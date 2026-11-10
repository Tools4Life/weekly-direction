#!/bin/bash
# Build, install and open the app on Eddie's connected iPhone without Xcode Run and without the debugger.
#   scripts/device.sh            the first connected iPhone
#   DEVICE=<udid> scripts/device.sh
# Needs the phone unlocked and connected (cable or same Wi-Fi), and Xcode signed in for team DZJE34VW29.
set -euo pipefail
cd "$(dirname "$0")/.."
DEV="${DEVICE:-$(xcrun devicectl list devices 2>/dev/null | awk '/connected/ && /iPhone/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')}"
[ -n "$DEV" ] || { echo "no connected iPhone: plug it in and unlock it"; exit 1; }
xcodegen >/dev/null
echo "building for $DEV…"
xcodebuild -project WeeklyDirection.xcodeproj -scheme WeeklyDirection -configuration Debug \
  -destination "id=$DEV" -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD" || true
APP="$(xcodebuild -project WeeklyDirection.xcodeproj -scheme WeeklyDirection -configuration Debug -destination "id=$DEV" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ TARGET_BUILD_DIR/{d=$2} / WRAPPER_NAME/{w=$2} END{print d"/"w}')"
[ -d "$APP" ] || { echo "build failed: no app at $APP"; exit 1; }
xcrun devicectl device install app --device "$DEV" "$APP" 2>&1 | tail -3
xcrun devicectl device process launch --device "$DEV" --terminate-existing com.redeemedtools.WeeklyDirection 2>&1 | tail -2
