# ADR 0001: Phase 0 architecture — language, packages, and build

## Status

Accepted

## Context

`tft-overlay` is a native macOS companion app for Teamfight Tactics. Per
README.md, the real host on macOS today is **Mactician** (an Android
emulator running the mobile TFT client) — there is no LCU, no lockfile, and
no port 2999. The bright line is **pixels only**: no process memory reads,
no injection, on host or guest. The project has four upcoming phases beyond
this one: a click-through comps/items overlay (Phase 1, no capture), board
awareness via screen capture + CV/OCR (Phase 2), a recommendation engine and
data platform (Phase 3), and compliance/distribution (Phase 4).

Phase 0 has to lay a foundation that serves all of that: a menu bar shell
with no Dock icon, hotkeys, an overlay window abstraction, a pure data
model, and CI — without over-committing to Phase 1/2 designs that aren't
decided yet.

## Decisions

### Language & UI framework: Swift + SwiftUI

- **Chosen:** Swift 6 toolchain (Xcode 26.6, Swift 6.3.3), SwiftUI for the
  menu bar UI and future overlay content, with AppKit underneath for window
  management (`NSWindow`, `NSEvent` global monitors) where SwiftUI has no
  equivalent.
- **Alternatives considered:**
  - **AppKit-only, no SwiftUI.** More control over window behavior, but
    slower to build UI for Phase 1's comp/item reference views, and
    `MenuBarExtra` (SwiftUI, macOS 13+) already gives us the menu bar item
    for free. Rejected — SwiftUI-with-AppKit-escape-hatches is the standard
    pattern for modern menu bar apps and costs nothing here.
  - **Electron / a web-based overlay.** Would let the eventual comp/item
    reference UI reuse web tooling. Rejected outright: it cannot do
    reliable always-on-top, click-through, transparent overlays on macOS
    without fighting the framework, has materially worse idle CPU/memory
    for something meant to sit on screen during a match, and adds an
    entire runtime for a problem native AppKit solves directly.

### macOS deployment target: 14.0 (Sonoma)

ScreenCaptureKit (needed in Phase 2) is available from 12.3, and `MenuBarExtra`
(used now, in Phase 0) from 13.0. We're going further, to **14.0**, because:

- Nothing in README.md's audience (TFT players running Mactician on Apple
  Silicon in 2026) is meaningfully served by supporting Sonoma-1 or older —
  this is a new app with no legacy install base to preserve.
- 14.0 gives Phase 2 the newer, simpler ScreenCaptureKit APIs (e.g.
  `SCScreenshotManager`, improved `SCContentFilter` ergonomics) instead of
  having to branch capture code by OS version.
- `NSWindow.collectionBehavior` and activation-policy handling used by
  `OverlayWindowController` are stable and well-documented from 14.0 on.
- Revisit if user data in Phase 4 shows meaningful Sonoma/Ventura demand;
  nothing here structurally prevents lowering the target later.

### State management: native SwiftUI state, no external framework

- **Chosen:** `@State`/`@Observable`/`@EnvironmentObject`-style native
  SwiftUI state management, kept local to the app target. `TFTData` and
  other packages stay UI-framework-agnostic (plain structs), so state
  management is purely an app-shell concern.
- **Alternatives considered:**
  - **The Composable Architecture (TCA) or a Redux-style store.** Gives
    strong testability and unidirectional data flow, which matters more
    once Phase 2/3 introduce real async pipelines (capture → CV → OCR →
    recommendation). Rejected *for now* — pulling in a global-store
    architecture before there's meaningful cross-feature state to
    coordinate is premature; Phase 0's state is "is the overlay visible"
    and "what's in the menu." Revisit at the start of Phase 2, when board
    state starts flowing through multiple pipeline stages and needs to be
    shared between the overlay and a settings surface.
  - **Combine-heavy hand-rolled stores.** Same rationale as TCA: more
    machinery than Phase 0/1 need, and SwiftUI's native tools already cover
    the menu bar shell and the Phase 1 reference UI.

### Package graph: local SwiftPM packages, one per bounded concern

```
tft-overlay/                    (root package — the app itself)
├── Package.swift                executable target "TFTOverlay"
├── Support/Info.plist           embedded via linker sectcreate (see below)
├── Sources/TFTOverlay/          app shell: App/AppDelegate/menu bar UI
└── Packages/
    ├── TFTData/                 set data model — champions, traits, items,
    │                            augments. Pure Swift structs, Sendable,
    │                            no UI imports, no networking types.
    ├── LCUClient/                STUB ONLY, see below.
    ├── OverlayKit/               overlay window (NSWindow), global hotkeys,
    │                            pure-geometry positioning.
    └── BoardVision/              empty placeholder for Phase 2
                                   (ScreenCaptureKit/adb capture + CV/OCR).
```

