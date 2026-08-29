#!/bin/zsh
# Shared environment for Mactician probes.
#
# Mactician runs its OWN adb server on port 5038 with its OWN bundled adb
# binary (platform-tools 36.0.2). Using a different adb client version against
# that server makes adb kill and restart the server, which breaks Mactician's
# running launcher. Always source this file and use $ADB / $ADB_PORT.

export MACTICIAN_SUPPORT="${MACTICIAN_SUPPORT:-$HOME/Library/Application Support/Mactician}"
export ADB="${TFT_ADB:-$MACTICIAN_SUPPORT/sdk/platform-tools/adb}"
export ADB_PORT="${TFT_ADB_SERVER_PORT:-5038}"
export SERIAL="${TFT_SERIAL:-emulator-5582}"
export PACKAGE="com.riotgames.league.teamfighttactics"

# Never let a bare `adb` call fork a daemon on the default port and block.
export ANDROID_ADB_SERVER_PORT="$ADB_PORT"

adbx() { "$ADB" -P "$ADB_PORT" -s "$SERIAL" "$@"; }
adbs() { "$ADB" -P "$ADB_PORT" "$@"; }
