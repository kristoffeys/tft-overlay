# Mactician host — empirical findings

Status: measured 2026-08-29 on this machine.
Feeds issues #56 (this investigation), #50 (GameHost), #10 (window discovery),
#51 (capture), #52 (state signals), #53 (geometry).

Everything below was measured against a live Mactician emulator running the
real TFT Android build, except where explicitly marked as read from source.
Probe scripts are in [`scripts/probe/`](../../scripts/probe) and every number
here is reproducible with them.

## Headline

**The adb hypothesis is refuted for continuous capture, and confirmed for
exact capture.**

`adb exec-out screencap` tops out at **3.1 fps** and costs the emulator
**~0.8 of a CPU core** while it runs. ScreenCaptureKit on the same window
delivers **112 fps** for **3.6% of one core**, and keeps working while the
window is fully occluded. SCK wins on speed by ~36x and on total CPU by ~25x.

What adb wins on is *exactness*: two consecutive `screencap` frames of a static
guest screen are **bit-identical**, while the SCK capture of the same static
screen differs from the guest framebuffer on ~23% of pixels.

So the recommendation is a **hybrid**: ScreenCaptureKit for the live loop, adb
as an on-demand exact reference. And the consequence for onboarding is the one
we did not want: **the macOS Screen Recording (TCC) permission cannot be
removed from the product.** Phase 1 still needs no capture at all, so the
prompt stays out of first-run onboarding and belongs to Phase 2.

---

## 1. What Mactician actually is

Read from the installed bundle and the app's own MIT-licensed launcher scripts.

Mactician is **not** a custom emulator. It is a SwiftUI launcher around the
**stock Google Android Emulator**, pinned by
`Contents/Resources/release-manifest.json`:

| Component | Version |
|---|---|
| platform-tools (adb) | 36.0.2 |
| emulator | 37.1.11 (`darwin_aarch64`) |
| system image | `android-36` `google_apis` `arm64-v8a` r07 |
| TFT package | `com.riotgames.league.teamfighttactics` |
| TFT version (installed here) | `18.1-5392842` (versionCode 8392842) |

Bundle layout:

```
/Applications/Mactician.app/Contents/
  MacOS/Mactician                       SwiftUI launcher (dev.sergeinaumov.mactician)
  Helpers/Mactician Game Host.app       app wrapper the emulator is launched INSIDE
  Frameworks/Sparkle.framework          auto-update
  Resources/
    launcher-runtime.command            emits JSON lifecycle events on stdout
    release-manifest.json               pinned component + profile table
    QEMU-Hypervisor.entitlements        com.apple.security.hypervisor
    Game/*.apk                          bundled TFT APK split set
    RuntimeTemplate/                    launcher scripts, copied to Application Support
```

The working install lives at `~/Library/Application Support/Mactician/`:
`sdk/` (its own platform-tools + emulator + system image), `avd/Tft.avd`,
`runtime-project/` (the launcher scripts), `logs/launcher.log`,
`install-state.json`.

### The launch chain

```
launcher-runtime.command                 validates TFT_* env, emits JSON events
  └─ scripts/run-asg-experiment.command  swaps hw.gltransport pipe -> virtio-gpu-asg
      └─ run-tft-angle-opengl.command    sets renderer + MoltenVK tuning
          └─ run-tft-root-affinity.command
              └─ open -n -W "Mactician Game Host.app" --args \
                   @Tft -id TFT-Tft -port 5582 -gpu host -skin 1920x1080 \
                   -vsync-rate 60 -cores 6 -memory 6144 -no-snapshot ...
```

Notable behaviours, all read from the scripts:

- The launcher takes an **AVD lock** (`shlock` on `.mactician-avd.lock`) and
  refuses to start if the emulator is already on `emulator-5582`.
- It **temporarily rewrites** `config.ini` (`hw.gltransport`) with a sidecar
  backup, and restores it on exit — including after a crash, on next launch.
- It mounts a **verified APK overlay** (`base-angle-opengl.apk`) plus an Unreal
  `DeviceProfiles.ini`, pinned by SHA-256, and unmounts on exit.
- It requires a **rootable (userdebug) AVD** — it `chown`/`chcon`/`mv`s files
  into TFT's private data directory. `adb root` is available on this AVD
  (verified: `uid=0(root) ... context=u:r:su:s0`).

