# ADR 0003: The `GameHost` abstraction

## Status

Accepted

## Context

TFT dropped native macOS support with Set 18 / patch 18.1, so on macOS today
the game runs under **Mactician** — an MIT-licensed launcher that runs the
Android TFT build in the stock Google Android Emulator on Apple Silicon. Riot
calls the removal temporary but has committed to no return date, so we must
build for the emulator host now while leaving room for a native client that
may come back.

That is the reason this abstraction exists at all. The two hosts differ in
almost every property the rest of the app cares about — coordinate systems,
what state we can observe without pixels, whether an LCU exists, and how we
get frames — but the *questions* the app asks are the same. `GameHost` is the
seam where those differences are answered once, so nothing above it has to
know which host is running.

Everything below is grounded in measurements taken against a live Mactician
emulator. The evidence, method and raw numbers are in
[`docs/research/mactician-host.md`](../research/mactician-host.md); the probes
that produced them are in [`scripts/probe/`](../../scripts/probe). The facts
that shaped this design:

- The window TFT renders into is owned by `qemu-system-aarch64`, but macOS
  reports it under the bundle identifier
  **`dev.sergeinaumov.mactician.game-host`** — not the launcher's
  `dev.sergeinaumov.mactician`, and not any process named "Mactician". The
  bundle owns **two** windows; the game is the larger one.
- adb is reachable, on a **non-default server port 5038** with serial
  `emulator-5582`, using **Mactician's own adb binary** (a different client
  version kills their server).
- `adb exec-out screencap` caps at **3.1 fps** and costs the emulator **~0.8
  of a core**. ScreenCaptureKit on the same window does **112 fps** for
  **3.6%** of a core and is unaffected by occlusion.
- adb frames are **bit-exact** (two consecutive frames of a static screen are
  identical). SCK frames differ from the guest framebuffer on ~23% of pixels.
- The guest framebuffer is exactly the configured profile resolution. **UI
  scale does not change it** — it is an Unreal `ApplicationScale` applied
  inside the guest, so it changes layout within a fixed pixel grid.
- `dumpsys` gives a clean "TFT is foregrounded" signal and **nothing finer** —
  the whole client is one Unreal `GameActivity`. logcat is silent.

## Options considered

### (a) No abstraction — code directly against Mactician

Simplest, and Mactician is the only host that matters today. Rejected: the
deferred native client is an explicit project milestone, and the differences
are not cosmetic. A native client has an LCU, no guest/host coordinate split,
no adb, and a borderless-fullscreen problem Mactician does not have. Threading
that through call sites later means touching capture, overlay positioning and
state detection simultaneously.

### (b) Abstract over *capture* only

Treat the host as a frame source and let everything else be Mactician-specific.
Rejected: capture is the part that generalises *worst*. The coordinate mapping
(guest pixels → screen points, through a resizable window with chrome insets
and a backing scale) and the state signal are where the hosts actually diverge,
and both feed Phase 1, which does no capture at all.

### (c) A host protocol with declared capabilities — **chosen**

One protocol covering detection, window resolution, coordinate mapping, state
signals and capture, where each host publishes a **capability descriptor**
saying what it can actually do. Callers branch on capabilities, not on host
identity.

This matters because the honest answer to several questions is "not on this
host". A host that cannot report finer state than "foregrounded" should say so
in a value the caller can read, rather than returning a plausible-looking
`GameState` it inferred from nothing.

## Decision

### The capability descriptor

```swift
struct GameHostCapabilities: Sendable, Equatable {
    /// A byte-exact copy of the framebuffer the game rendered, on demand.
    var exactFramebufferCapture: Bool
    /// Sustained frame rate the continuous capture path can actually hold.
    var sustainedCaptureFPS: Double
    /// Continuous capture requires the macOS Screen Recording (TCC) grant.
    var captureRequiresScreenRecording: Bool
    /// Guest geometry is pinned and knowable, not inferred from the window.
    var fixedRenderGeometry: Bool
    /// Some non-pixel signal exists — at minimum "the client is in front".
    var foregroundSignal: Bool
    /// The finest state this host can report WITHOUT looking at pixels.
    var finestNonPixelState: NonPixelStateResolution
    /// LCU / lockfile / Live Client Data are reachable.
    var localGameAPI: Bool
}

enum NonPixelStateResolution: Comparable, Sendable {
    case none            // nothing without pixels
    case processRunning  // the client process exists
    case appForeground   // the client is the focused app  <- Mactician stops here
    case inGame          // in a match vs. not
    case roundPhase      // planning / combat / carousel
}
```

