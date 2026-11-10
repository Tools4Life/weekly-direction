# Weekly Direction iOS — handoff for local Claude Code sessions

SwiftUI rewrite of the web app (`../index.html`), personal use only (no App Store). Same Firebase project
(ops-hub-9bebc), same account, same Firestore data: `users/{uid}/weeklyDirection/{settings, draft}` and
`users/{uid}/weeklyDirection/data/{weeks, prayers, library, caffeine}`. The web app is the source of truth for
behavior; read it before porting anything.

## Start here
Read `SPEC.md` (the full build spec) and look at `spec/screens/*.png` (every web screen to replicate).
SPEC section 1 bugs are fixed and every section 3 screen is built (see State).

## State (Nov 9 2026, end of run DAY-2026-11-09)
- Every screen in SPEC §3 is built and compiles for device. Checked on the simulator with sample data only; **no write has
  been tested on a real account or on the phone**. `docs/PROGRESS.md` (top line = current item) has the device checklist.
- After any context compaction, reread this file and `docs/PROGRESS.md` before continuing.
- Files: `Store.swift` (auth, listeners, the web store's field-level writes), `Actions.swift` (setItem / fail / saveAbout),
  `Rules.swift` + `Logic.swift` (ports of the web rules and derived values), `Router.swift` (what is on screen),
  one file per screen, `Recorder.swift`, `Notifier.swift`, `Intents.swift`, `Mock.swift` (sample data).
- `project.yml` is an XcodeGen spec; the `.xcodeproj` is generated and git-ignored. Re-run `xcodegen` after adding/removing files.
  Keep `scheme`, `DEVELOPMENT_TEAM` and the `info:` block (UIAppFonts) or Run / signing / fonts break after regenerating.
- `GoogleService-Info.plist` lives in `WeeklyDirection/` locally and is not committed.

## Layout since Nov 9 2026 (differs from the web on purpose, Eddie's call)
Tab bar: This Week, Journal (`JournalList.swift`), mic (records from any screen), Prayer, Progress. This Week shows the latest
thought under the habits. Names, rows and buttons use condensed caps (`.caps()`); page titles and journal text stay serif.
Rejected design findings stay behind launch arguments in sample-data mode only: `-MockPalette focus`, `-MockStyle 1/2`.

## Build, test and screenshots
```
cd ios && xcodegen
xcodebuild -project WeeklyDirection.xcodeproj -scheme WeeklyDirection \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning:|BUILD"
scripts/test.sh                      # XCTest (rules, write fields, journal, reminders) on the dedicated simulator
scripts/shot.sh week stats close     # screenshots with sample data → docs/screenshots/latest/
scripts/device.sh                    # build, install and open on the connected iPhone (devicectl; no Xcode Run, no debugger)
scripts/testflight.sh                # Release archive + local .ipa in build/; `scripts/testflight.sh upload` sends it to TestFlight (ask Eddie first)
```
Simulator rule (Eddie, 2026-11-09): one simulator only ("Weekly Direction Tests", iPhone 14 Pro), booted only for tests and
screenshots, launched with simctl (never Xcode Run, never the debugger); both scripts shut every simulator down when done.
The Mac has 16 GB and lldb alone took 6 GB. Run on the device from Xcode (iPhone 14 Pro, iOS 18). Signing: automatic.

Launch arguments: `-UITestSeed 1` (sample data, no Firebase, writes stay in memory), `-OpenScreen <name>` (see
`Router.open`), `-MockNow 2026-11-14T17:30`, `-MockTheme light`. Each new screen gets an `-OpenScreen` name.

## Working method (from ~/Desktop/APP-BUILD-PLAYBOOK.md)
Small steps, commit after each, keep `docs/PROGRESS.md` current, run file in `docs/runs/`. Visual contract: `spec/screens/*.png`.
Every report shows the simulator shot next to the reference, says what was not verified, and ends with
"NEXT ACTION FOR EDDIE: …". Never claim something works on the device until Eddie has tested it.

## Known pitfalls
- A failing XCTest assertion hangs (XCTest stalls collecting the failure's call stack) instead of printing. `scripts/test.sh`
  caps each test at 60 s; a test that "exceeded execution time allowance" is a failed assertion: print the actual values.
- Opening Plan must not write a draft: field `onChange` handlers fire while the form loads (`ready` flag in PlanView).
- A merge write deletes with `Store.del`, never `NSNull` (NSNull is a real null, which the web app also writes when sealing).
- `git push` has no credentials in the Claude shell; Eddie pushes.
- SPEC §2 is wrong about two functions; follow the web app: `transcribe` takes the raw audio body (Content-Type, X-Duration),
  `summarize` takes `{text, focus}` and the client writes `summary` + `summaryAt`.

## Rules that must not drift (the owner keeps a strict record)
- `Rules.swift` must match `index.html` exactly: `onDay`, `baseBy`, `byOf`, `deadline`, `hState`, `weekEnd`, `habitDays`.
  Grace: from 2026-11-08, starting within 2 h of the start-by counts on time; after that it's missed and final. No late, no reschedule.
- Writes (phase 2+) must be field-level like the web app's `store.patchWeek` / `store.setDay`; never overwrite a whole week doc
  except when creating a brand-new week. Past days lock at midnight; closed weeks are read-only; no undo for checks or failures.
- Don't change past records unless the app itself got it wrong.
- Journal text (`liveRefl`): blocks separated by a blank line, first line a stamp like `Sunday, 10:22 pm`. Never put blank
  lines inside an entry.

## Phases (all built in run DAY-2026-11-09; next is Eddie's device test, then a FIXES run from his findings)
1. Read-only shell: sign in, today's habits with live states, this week's journal.
2. Habits: check off, fail, timed habits, day strip, plan and close the week.
3. Reflect: native recording (AVAudioRecorder, m4a) → existing Cloud Function `transcribe`
   (https://us-central1-ops-hub-9bebc.cloudfunctions.net/transcribe, Bearer Firebase ID token, multipart `file`);
   live words via `liveToken` + OpenAI realtime WebRTC; App Intent "Reflect" for Back Tap / Control Center / Siri
   (iPhone 14 Pro has no Action button).
4. Progress, prayer, settings, native notifications (local notifications for start-by and grace ending).

## Owner preferences
Blunt, no praise, lead with the strongest counterargument, explicit confidence levels. Act directly on obvious fixes.
Always add a Bible verse to habit About notes. Commit with clear messages; push to `main`.