The rendering stack, per the launcher's own status line, is
`Unreal OpenGL ES -> gfxstream GLES encoder -> host ANGLE -> Metal`.

---

## 2. Process and window topology  (issue #10)

**This is the part that would have been guessed wrong.**

The process that owns the on-screen window is `qemu-system-aarch64` — but
macOS does not report it under that name. Because the emulator is launched via
`open -n -W "Mactician Game Host.app"`, it inherits that bundle's
LaunchServices identity. Measured with `CGWindowListCopyWindowInfo`:

```
windowID  pid   layer  owner                 title           x    y    w    h
3168      1485  0      Mactician Game Host   Mactician: TFT  100  100  960  568
3169      1485  0      Mactician Game Host   (none)          1060 128  54   506
```

```
pid 1485  .../sdk/emulator/qemu/darwin-aarch64/qemu-system-aarch64
pid 1555  .../sdk/emulator/netsimd            (child)
```

So:

| Question | Answer |
|---|---|
| `ps` executable name | `qemu-system-aarch64` |
| `kCGWindowOwnerName` | **`Mactician Game Host`** |
| Bundle identifier | **`dev.sergeinaumov.mactician.game-host`** |
| Window title | `Mactician: TFT` |
| Window layer | 0 (normal) |
| Windows owned | **two** |

**Discovery rule for #10:** match on bundle identifier
`dev.sergeinaumov.mactician.game-host` (stable, and what `SCWindow`
`owningApplication` reports), never on process name and never on window title.
The launcher app `dev.sergeinaumov.mactician` is a *different* process and owns
a *different* window — do not confuse them.

