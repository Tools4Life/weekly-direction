#!/bin/bash
# TestFlight build: archive a Release build and either keep the .ipa (default) or upload it to App Store Connect.
#   scripts/testflight.sh            archive + export build/WeeklyDirection.ipa (nothing leaves the Mac)
#   scripts/testflight.sh upload     archive + upload to App Store Connect (shows up in TestFlight after processing)
# Needs: Xcode signed in to the Apple account for team DZJE34VW29 (Settings > Accounts), and, for upload, an app record
# in App Store Connect with bundle id com.redeemedtools.WeeklyDirection. The build number is the time of the build, so
# every upload is newer than the last. No simulator, no debugger.
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-export}"
BUILD="$(date +%Y%m%d%H%M)"
OUT=build
rm -rf "$OUT/WeeklyDirection.xcarchive" "$OUT/export"
mkdir -p "$OUT"
xcodegen >/dev/null
[ -f WeeklyDirection/GoogleService-Info.plist ] || { echo "GoogleService-Info.plist is missing: the app could not sign in"; exit 1; }
echo "archiving build $BUILD…"
xcodebuild -project WeeklyDirection.xcodeproj -scheme WeeklyDirection -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/WeeklyDirection.xcarchive" \
  CURRENT_PROJECT_VERSION="$BUILD" -allowProvisioningUpdates archive 2>&1 | grep -E "error:|warning: .*[Ss]ign|ARCHIVE" || true
[ -d "$OUT/WeeklyDirection.xcarchive" ] || { echo "archive failed"; exit 1; }
DEST=export; [ "$MODE" = "upload" ] && DEST=upload
sed "s/DESTINATION/$DEST/" scripts/ExportOptions.plist > "$OUT/ExportOptions.plist"
echo "$DEST…"
xcodebuild -exportArchive -archivePath "$OUT/WeeklyDirection.xcarchive" -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates 2>&1 | grep -E "error|Error|EXPORT|Upload|upload" || true
if [ "$MODE" = "upload" ]; then echo "done: build $BUILD sent; it appears in TestFlight after Apple finishes processing"
else ls -la "$OUT/export"/*.ipa && echo "done: build $BUILD exported, nothing uploaded"; fi
