# Weekly Direction iOS — handoff for local Claude Code sessions

SwiftUI rewrite of the web app (`../index.html`), personal use only (no App Store). Same Firebase project
(ops-hub-9bebc), same account, same Firestore data: `users/{uid}/weeklyDirection/{settings, draft}` and
`users/{uid}/weeklyDirection/data/{weeks, prayers, library, caffeine}`. The web app is the source of truth for
behavior; read it before porting anything.

## Start here
Read `SPEC.md` (the full build spec) and look at `spec/screens/*.png` (every web screen to replicate).
Fix the known bugs in SPEC section 1 first, then build screen by screen.

## State (Nov 9 2026)
- Phase 1 builds and runs on the owner's iPhone, but it's barebones and read-only, with two bugs (SPEC §1).
- Files: `WeeklyDirectionApp.swift` (entry, tabs), `Store.swift` (auth + live listeners, read-only), `Models.swift`,
  `Rules.swift` (port of the web app's habit rules), `ThisWeekView.swift`, `JournalView.swift`, `SignInView.swift`, `Theme.swift`.
- `project.yml` is an XcodeGen spec; the `.xcodeproj` is generated and git-ignored. Re-run `xcodegen` after adding/removing files.
- `GoogleService-Info.plist` lives in `WeeklyDirection/` locally and is not committed.

## Build and check
```
cd ios && xcodegen
xcodebuild -project WeeklyDirection.xcodeproj -scheme WeeklyDirection \
  -destination 'generic/platform=iOS' build 2>&1 | grep -E "error|warning: unused" | head -40
# Don't boot a simulator or keep the debugger attached: the Mac has 16 GB and lldb alone took 6 GB.
```
Run on the device from Xcode (the owner's iPhone 14 Pro, iOS 18). Signing: automatic, owner's team.

## Rules that must not drift (the owner keeps a strict record)
- `Rules.swift` must match `index.html` exactly: `onDay`, `baseBy`, `byOf`, `deadline`, `hState`, `weekEnd`, `habitDays`.
  Grace: from 2026-11-08, starting within 2 h of the start-by counts on time; after that it's missed and final. No late, no reschedule.
- Writes (phase 2+) must be field-level like the web app's `store.patchWeek` / `store.setDay`; never overwrite a whole week doc
  except when creating a brand-new week. Past days lock at midnight; closed weeks are read-only; no undo for checks or failures.
- Don't change past records unless the app itself got it wrong.
- Journal text (`liveRefl`): blocks separated by a blank line, first line a stamp like `Sunday, 10:22 pm`. Never put blank
  lines inside an entry.

## Phases
1. Read-only shell: sign in, today's habits with live states, this week's journal. ← compile and fix this first
2. Habits: check off, fail, timed habits, day strip, plan and close the week.
3. Reflect: native recording (AVAudioRecorder, m4a) → existing Cloud Function `transcribe`
   (https://us-central1-ops-hub-9bebc.cloudfunctions.net/transcribe, Bearer Firebase ID token, multipart `file`);
   live words via `liveToken` + OpenAI realtime WebRTC; App Intent "Reflect" for Back Tap / Control Center / Siri
   (iPhone 14 Pro has no Action button).
4. Progress, prayer, settings, native notifications (local notifications for start-by and grace ending).

## Owner preferences
Blunt, no praise, lead with the strongest counterargument, explicit confidence levels. Act directly on obvious fixes.
Always add a Bible verse to habit About notes. Commit with clear messages; push to `main`.
