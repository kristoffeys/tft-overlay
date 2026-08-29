#!/bin/zsh
# Reachability + guest geometry + non-pixel state signals over adb.
set -uo pipefail
source "${0:A:h}/adbenv.sh"

print "== adb binary =="; "$ADB" version | head -2
print "\n== devices on Mactician server (port $ADB_PORT) =="
adbs devices -l
print "\n== devices on DEFAULT server (port 5037) — does a stock adb see it? =="
"$ADB" -P 5037 devices -l 2>&1 | head -5

adbx get-state >/dev/null 2>&1 || { print "\n$SERIAL is not up; stopping here."; exit 1; }

print "\n== guest geometry =="
adbx shell wm size
adbx shell wm density
adbx shell dumpsys display 2>/dev/null | grep -E 'mBaseDisplayInfo|real [0-9]+ x|deviceWidth|density' | head -6

print "\n== relevant props =="
adbx shell getprop | grep -iE 'gltransport|sf\.|ro\.kernel\.qemu|boot_completed|mactician' | tr -d '\r' | head -20

print "\n== game package =="
adbx shell pm path "$PACKAGE" | tr -d '\r'
adbx shell dumpsys package "$PACKAGE" 2>/dev/null | grep -E 'versionName|versionCode' | head -2 | tr -d '\r'
adbx shell pidof "$PACKAGE" | tr -d '\r'

print "\n== foreground activity (non-pixel state signal, issue #52) =="
adbx shell dumpsys activity activities 2>/dev/null \
    | grep -E 'mResumedActivity|topResumedActivity|mFocusedApp|ResumedActivity' | tr -d '\r' | head -6
print -r -- "-- dumpsys window --"
adbx shell dumpsys window 2>/dev/null \
    | grep -E 'mCurrentFocus|mFocusedApp|mFocusedWindow' | tr -d '\r' | head -6
print -r -- "-- activity top (task stack) --"
adbx shell dumpsys activity top 2>/dev/null | grep -E 'ACTIVITY|TASK' | tr -d '\r' | head -8