**There are two windows.** Window 3169 (54x506) is the emulator's floating
extended-controls toolbar. It sits immediately right of the game window
(x=1060 = game window's right edge) so it does not occlude the game, but any
"find the window for this pid" heuristic must exclude it. Selecting the
**largest-area window** of the bundle is sufficient and is what the probes do.

The `dev.sergeinaumov.mactician.game-host` bundle declares
`LSSupportsGameMode` / `GCSupportsGameMode`, so macOS Game Mode can engage —
worth remembering when we later reason about overlay window levels.

---

## 3. adb reachability  (issue #51)

Mactician does **not** disable or firewall adb. But it does something that will
silently break a naive integration:

> **Mactician runs its own adb server on port 5038, with its own adb binary.**

```
$ adb -P 5038 devices -l
emulator-5582   device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a

$ adb -P 5037 devices -l          # the DEFAULT server
List of devices attached
                                   # <- nothing
```

| Fact | Value |
|---|---|
| Serial | `emulator-5582` (hardcoded in the Mactician binary) |
| adb server port | `5038` (hardcoded; `TFT_ADB_SERVER_PORT` overrides) |
| Mactician's adb | `~/Library/Application Support/Mactician/sdk/platform-tools/adb` — **36.0.2** |
| A Homebrew adb on this machine | `/opt/homebrew/bin/adb` — **37.0.1** |

**Two hazards, both real:**

1. A stock `adb devices` on the default port 5037 sees **nothing**. Empirically
   verified above — the emulator registers only with the server it was
   configured for.
2. adb enforces client/server version match. Pointing the Homebrew 37.0.1
   client at Mactician's 36.0.2 server on 5038 makes it **kill and restart that
   server**, which pulls the transport out from under Mactician's running
   launcher.

**Rule:** always invoke Mactician's *own* adb binary with `-P 5038`. Never
shell out to whatever `adb` is on `PATH`. `scripts/probe/adbenv.sh` encodes
this.

Also confirmed: a bare `adb devices` blocks the calling shell while it forks
its daemon. Call `adb -P <port> start-server` first.

Stability across restarts: the serial and port are **constants in the Mactician
binary**, not negotiated, so they are stable by construction. Verified across
three separate emulator launches in this session.

---

## 4. Capture benchmark  (issues #51, #53)

Guest: 1920x1080 @ 320dpi, 60Hz. Host: Apple Silicon, 2x backing scale,
emulator window at its default 960x568pt. TFT running.

### 4.1 Latency and throughput

Per-frame wall time, in-process timer, 20 iterations
(`scripts/probe/bench-adb-decompose.py`):

| Path | bytes/frame | min | p50 | mean | p95 | max | ceiling |
|---|---:|---:|---:|---:|---:|---:|---:|
| adb client spawn + connect (`shell true`) | 0 | 14.6 | 15.2 | 15.5 | 17.4 | 19.1 | — |
| adb pipe throughput (8MB of zeros) | 8 388 685 | 238.4 | **288.2** | 283.5 | 296.7 | 298.0 | 3.5 fps |
| `adb exec-out screencap` (raw RGBA) | 8 294 416 | 283.8 | **323.4** | 319.6 | 339.3 | 340.4 | **3.1 fps** |
| `adb exec-out screencap -p` (PNG) | 1 184 076 | 440.4 | **468.9** | 473.6 | 500.7 | 502.0 | 2.1 fps |
| `screencap` + `adb pull` via /sdcard | — | 484 | ~520 | 534 | — | 626 | 1.9 fps |
| guest-side `screencap` only, no host transport | — | — | — | **42.9** | — | — | 23.3 fps |

All times in milliseconds.

**The bottleneck is the adb pipe, not screencap.** 8MB of `/dev/zero` through
`exec-out` costs 288ms — about **29 MB/s**. A raw 1080p frame is 8.29MB, so
the transport alone caps the path at ~3.5 fps before a single pixel is
captured. Capture inside the guest is only 43ms/frame (23 fps); the host round
trip is what destroys it. Client process spawn is 15ms and irrelevant — a
persistent connection would not rescue this.

PNG is *worse*, not better: it cuts bytes by 7x but adds ~430ms of in-guest
encoding.

Scaling is the wrong direction too: the 1440p profile is 1.78x the pixels of
1080p and 4K is 4x, so the adb ceiling falls to roughly 1.7 fps and 0.8 fps.

### 4.2 ScreenCaptureKit on the same window

`scripts/probe/bench-sck.swift`, `SCContentFilter(desktopIndependentWindow:)`,
`minimumFrameInterval` 1/120:

| Condition | frames | window | delivered fps | interframe p50 | p95 | max |
|---|---:|---:|---:|---:|---:|---:|
| window frontmost | 675 | 6.0s | **112.5** | 8.89 | 17.06 | 18.46 |
| window **fully occluded** | 447 | 4.0s | **111.8** | 8.97 | 10.92 | 12.72 |

Occlusion test: a TextEdit window was moved to exactly the emulator window's
rect (100,100 960x568) and raised. Frame delivery was unaffected. **SCK window
capture is immune to occlusion**, so that argument for adb does not hold.

Delivered buffer: 1920x1136 — i.e. the full window frame at 2x, including 56
device pixels of macOS title bar.

### 4.3 Host CPU cost

`ps %cpu` sampled once a second for 8s per condition
(`scripts/probe/bench-cpu.sh`). Percentages are of one core.

| Condition | `qemu-system-aarch64` | capturing process |
|---|---:|---:|
| idle, no capture | 124.1% | — |
| continuous `adb exec-out screencap` | **207.2%** | negligible |
| ScreenCaptureKit stream | 126.9% | **3.6%** |

**adb capture costs the emulator ~83 percentage points — about 0.8 of a
core — taken directly from the process rendering the game.** ScreenCaptureKit
costs the emulator nothing measurable (+2.8pp, within sampling noise) and the
capturing process 3.6%.

This is the strongest argument against adb as a live path: it is not merely
slow, it actively degrades the game it is observing.

### 4.4 Fidelity — where adb wins

Measured on a *static* guest screen, with an interleaved control to prove the
screen was not changing (`scripts/probe/compare-frames.py`):

```
CONTROL  adb-before vs adb-after, SCK grab taken in between
         mean=0.000  max=0  identical pixels=100.00%
```

adb `screencap` is **bit-exact and deterministic**. Two frames of a static
screen are byte-identical. That control also proves the guest was completely
still, so the comparison below is not contaminated by motion.

Against that same frame, the SCK capture (title bar cropped):

| Crop offset | mean abs diff | pixels exactly equal | within ±2 |
|---:|---:|---:|---:|
| 53 | 22.94 | 14.79% | 76.85% |
| 54 | 23.01 | 14.59% | 76.73% |
| 55 | 23.07 | 14.46% | 76.59% |
| 56 | 23.15 | 14.36% | 76.35% |

So roughly **77% of pixels agree within ±2/255, and ~23% do not.** Two
diagnostics on the residual:

- **It is edge-dominated.** Mean local gradient where `|diff|>8` is 3.84,
  versus 0.48 where `|diff|<=8`. Errors concentrate on edges, which is the
  signature of resampling, not of a flat colour shift.
- **There is also a systematic lift**: mean *signed* difference is
  `R +8.21, G +8.14, B +6.97`.

Neither an integer crop offset (searched 0–79) nor a vertical rescale of the
whole frame to 1080 rows improves it — a full-frame squash makes it worse
(mean 30.47). So the host window is *nominally* 1:1 with the guest, but the
emulator is compositing the guest texture with a sub-pixel offset and/or a
colour transform on the way to the display.

**Conclusion:** ScreenCaptureKit is geometrically 1:1 but photometrically
approximate. That is almost certainly fine for CV on a 1080p board — but it
means golden-image tests, template extraction and calibration should use adb,
not SCK, or they will bake in this machine's display transform.

---

## 5. Guest geometry  (issue #53)

### 5.1 The profile table

From `release-manifest.json` (read from source, not measured):

| Profile id | Title | Width | Height | Density | Memory |
|---|---|---:|---:|---:|---:|
| `balanced` | 1080p | 1920 | 1080 | 320 | 6144 |
| `quality` | 1440p | 2560 | 1440 | 416 | 6144 |
| `ultra` | 1800p | 3200 | 1800 | 520 | 6144 |
| `4k` | 4K | 3840 | 2160 | 640 | 6144 |

Applied in two places by `run-tft-root-affinity.command`:

```
emulator ... -skin "$TFT_DISPLAY_SIZE"       # host window content size
adb shell wm size    "$TFT_DISPLAY_SIZE"     # guest logical display
adb shell wm density "$TFT_DISPLAY_DENSITY"
```

Measured against the running 1080p profile:

```
Physical size:    1920x1080
Physical density: 320
DisplayViewport   logicalFrame=Rect(0,0-1920,1080) physicalFrame=Rect(0,0-1920,1080)
                  deviceWidth=1920 deviceHeight=1080
                  renderFrameRate 60.000004, supportedModes [{1920x1080, 60fps}]
                  physicalPixelDisplaySizeRatio=1.0 scale=1.0
```

And from the raw `screencap` header (`<III` little-endian width, height,
pixel format, then a **16-byte** header before RGBA data):

```
width=1920 height=1080 pixelformat=1 totalbytes=8294416
  header=16B -> 1920*1080*4 + 16 = 8294416  MATCH
```

The guest framebuffer is exactly the profile resolution. No letterboxing, no
device frame (`showDeviceFrame=no`), no rotation.

### 5.2 UI scale does **not** change the framebuffer

This is the geometry finding that matters most, and it is easy to get wrong.

Mactician's UI-scale setting (allowed values `1.0`, `1.25`, `1.5`, `1.75`,
`2.0`) is applied by rewriting the **guest's Unreal config**, not by resizing
anything:

