#!/usr/bin/env python3
"""Decompose adb capture latency: client spawn vs transport vs guest capture.

Without this split, `adb exec-out screencap` timings are unattributable — a
slow number could be our harness forking a client per frame rather than the
capture path itself. Times every stage with the same timer, in-process.
"""
import os, statistics, subprocess, sys, time

SUP = os.path.expanduser("~/Library/Application Support/Mactician")
ADB = os.environ.get("TFT_ADB", f"{SUP}/sdk/platform-tools/adb")
PORT = os.environ.get("TFT_ADB_SERVER_PORT", "5038")
SERIAL = os.environ.get("TFT_SERIAL", "emulator-5582")
BASE = [ADB, "-P", PORT, "-s", SERIAL]
N = int(sys.argv[1]) if len(sys.argv) > 1 else 20


def run(args, n=N):
    subprocess.run(BASE + args, capture_output=True)  # warm
    times, nbytes = [], 0
    for _ in range(n):
        t0 = time.perf_counter()
        p = subprocess.run(BASE + args, capture_output=True)
        times.append((time.perf_counter() - t0) * 1000)
        nbytes = len(p.stdout)
    times.sort()
    return times, nbytes


def show(label, times, nbytes, note=""):
    n = len(times)
    p50 = times[n // 2]
    print(f"{label:<34} n={n:<3} bytes={nbytes:<9} "
          f"min={times[0]:6.1f} p50={p50:6.1f} mean={statistics.mean(times):6.1f} "
          f"p95={times[int(n*.95)-1]:6.1f} max={times[-1]:6.1f}  "
          f"ceil_fps={1000/p50:5.2f}  {note}")


print(f"adb={ADB}  port={PORT}  serial={SERIAL}\n")
print("--- stage decomposition ---")
show("client spawn + connect (true)", *run(["shell", "true"]))
show("guest exec only (echo)", *run(["shell", "echo", "x"]))
show("transport 8MB (cat 8MB zeros)",
     *run(["exec-out", "dd", "if=/dev/zero", "bs=1048576", "count=8"]),
     note="<- pure adb pipe throughput")
print()
print("--- capture paths ---")
show("screencap raw (RGBA)", *run(["exec-out", "screencap"]))
show("screencap -p (PNG in guest)", *run(["exec-out", "screencap", "-p"]))

# Does a persistent shell amortize the per-frame client spawn?
print("\n--- persistent connection (one adb process, N frames) ---")
t0 = time.perf_counter()
script = "for i in $(seq 1 %d); do screencap > /dev/null; done" % N
subprocess.run(BASE + ["shell", script], capture_output=True)
dt = (time.perf_counter() - t0) * 1000
print(f"{'screencap to /dev/null, in-guest loop':<34} "
      f"total={dt:.0f}ms  per_frame={dt/N:.1f}ms  ceil_fps={1000/(dt/N):.2f}"
      f"   <- guest-side capture cost with NO host transport at all")
