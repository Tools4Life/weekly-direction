#!/bin/bash
# Unit tests on the one dedicated simulator ("Weekly Direction Tests", iPhone 14 Pro), no debugger.
# Every simulator is shut down afterwards (the Mac has 16 GB).
set -uo pipefail
cd "$(dirname "$0")/.."
SIM="Weekly Direction Tests"
xcrun simctl list devices | grep -q "$SIM (" || xcrun simctl create "$SIM" "iPhone 14 Pro" >/dev/null
[ -d WeeklyDirection.xcodeproj ] || xcodegen >/dev/null
trap 'xcrun simctl shutdown all >/dev/null 2>&1 || true' EXIT
START=$(date +%s)
xcodebuild test -project WeeklyDirection.xcodeproj -scheme WeeklyDirection -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath build/sim CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 60 ${TEST_ARGS:-} 2>&1 | tee build/test.log \
  | grep -E "error:|Test Case .* (passed|failed)|XCTAssert|\*\* TEST" | grep -v SourcePackages
P=$(grep -c "Test Case .* passed" build/test.log); F=$(grep -c "Test Case .* failed" build/test.log)
echo "summary: $P passed, $F failed, $(( $(date +%s) - START ))s, serial"
[ "$F" = "0" ] && [ "$P" != "0" ]