The app target depends on `TFTData`, `LCUClient`, and `OverlayKit`.
`BoardVision` is deliberately **not** wired into the app yet — it has no
implementation to wire in until Phase 2.

- **Why separate packages instead of one target with folders:** each
  package draws a hard compile-time boundary. `TFTData` cannot accidentally
  import AppKit or a networking library; `OverlayKit` cannot reach into
  game-data internals. Each also gets its own test target, so `swift test`
  inside any one package is a fast, focused signal, and CI can build/test
  them independently.
- **Alternative considered — a single monolithic app target with internal
  folders.** Simpler `Package.swift`, but no compiler-enforced boundaries
  and slower incremental builds as the app grows. Rejected; the boundary
  cost is worth paying this early, before code accretes on the wrong side
  of it.

### LCUClient is a stub, on purpose

TFT removes native macOS support at Set 18 / Patch 18.1 (client shipping
2026-10-09): no League client, no lockfile, no LCU REST/WebSocket API, and
no Live Client Data API on port 2999, on macOS. `LCUClient` exists only so
the package graph doesn't need surgery if Riot restores native macOS
support later (tracked as "Deferred — Native macOS client" in README.md).
Its only real behavior today is reporting itself unavailable
(`LCUError.unavailableOnMacOS`). Do not add real lockfile/REST/WebSocket
logic to it until native support returns.

### Build system: plain SwiftPM, not a hand-authored `.xcodeproj`

- **Chosen:** A pure SwiftPM layout (`swift build` / `swift test` from the
  repo root and from each `Packages/*` directory). The app's `Info.plist`
  (setting `LSUIElement = true`, among other keys) is embedded directly
  into the linked Mach-O binary via
  `-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Support/Info.plist`
  in the executable target's `linkerSettings`, and `AppDelegate` also calls
  `NSApp.setActivationPolicy(.accessory)` for a second, code-level guarantee
  of no-Dock-icon behavior independent of plist parsing. This has been
  verified locally: `swift build` succeeds, `swift test` passes in all four
  packages, and the built binary runs as background-only (confirmed via
  `System Events` — it appears with `background only = true` and is absent
  from the Dock-visible process list) while showing a `MenuBarExtra` item.
- **Why not generate a real `.xcodeproj`:** modern Xcode (26.6) opens a
  `Package.swift` folder directly as a project — a checked-in `.xcodeproj`
  is optional, not required, for local development or for
  `xcodebuild -scheme TFTOverlay build test` to work against a SwiftPM
  package. Hand-authoring a correct `project.pbxproj` (target settings,
  build phases, scheme, entitlements) by direct text editing is
  error-prone and hard to verify without Xcode's GUI in this environment;
  `swift package generate-xcodeproj` was removed from modern SwiftPM
  entirely. Given the task's explicit fallback allowance, pure SwiftPM was
  judged the more reliable, verifiable choice for Phase 0.
- **Consequence / revisit trigger:** Phase 4 (notarization, sandboxing,
  Riot registration, entitlements for ScreenCaptureKit/microphone-adjacent
  permissions) is more naturally managed through a real Xcode project and
  scheme, with signing settings in Xcode's UI. Revisit then — either by
  letting Xcode generate/save a `.xcodeproj` from this same `Package.swift`
  layout (Xcode can do this via "Open" → the package resolves as a project
  and Xcode can save a workspace around it), or by migrating to an
  app-target-in-`.xcodeproj` + local-SwiftPM-package-dependencies layout,
  which this package graph maps onto directly with no restructuring.

## Consequences

- CI and local development both run on `swift build` / `swift test`;
  there's no `xcodebuild` step required for Phase 0's "does it build and
  pass tests" gate, though `xcodebuild -scheme TFTOverlay build test`
  should also work against this package since Xcode treats a `Package.swift`
  directory as a buildable project with an implicit scheme matching the
  product name.
- Anyone opening this repo in Xcode gets full IDE support (autocomplete,
  debugging, SwiftUI previews) without a checked-in project file to keep in
  sync.
- The `LCUClient` package will look conspicuously empty to a future
  contributor; the header comment in
  `Packages/LCUClient/Sources/LCUClient/LCUClient.swift` explains why, and
  this ADR is the canonical reference.
