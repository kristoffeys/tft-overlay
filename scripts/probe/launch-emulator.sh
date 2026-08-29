#!/bin/zsh
# Launch just the Android emulator the way Mactician's run-tft-root-affinity
# launcher does — through the "Mactician Game Host.app" wrapper, with the same
# AVD, port, skin and GPU mode — without the ANGLE APK-overlay transaction.
#
# This reproduces Mactician's process/window topology faithfully while keeping
# the probe cheap and side-effect-free (no guest mounts, no config.ini swap).
set -uo pipefail
source "${0:A:h}/adbenv.sh"

RP="$MACTICIAN_SUPPORT/runtime-project"
export ANDROID_SDK_ROOT="$MACTICIAN_SUPPORT/sdk"
export ANDROID_AVD_HOME="$MACTICIAN_SUPPORT/avd"
export ANDROID_ADB_SERVER_PORT="$ADB_PORT"

DISPLAY_SIZE="${TFT_DISPLAY_SIZE:-1920x1080}"

"$ADB" -P "$ADB_PORT" start-server >/dev/null 2>&1

/usr/bin/open -n -W \
    --env "TFT_EMULATOR=$ANDROID_SDK_ROOT/emulator/emulator" \
    --env "TFT_ADB_SERVER_PORT=$ADB_PORT" \
    --env "ANDROID_ADB_SERVER_PORT=$ADB_PORT" \
    --env "ADB_MDNS_AUTO_CONNECT=" \
    --env "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" \
    --env "ANDROID_AVD_HOME=$ANDROID_AVD_HOME" \
    "$RP/Mactician Game Host.app" --args \
    "@Tft" -id "TFT-Tft" -port "${SERIAL#emulator-}" -gpu host \
    -skin "$DISPLAY_SIZE" -vsync-rate 60 -dns-server 1.1.1.1,8.8.8.8 \
    -cores "${TFT_CPU_CORES:-6}" -memory "${TFT_MEMORY_MB:-6144}" \
    -no-snapshot -no-metrics -no-boot-anim -crash-report-mode disabled