```ini
; /data/user/0/com.riotgames.league.teamfighttactics/files/UnrealGame/TFT/TFT/
;   Saved/Config/Android/Engine.ini
[/Script/Engine.UserInterfaceSettings]
ApplicationScale=1.25
```

The launcher's own comment states the intent: *"Unreal exposes ApplicationScale
as the global multiplier applied after its resolution-dependent DPI rule. Stage
it before every game start without changing the 3D framebuffer resolution or
r.ScreenPercentage."*

So:

> **Resolution changes the pixel grid. UI scale changes the layout within that
> grid.** The framebuffer is `TFT_DISPLAY_SIZE` regardless of UI scale.

Consequence for Phase 2: a CV template set must be keyed on
**(resolution, uiScale)**, not resolution alone. Two players at 1080p can have
completely different shop-row rectangles.

Reading the UI scale back is awkward. `Engine.ini` lives in TFT's private data
directory. `adb root` *is* available on this AVD (verified), so it is
technically readable — but shipping a product that calls `adb root` (which
restarts `adbd` and drops the transport) is not acceptable. Mactician stores
its own preference in `defaults` under `dev.sergeinaumov.mactician`, but those
keys only materialise once the user changes them from the default, so they
cannot be relied on either. **Recommendation: detect UI scale from pixels** by
calibrating against a known-size anchor, and treat it as part of the
calibration profile rather than something to be read out of band.

### 5.3 Host window geometry and the mapping rule