`finestNonPixelState` is the load-bearing field. It is how Phase 2 knows that
on Mactician, *everything* past "the client is in front" is a CV problem, and
how a future native host advertises that it can do better without any caller
being rewritten.

### The protocol

```swift
protocol GameHost: Actor {
    static var id: GameHostID { get }
    nonisolated var capabilities: GameHostCapabilities { get }

    // --- Detection (issue #10) -------------------------------------------
    /// One-shot probe. Cheap enough to poll on a timer.
    func detect() async -> HostPresence
    /// Long-lived presence/state stream. Coalesced; emits only on change.
    func observe() -> AsyncStream<HostObservation>

    // --- Window resolution + coordinate mapping (issues #10, #53) --------
    /// Fails rather than guessing when the window cannot be resolved.
    func resolveViewport() async throws -> Viewport

    // --- Non-pixel state (issue #52) -------------------------------------
    func stateSignal() async -> NonPixelState

    // --- Capture (issue #51) ---------------------------------------------
    func makeCaptureSource(_ intent: CaptureIntent) async throws -> any CaptureSource
}

enum HostPresence: Sendable {
    case hostAbsent               // Mactician not installed
    case hostIdle                 // installed, emulator not running
    case hostRunning(Viewport?)   // emulator up, client not necessarily running
    case clientRunning(Viewport)  // TFT process alive
    case clientForeground(Viewport)
}
```

`Viewport` is the single source of truth for geometry, and it deliberately
carries its own fidelity:

```swift
struct Viewport: Sendable, Equatable {
    /// The game's own pixel grid. On Mactician this is the guest framebuffer.
    let renderSize: CGSize            // e.g. 1920x1080
    /// Window frame in screen points, as macOS reports it.
    let windowFrame: CGRect
    /// Non-content chrome (title bar) — MEASURED per resolve, never hardcoded.
    let chromeInsets: NSEdgeInsets
    let backingScale: CGFloat
    /// contentPixels / renderSize. 1.0 means no resampling.
    let renderToContentScale: CGFloat
    /// Opaque, host-specific handle for the capture layer (e.g. CGWindowID).
    let windowToken: WindowToken

    var isPixelExact: Bool { abs(renderToContentScale - 1.0) < 0.001 }
    var contentPixelSize: CGSize { ... }

    func renderToScreen(_ p: CGPoint) -> CGPoint
    func screenToRender(_ p: CGPoint) -> CGPoint?   // nil when outside content
}
```

Three rules this type enforces, each from a measurement:

1. **`chromeInsets` is derived, never constant.** It measured 56 device pixels
   here, but it belongs to a window we do not own.
2. **`renderToContentScale` is exposed, not hidden.** The user can resize the
   Mactician window freely and the emulator rescales the guest texture — the
   user's own launcher log shows a 3626x2040 swapchain against a 1920x1080
   guest, a 1.888x upscale. Downstream CV must be able to see that it is
   looking at resampled pixels and lower its confidence accordingly.
3. **`renderSize` comes from the host, not from the window.** On Mactician it
   is read from the guest (`screencap` header, or `wm size`), so it stays
   correct no matter what the window is doing.

### Capture: intent-based, two paths

```swift
enum CaptureIntent {
    /// Continuous, low-latency, low-cost. Fidelity may be approximate.
    case liveStream(targetFPS: Double)
    /// One byte-exact frame. Slow and expensive; not for a loop.
    case exactStill
}
```

`MacticianHost` serves `.liveStream` from ScreenCaptureKit and `.exactStill`
from adb. It advertises `exactFramebufferCapture: true`,
`sustainedCaptureFPS: 60`, `captureRequiresScreenRecording: true`.

The measurements make this split, not taste:

| | ScreenCaptureKit | `adb exec-out screencap` |
|---|---:|---:|
| Delivered fps | **112** | **3.1** |
| Emulator CPU cost | +2.8pp (noise) | **+83pp (~0.8 core)** |
| Capturer CPU | 3.6% | negligible |
| Survives occlusion | yes | n/a |
| Bit-exact vs guest | **no** (~23% of pixels differ) | **yes** |
| Needs Screen Recording | yes | **no** |

adb's ceiling is the adb pipe itself — 8MB through `exec-out` costs 288ms
(~29 MB/s), and a 1080p RGBA frame is 8.29MB. Capture inside the guest is only
43ms. No amount of connection reuse fixes a transport bound, and higher
resolution profiles make it worse (roughly 1.7 fps at 1440p, 0.8 fps at 4K).

So `.exactStill` is for calibration, template extraction, golden-image tests
and diagnostic bug reports — the places where "the pixels the game actually
drew" matters more than latency, and where the CPU cost is paid once rather
than 60 times a second.

