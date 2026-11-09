# Weekly Direction for iPhone (SwiftUI)

Native rewrite of the web app. Same Firebase project (ops-hub-9bebc), same account, same data:
whatever you do in one shows up in the other.

## Phases
1. **Read-only shell** (this build): sign in, today's habits with live states (on time, grace, missed), this week's journal.
2. **Habits**: check off, fail, timed habits, day strip, plan and close the week. Every write mirrors the web app's rules.
3. **Reflect**: native recording, live words, transcription through the existing Cloud Functions, Action button shortcut.
4. **Progress, prayer, settings, native notifications.**

Until phase 2 lands, use the web app for anything that changes your record.

## First-time setup on the Mac
1. Install XcodeGen once: `brew install xcodegen`
2. In the Firebase console (project ops-hub-9bebc) → Project settings → **Add app → iOS**, bundle ID `com.redeemedtools.WeeklyDirection`.
   Download **GoogleService-Info.plist** and put it in `ios/WeeklyDirection/`.
3. Generate and open the project:
   ```
   cd ~/Desktop/weekly-direction/ios
   xcodegen
   open WeeklyDirection.xcodeproj
   ```
4. In Xcode: select the WeeklyDirection target → Signing & Capabilities → pick your team.
5. Plug in the iPhone, choose it as the run destination, press Run.

Re-run `xcodegen` whenever files are added or removed (the .xcodeproj is generated, not committed).

## Rules
`Rules.swift` is a port of the web app's habit rules (grace window, start-by, sealing day).
The record is strict, so the two must stay identical: change both together.
