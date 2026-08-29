#!/bin/zsh
# Launch the Mactician runtime headlessly (no SwiftUI launcher click), using
# the app's own MIT-licensed launcher chain and its documented TFT_* interface.
#
#   launcher-runtime.command
#     -> scripts/run-asg-experiment.command   (swaps hw.gltransport, restores on exit)
#          -> run-tft-angle-opengl.command
#               -> run-tft-root-affinity.command
#                    -> open -n -W "Mactician Game Host.app" --args @Tft -port 5582 ...
#
# Emits one JSON line per lifecycle event on stdout (booting/emulator_started/
# ready/game_stopped/stopped). Full emulator output goes to $TFT_LAUNCH_LOG.
set -uo pipefail

RP="$HOME/Library/Application Support/Mactician/runtime-project"
export TFT_RUNTIME_PROJECT="$RP"
export TFT_LAUNCH_LOG="${TFT_LAUNCH_LOG:-${TMPDIR:-/tmp}/mactician-probe-launch.log}"
export TFT_ADB="$HOME/Library/Application Support/Mactician/sdk/platform-tools/adb"
export TFT_AVD_HOME="$HOME/Library/Application Support/Mactician/avd"
export TFT_AVD_NAME="Tft"
export TFT_SERIAL="emulator-5582"
export TFT_ADB_SERVER_PORT="5038"

# 1080p "balanced" profile from Mactician's release-manifest.json.
export TFT_DISPLAY_SIZE="${TFT_DISPLAY_SIZE:-1920x1080}"
export TFT_DISPLAY_DENSITY="${TFT_DISPLAY_DENSITY:-320}"
export TFT_UI_SCALE="${TFT_UI_SCALE:-1.0}"
export TFT_GAME_LANGUAGE="en-US"
export TFT_CPU_CORES="${TFT_CPU_CORES:-6}"
export TFT_MEMORY_MB="${TFT_MEMORY_MB:-6144}"

# run-asg-experiment defaults TFT_LAUNCHER to a script that does not ship.
export TFT_LAUNCHER="$RP/run-tft-angle-opengl.command"
# tools/tft-input-bridge.swift is not shipped in the installed runtime; the
# launcher hard-fails if the bridge is left enabled.
export TFT_INPUT_BRIDGE_ENABLED=0
# artifacts/ ships four named DeviceProfiles variants, not the default name.
PROF="$RP/artifacts/tft-18.1-angle-opengl/Android_Codex.DeviceProfiles.effects-performance.ini"
export TFT_ANGLE_OPENGL_PROFILE="$PROF"
export TFT_ANGLE_OPENGL_PROFILE_SHA256="$(shasum -a 256 "$PROF" | awk '{print $1}')"
# The launcher pins the overlay APK hash to the version it shipped with; the
# game self-updates, so pin to the hash of the artifact actually installed.
APK="$RP/artifacts/tft-18.1-angle-opengl/base-angle-opengl.apk"
export TFT_ANGLE_OPENGL_APK_SHA256="$(shasum -a 256 "$APK" | awk '{print $1}')"

: > "$TFT_LAUNCH_LOG"
exec /Applications/Mactician.app/Contents/Resources/launcher-runtime.command
