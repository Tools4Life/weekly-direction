#!/bin/bash
# Simulator screenshots with sample data, no debugger.
#   scripts/shot.sh <screen> [<screen> ...]        e.g. scripts/shot.sh week habit vision
#   SHOT_ARGS="-MockNow 2026-11-14T17:30" scripts/shot.sh week     extra launch arguments
#   SHOT_DIR=docs/screenshots/latest (default)
# Screens are the names Router.open(screen:) knows (-OpenScreen). One simulator only ("Weekly Direction Tests",
# an iPhone 14 Pro); it is booted for the shots and every simulator is shut down at the end (the Mac has 16 GB).
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="Weekly Direction Tests"
OUT="${SHOT_DIR:-docs/screenshots/latest}"
BUNDLE=com.redeemedtools.WeeklyDirection
mkdir -p "$OUT"
xcrun simctl list devices | grep -q "$SIM (" || xcrun simctl create "$SIM" "iPhone 14 Pro" >/dev/null
[ -d WeeklyDirection.xcodeproj ] || xcodegen >/dev/null
if [ -z "${SHOT_NOBUILD:-}" ]; then
  xcodebuild -project WeeklyDirection.xcodeproj -scheme WeeklyDirection -destination "platform=iOS Simulator,name=$SIM" \
    -derivedDataPath build/sim CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD" | grep -v SourcePackages || true
fi
APP=build/sim/Build/Products/Debug-iphonesimulator/WeeklyDirection.app
[ -d "$APP" ] || { echo "no simulator build at $APP"; exit 1; }
trap 'xcrun simctl shutdown all >/dev/null 2>&1 || true' EXIT
xcrun simctl shutdown all >/dev/null 2>&1 || true
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" >/dev/null
xcrun simctl status_bar "$SIM" override --time "10:00" --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$APP"
for s in "$@"; do
  xcrun simctl terminate "$SIM" $BUNDLE >/dev/null 2>&1 || true
  # shellcheck disable=SC2086
  xcrun simctl launch "$SIM" $BUNDLE -UITestSeed 1 -OpenScreen "$s" ${SHOT_ARGS:-} >/dev/null
  sleep "${SHOT_WAIT:-3}"
  xcrun simctl io "$SIM" screenshot "$OUT/$s${SHOT_SUFFIX:-}.png" >/dev/null 2>&1
  echo "shot: $OUT/$s.png"
done