| Measurement | Value |
|---|---|
| Window frame (points) | 960 x 568 |
| Backing scale | 2.0 |
| SCK delivered buffer | 1920 x 1136 |
| Title-bar / chrome rows | **56 device px** (28pt) |
| Content area | 1920 x 1080 device px |
| Guest framebuffer | 1920 x 1080 |
| Content : guest ratio | **1.000** |

At the default window size on a 2x display with the 1080p profile, the window
content is *exactly* the guest framebuffer size. That is a coincidence of this
configuration, not a guarantee.

The window is freely resizable and the emulator rescales the guest texture to
fit. This machine's own `launcher.log` from the user's earlier real session
shows it:

```
INFO | Recreating swapchain with size 3626x2040.
```

3626x2040 against a 1920x1080 guest is a **1.888x upscale**. Resizing smaller
than the guest resolution would *downsample* and lose information outright.

**Coordinate mapping rule:**

```
contentPx   = (windowFrame.size - chromeInsets) * backingScale
guestToContent = contentPx.width / guestSize.width
isPixelExact   = (guestToContent == 1.0)
screenPoint = windowOrigin
            + chromeInsets
            + guestPoint * guestToContent / backingScale
```

Chrome insets must be *derived* (`SCK buffer height - guest height * ratio`),
not hardcoded to 56 — it is a standard title bar today, but that is an
assumption about a window we do not own. The probes measure it every run.

Capture fidelity should be reported to the rest of the app as a first-class
signal: when `guestToContent != 1.0` the pipeline is looking at resampled
pixels and confidence thresholds should reflect that.

---

## 6. Non-pixel state signal  (issue #52)

### 6.1 `dumpsys` — works, but coarse

`adb shell dumpsys activity activities` gives a clean, cheap foreground read.
Measured transitions:

Android launcher:
```
topResumedActivity=ActivityRecord{... com.google.android.apps.nexuslauncher/.NexusLauncherActivity t2}
```

After `am start -n com.riotgames.league.teamfighttactics/com.epicgames.unreal.SplashActivity`:
```
topResumedActivity=ActivityRecord{... com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity t7}
mCurrentFocus=Window{... com.riotgames.league.teamfighttactics/com.epicgames.unreal.GameActivity}
```

So the available non-pixel facts are:

| Signal | Command | Cost |
|---|---|---|
| Is the emulator up? | `adb -P 5038 -s emulator-5582 get-state` | ~15ms |
| Is TFT running? | `adb shell pidof com.riotgames.league.teamfighttactics` | ~15ms |
| Is TFT foregrounded? | `adb shell dumpsys activity activities` → `topResumedActivity` | ~40ms |
| Guest framebuffer size | `screencap` header, or `wm size` | ~15ms |

That is genuinely useful — it drives overlay show/hide for Phase 1 with no
capture and therefore **no Screen Recording permission at all**.

**But it cannot see inside the game.** TFT is a single Unreal
`GameActivity`; lobby, queue, champion select, carousel, combat and post-game
are all the same activity. `dumpsys` can tell us *TFT is in front*, and
nothing finer.

### 6.2 `logcat` — a dead end

Checked whether the client leaks state to logcat. It does not. Tag frequency
over an 8s window with TFT foregrounded:

```
1277  android.hardware.gnss-service.ranchu
  20  wpa_supplicant
  14  WifiScanningService
  11  resolv
   4  PlayCore
```

The single TFT-related line in a 12s capture was a Play Store update check:

```
I/PlayCore( 3963): AppUpdateService : requestUpdateInfo(com.riotgames.league.teamfighttactics)
```

No `LogTFT`, no `UE4`/`Unreal` logging — a release Unreal build with logging
stripped. **logcat is not a state signal.**

### 6.3 Conclusion for #52

Model the state signal as deliberately coarse:

```
hostNotRunning -> hostRunning -> clientRunning -> clientForeground
```

Anything finer than "TFT is foregrounded" is a **pixels-only** problem. Do not
design #52 around a richer signal that does not exist.

---

## 7. What is permanently gone, and what we refused

Confirmed absent under Mactician, as expected: no lockfile, no LCU REST or
WebSocket, no Live Client Data API on port 2999. The game is an Android
process inside a VM; none of the PC client's local surfaces exist.

**Rejected approaches, on the project's hard constraint (pixels and adb only):**