### Consequence we did not want: Screen Recording stays

The hope behind this investigation was that adb would let us ship a board-aware
overlay with **no TCC prompt at all**. It cannot: 3.1 fps that steals a core
from the game is not a live capture path.

What survives is narrower but still real:

- **Phase 1 needs no capture and therefore no Screen Recording prompt.**
  Auto-showing the overlay around games runs entirely on `detect()` +
  `stateSignal()`, both of which are adb calls costing ~15–40ms. Onboarding
  can ship with **zero** system permission prompts.
- **The prompt belongs to Phase 2**, at the moment the user turns on board
  awareness — asked in context, for a feature they just chose, rather than as a
  first-run tax on a feature they have not seen.

That is a materially better onboarding flow than the alternative, just not the
permission-free one we were hoping for. It is a Phase 2 decision now, not a
Phase 1 one.

### Hosts

**`MacticianHost` — primary, implemented.**

| Concern | Implementation |
|---|---|
| Detect install | `/Applications/Mactician.app`, bundle `dev.sergeinaumov.mactician` |
| Detect window | bundle id **`dev.sergeinaumov.mactician.game-host`**, largest-area window |
| adb | Mactician's own binary, **`-P 5038 -s emulator-5582`**, `start-server` first |
| `renderSize` | `screencap` 16-byte header, or `wm size` |
| State signal | `get-state` → `pidof` → `dumpsys activity activities` |
| Live capture | ScreenCaptureKit, `SCContentFilter(desktopIndependentWindow:)` |
| Exact capture | `adb exec-out screencap` (raw RGBA, not `-p`) |
| `finestNonPixelState` | `.appForeground` |
| `localGameAPI` | `false` |

Two integration hazards this host must own, because getting either wrong looks
like an unrelated bug:

- **Never invoke `adb` from `PATH`.** A version-mismatched client kills
  Mactician's server and drops the transport under their running launcher. Use
  their binary at their port.
- **Never match on process name or window title.** The process is
  `qemu-system-aarch64`; the title (`Mactician: TFT`) is cosmetic and
  localisable. Match on bundle identifier.

**`NativeClientHost` — deferred stub.**

Compiles, detects nothing, and declares what it *would* offer so the
capability-driven call sites are exercised by at least two shapes:

```swift
GameHostCapabilities(
    exactFramebufferCapture: false,
    sustainedCaptureFPS: 60,
    captureRequiresScreenRecording: true,
    fixedRenderGeometry: false,       // borderless fullscreen, user resolution
    foregroundSignal: true,
    finestNonPixelState: .roundPhase, // LCU can do better than a foreground bit
    localGameAPI: true
)
```

`detect()` returns `.hostAbsent` until Riot restores native macOS support. It
exists to keep the seam honest — a protocol with one implementation drifts into
that implementation's shape.

### Host resolution

A `GameHostRegistry` probes registered hosts in priority order and publishes
the first non-`.hostAbsent` result, re-probing on workspace app
launch/terminate notifications. Mactician is first. The app binds to whichever
host is present; nothing above the registry names a host.

## Consequences

- **Phase 1 ships with no system permission prompts.** Auto-show/hide runs on
  adb state polling alone.
- **Phase 2 must ask for Screen Recording**, in context, when board awareness
  is enabled. Plan the onboarding copy for that, not for a permission-free
  world.
- **CV templates must be keyed on `(resolution, uiScale)`.** UI scale changes
  layout inside a fixed pixel grid, so two players at 1080p can have different
  shop rectangles. This is a Phase 2 data-model constraint, and it is why
  `Viewport` alone is not enough to locate a UI element.
- **Nothing above `GameHost` may assume a state finer than "foregrounded".**
  On Mactician there is no such signal. Designing #52 around one would mean
  designing around something that does not exist.
- **Calibration and golden-image tests must use `.exactStill`.** Capturing
  references through ScreenCaptureKit would bake this machine's display
  transform into fixtures that then fail elsewhere.
- **We take a dependency on Mactician's internals** — a bundle identifier, a
  port and a serial, all read from their binary and scripts. They are constants
  in a shipped build, not negotiated, so they are stable by construction. But
  Mactician is a moving third-party project. `MacticianHost` should fail loudly
  and specifically when a probe stops matching, rather than silently reporting
  `.hostAbsent`, so a Mactician update surfaces as "Mactician changed" and not
  as "the overlay stopped working".
- **The pixels-and-adb constraint is now on the record with its rejections.**
  Guest process memory is technically reachable (`adb root` succeeds on this
  userdebug AVD) and was refused; so were host-side memory reads and any form
  of injection. See §7 of the findings doc.
