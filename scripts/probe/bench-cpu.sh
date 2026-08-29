#!/bin/zsh
# Host CPU cost of each capture path, sampled while the path runs.
# Reports %CPU for the emulator (qemu-system-aarch64) and for the capturing
# process itself.
set -uo pipefail
source "${0:A:h}/adbenv.sh"
QPID=$(pgrep -f 'qemu-system-aarch64.*-port 5582' | head -1)
[[ -z "$QPID" ]] && { print "emulator not running"; exit 1; }

sample() {  # sample <label> <seconds> [extra-pid]
    local label="$1" secs="$2" extra="${3:-}"
    local -a q e
    for i in {1..$secs}; do
        /bin/sleep 1
        q+=$(ps -o %cpu= -p "$QPID" | tr -d ' ')
        [[ -n "$extra" ]] && e+=$(ps -o %cpu= -p "$extra" 2>/dev/null | tr -d ' ')
    done
    local qm=$(python3 -c "v=[float(x) for x in '${q[*]}'.split()];print(f'{sum(v)/len(v):.1f}')")
    local em="n/a"
    [[ -n "$extra" && ${#e} -gt 0 ]] && em=$(python3 -c "
v=[float(x) for x in '${e[*]}'.split() if x]
print(f'{sum(v)/len(v):.1f}' if v else 'n/a')")
    printf "%-28s qemu=%6s%%  capturer=%6s%%\n" "$label" "$qm" "$em"
}

print "== host CPU (%% of one core; sampled 8s each) =="
sample "idle (no capture)" 8

# adb screencap loop
( while :; do "$ADB" -P "$ADB_PORT" -s "$SERIAL" exec-out screencap >/dev/null 2>&1; done ) &
LOOP=$!
sample "adb screencap loop" 8 "$(pgrep -f 'adb -P 5038' | tail -1)"
kill $LOOP 2>/dev/null; pkill -f "exec-out screencap" 2>/dev/null

# ScreenCaptureKit
swift "${0:A:h}/bench-sck.swift" Mactician 10 >/dev/null 2>&1 &
SCKPID=$!
/bin/sleep 2
sample "ScreenCaptureKit stream" 7 "$SCKPID"
wait $SCKPID 2>/dev/null
