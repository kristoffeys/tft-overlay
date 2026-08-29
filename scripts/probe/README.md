# Mactician host probes

Throwaway, reproducible probes behind
[`docs/research/mactician-host.md`](../../docs/research/mactician-host.md) and
[ADR 0003](../../docs/adr/0003-game-host.md). Not part of the app; not built by
CI. They exist so the numbers in those documents can be re-measured rather than
trusted.

Everything here is **read-only against the game**: adb queries, window
enumeration and screen capture. No process memory is read and nothing is
injected, on host or guest.

## Prerequisites

- Mactician installed at `/Applications/Mactician.app`, set up at least once
  (so `~/Library/Application Support/Mactician/` has `sdk/`, `avd/Tft.avd`).
- Swift toolchain (`swift`, for the two `.swift` probes).
- `python3` with `numpy` and `Pillow`, for `compare-frames.py` only.
- Screen Recording permission for the terminal running the ScreenCaptureKit
  probes. `bench-sck.swift` prints its own preflight result first.

## The one thing to know before running anything

Mactician runs **its own adb server on port 5038** with **its own adb binary**
(platform-tools 36.0.2). Pointing a different adb client version at that server
makes adb kill and restart it, dropping the transport under Mactician's running
launcher.

`adbenv.sh` resolves the right binary, port (5038) and serial
(`emulator-5582`). Source it; never call a bare `adb`.

A bare `adb devices` also blocks the calling shell while it forks its daemon —
run `adb -P 5038 start-server` first.

## Scripts

| Script | What it answers |
|---|---|
| `adbenv.sh` | Shared env. `source` this; provides `$ADB`, `$ADB_PORT`, `$SERIAL`, and `adbx`/`adbs` helpers. |
| `launch-emulator.sh` | Starts the emulator the way Mactician does — through the `Mactician Game Host.app` wrapper, same args — without the ANGLE overlay mount. This is what the measurements ran against. |
| `launch-mactician.sh` | The *full* Mactician chain via `launcher-runtime.command`, documenting the complete `TFT_*` environment it needs. See the caveat below. |
| `probe-windows.swift` | Window topology: owner, pid, layer, bounds, title. Optional substring filter. |
| `probe-adb.sh` | adb reachability (both ports), guest geometry, package version, foreground activity. |
| `bench-adb-screencap.sh` | End-to-end `screencap` timings: raw vs PNG vs file+pull. |
| `bench-adb-decompose.py` | **The useful one.** Splits adb latency into client spawn / pipe throughput / guest capture, so a slow number is attributable. |
| `bench-sck.swift` | ScreenCaptureKit frame rate and interframe distribution for a window. |
| `bench-cpu.sh` | Host CPU cost of each capture path, sampled while it runs. |
| `grab-sck-frame.swift` | One SCK frame to PNG, for fidelity diffing. |
| `compare-frames.py` | Diffs an SCK frame against an adb frame: geometry, crop offset search, per-channel bias, edge-vs-flat error split. |

## Typical run

```sh
cd <repo root>

# 1. bring the emulator up (blocks until it exits; run it backgrounded)
./scripts/probe/launch-emulator.sh &

# 2. wait for the guest
source scripts/probe/adbenv.sh
until [ "$(adbx get-state 2>/dev/null)" = device ]; do sleep 2; done
until [ "$(adbx shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done

# 3. topology + reachability + geometry
swift scripts/probe/probe-windows.swift Mactician
./scripts/probe/probe-adb.sh

# 4. benchmarks
python3 scripts/probe/bench-adb-decompose.py 20
swift  scripts/probe/bench-sck.swift Mactician 6
./scripts/probe/bench-cpu.sh

# 5. fidelity (do this on a STATIC guest screen, and keep the control)
adbx exec-out screencap -p > /tmp/a1.png
swift scripts/probe/grab-sck-frame.swift Mactician /tmp/sck.png
adbx exec-out screencap -p > /tmp/a2.png     # control: a1 == a2 or the test is void
python3 scripts/probe/compare-frames.py /tmp/sck.png /tmp/a1.png
```

Optionally launch TFT itself for a realistic GPU load:

```sh
adbx shell am start -n com.riotgames.league.teamfighttactics/com.epicgames.unreal.SplashActivity
```

Shut down with `adbx emu kill`.

## Caveat on `launch-mactician.sh`

It reproduces the full chain, but the launcher pins the overlay APK's SHA-256
to the build Mactician shipped with, while the game self-updates — so a stock
run fails with *"The ANGLE/OpenGL APK SHA-256 does not match the verified
value."* The script therefore pins to the hash of the artifact actually
installed. It also has to set `TFT_LAUNCHER` (the default points at a script
that does not ship), `TFT_INPUT_BRIDGE_ENABLED=0` (`tools/` is not shipped) and
an explicit `TFT_ANGLE_OPENGL_PROFILE` (the four shipped profiles use suffixed
names).

The launcher restores `config.ini` and `hardware-qemu.ini` from sidecar backups
on exit, including after a failure — verified across both failed attempts here.

`launch-emulator.sh` is the safer probe and is what the published numbers used;
it touches no guest state and swaps no config.

## Caveat on measurement conditions

The published numbers were taken at the **TFT home screen**, not inside a live
match, and only at the **1080p** profile with the window at its default size.
Open questions and what would close them are listed in §8 of the findings doc.
