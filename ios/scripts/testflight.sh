#!/bin/bash
# TestFlight build: archive a Release build and either keep the .ipa (default) or upload it to App Store Connect.
#   scripts/testflight.sh            archive + export build/WeeklyDirection.ipa (nothing leaves the Mac)
#   scripts/testflight.sh upload     archive + upload to App Store Connect (shows up in TestFlight after processing)
# Needs: Xcode signed in to the Apple account for team DZJE34VW29 (Settings > Accounts), and, for upload, an app record
# in App Store Connect with bundle id com.redeemedtools.WeeklyDirection. The build number counts up by one per upload (1, 2, 3…),
# kept in scripts/build-number; commit that file after an upload. Version 0.1 used time-stamped numbers, so the count
# starts at 0.2 (Apple wants each build of a version higher than the last). No simulator, no debugger.
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-export}"
BUILD=$(( $(cat scripts/build-number 2>/dev/null || echo 0) + 1 ))
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
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates > "$OUT/export.log" 2>&1 || true
grep -E "error|Error|EXPORT|Upload|upload|App record" "$OUT/export.log" || true
grep -q "EXPORT SUCCEEDED" "$OUT/export.log" || { echo "FAILED: build $BUILD was NOT $([ "$MODE" = upload ] && echo uploaded || echo exported) (full log: $OUT/export.log)"; exit 1; }
if [ "$MODE" = "upload" ]; then echo "$BUILD" > scripts/build-number; echo "done: build $BUILD sent; it appears in TestFlight after Apple finishes processing"
else ls -la "$OUT/export"/*.ipa && echo "done: build $BUILD exported, nothing uploaded"; fi
