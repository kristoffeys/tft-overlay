#!/bin/zsh
# Benchmark adb capture paths against the Mactician guest.
#
# Three variants:
#   raw  : adb exec-out screencap            -> RGBA + 12/16-byte header, no encode
#   png  : adb exec-out screencap -p         -> PNG encoded in the guest
#   file : screencap to /sdcard then adb pull (baseline, expected slowest)
#
# Usage: bench-adb-screencap.sh [iterations]   (default 30)
set -uo pipefail
source "${0:A:h}/adbenv.sh"

ITERS="${1:-30}"
OUT="${TMPDIR:-/tmp}/mactician-bench.$$"
mkdir -p "$OUT"

adbx get-state >/dev/null 2>&1 || { print "$SERIAL not up"; exit 1; }

now_ms() { python3 -c 'import time;print(int(time.time()*1000))'; }

bench() {
    local label="$1"; shift
    local -a times
    local i start end bytes total=0
    # warm-up
    "$@" > "$OUT/warm.bin" 2>/dev/null
    bytes=$(stat -f%z "$OUT/warm.bin")
    for i in {1..$ITERS}; do
        start=$(python3 -c 'import time;print(time.perf_counter_ns())')
        "$@" > "$OUT/f.bin" 2>/dev/null
        end=$(python3 -c 'import time;print(time.perf_counter_ns())')
        times+=$(( (end - start) / 1000000 ))
    done
    local sorted=(${(n)times})
    local n=${#sorted}
    local p50=${sorted[$(( (n+1)/2 ))]}
    local p95=${sorted[$(( n*95/100 == 0 ? 1 : n*95/100 ))]}
    local min=${sorted[1]} max=${sorted[$n]}
    for i in $times; do (( total += i )); done
    local mean=$(( total / n ))
    printf "%-6s n=%-3d bytes=%-9d min=%-5d p50=%-5d mean=%-5d p95=%-5d max=%-5d  max_fps=%.1f\n" \
        "$label" "$n" "$bytes" "$min" "$p50" "$mean" "$p95" "$max" \
        "$(python3 -c "print(1000.0/max($p50,1))")"
}

print "== adb capture benchmark ($ITERS iterations, serial $SERIAL) =="
bench raw adbx exec-out screencap
bench png adbx exec-out screencap -p

print "\n== file+pull baseline (5 iterations) =="
local -a ft
for i in {1..5}; do
    s=$(python3 -c 'import time;print(time.perf_counter_ns())')
    adbx shell screencap -p /sdcard/bench.png >/dev/null 2>&1
    adbx pull /sdcard/bench.png "$OUT/pull.png" >/dev/null 2>&1
    e=$(python3 -c 'import time;print(time.perf_counter_ns())')
    ft+=$(( (e - s) / 1000000 ))
done
print "file   samples(ms): ${ft[*]}"
adbx shell rm -f /sdcard/bench.png >/dev/null 2>&1

print "\n== raw frame header (width, height, format) =="
adbx exec-out screencap > "$OUT/raw.bin" 2>/dev/null
python3 - "$OUT/raw.bin" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
w, h, f = struct.unpack('<III', d[:12])
print(f"width={w} height={h} pixelformat={f} totalbytes={len(d)}")
for hdr in (12, 16):
    exp = w * h * 4 + hdr
    print(f"  header={hdr}B -> expected {exp} ({'MATCH' if exp == len(d) else 'no'})")
PY

print "\n== fidelity: PNG dimensions =="
adbx exec-out screencap -p > "$OUT/shot.png" 2>/dev/null
python3 -c "
import struct,sys
d=open('$OUT/shot.png','rb').read()
print('png', struct.unpack('>II', d[16:24]), 'bytes', len(d))
"
cp "$OUT/shot.png" "${TMPDIR:-/tmp}/mactician-guest.png"
print "saved sample frame: ${TMPDIR:-/tmp}/mactician-guest.png"
rm -rf "$OUT"