- **Reading TFT's process memory in the guest.** The AVD is userdebug and
  `adb root` succeeds, so `/proc/<pid>/mem` on the TFT process is *technically*
  reachable. **Rejected.** It is exactly the prohibited technique, it is what
  separates a companion overlay from a cheat, and it would put the project
  outside Riot's policy regardless of how the data were used.
- **Reading emulator (`qemu-system-aarch64`) memory on the host** to recover
  the guest framebuffer without the adb transport cost. **Rejected** for the
  same reason — it is a process-memory read of the game's host, and it would
  also require disabling SIP or acquiring `task_for_pid` on another process.
- **Injecting into the emulator's GL/Metal path** (e.g. interposing on the
  gfxstream encoder or a Metal layer hook) to tap frames at zero cost.
  **Rejected**: injection, explicitly out of bounds, and it would make the app
  indistinguishable from tooling Riot bans.
- **Frida / `LD_PRELOAD` in the guest** against the Unreal binary. **Rejected**:
  injection.

None of these were attempted. They are listed so the decision is on the record
and does not get rediscovered as a "clever idea" later.

One approach was rejected on *engineering* grounds rather than policy:
`adb shell screenrecord --output-format=h264 -` would cut the byte budget by
orders of magnitude, but it buffers for low latency's opposite, caps at 3
minutes per invocation, and delivers compressed frames that would need decoding
before CV. Not measured; not recommended.

---

## 8. Open questions

Stated plainly, with what would answer each.

| # | Open question | Why it is open | What would answer it |
|---|---|---|---|
| 1 | Capture behaviour **inside a live TFT match** | Measurements were taken at the TFT home screen. The Riot session was already signed in on this machine and I did not enter a queue — playing a ranked or normal game on the user's account was not mine to do. | Run `bench-cpu.sh` and `bench-sck.swift` while the user is in a real game. Expect qemu's idle baseline to rise and the adb ceiling to fall further; SCK's 3.6% should be unchanged. |
| 2 | SCK fidelity at **non-1:1 window sizes** | Only the default 960x568 window was measured, where content is exactly 1:1 with the guest. | Resize the window to a few sizes (including smaller than 1920x1080 device px) and re-run `compare-frames.py`. This sets the confidence floor for CV at arbitrary window sizes. |
| 3 | Geometry at **1440p / 1800p / 4K** profiles | Only `balanced` (1080p) was launched. The profile table is read from source and the mapping is mechanical, but unverified for the others. | Relaunch with `TFT_DISPLAY_SIZE`/`TFT_DISPLAY_DENSITY` set per profile and re-run `probe-adb.sh`. Cheap; ~2 min per profile. |
| 4 | The exact cause of the **23% pixel divergence** | Established that it is edge-dominated with a `+8/+8/+7` bias, and that no integer crop or vertical rescale fixes it. Not decomposed into sub-pixel offset vs colour transform. | Capture a synthetic test pattern in the guest (a 1px checkerboard and a greyscale ramp) and compare. Would separate resampling from gamma/colour-space in one shot. |
| 5 | Whether **UI scale** is detectable from pixels reliably | Recommended in §5.2 but not demonstrated. | Launch at 1.0 and 1.5 with the same resolution and diff the shop-row geometry. |
| 6 | Whether Mactician's window can be **fullscreened**, and what that does to chrome insets and scale | Only the default windowed state was observed. | Fullscreen the window, re-run `probe-windows.swift` and `grab-sck-frame.swift`. |

Deviations from a pristine Mactician launch, for honesty about what was
measured:

- The emulator was launched by `scripts/probe/launch-emulator.sh`, which uses
  the **Game Host app wrapper and the same emulator arguments** Mactician uses,
  but **skips** the ANGLE APK-overlay mount and the `hw.gltransport` swap. So
  the window topology, adb surface and geometry are faithful; the guest
  renderer is the stock path rather than Mactician's tuned ANGLE path. This
  should not affect capture-path timings, which are bounded by the adb
  transport and by SCK, not by the guest renderer — but it is a deviation.
- The full Mactician chain was attempted first and failed on a version-pinned
  hash: the launcher pins the overlay APK's SHA-256 to the build it shipped
  with, while the game self-updates (installed `18.1-5392842` vs bundled
  `18.1-5388569`). It restored `config.ini` cleanly on failure both times.
  `scripts/probe/launch-mactician.sh` documents the working env.
- `input keyevent KEYCODE_HOME` was used once, to reach a static Android
  launcher screen for the fidelity control. No input was ever sent to TFT.
