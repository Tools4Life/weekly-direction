# Weekly Direction iOS — progress log

**Current: run DAY-2026-11-09 DONE; waiting for Eddie's device test.** Every SPEC §3 screen is built; simulator-checked with sample data, nothing verified on the phone, nothing pushed (no git credentials in the Claude shell).

## Run DAY-2026-11-09 (see docs/runs/DAY-2026-11-09.md)

| Item | Result | Proof |
|---|---|---|
| §1.1 journal parser | Ported from the web's rfBlocks; script-checked against sample text. Cause of the phone's "Nothing yet this week" NOT confirmed (old parser was logically equivalent). | commit 6233d45 |
| §1.2 Reflect pillarbox | Content takes full width | shots reflect*.png |
| §1.3 fonts | Fraunces, Barlow, Barlow Condensed bundled + UIAppFonts | every shot |
| 3.1 This Week | Built | docs/screenshots/latest/week.png, week-day.png vs spec 01, 02 |
| 3.2 Habit sheet | Built | habit.png vs spec 03 |
| 3.3 Timer focus | Built | focus.png (no reference image) |
| 3.4 Vision | Built | vision.png vs spec 05 |
| 3.5 Journal | Built | reflect, reflect-past, week-page, week-page-select, entry-menu, edit, write vs spec 10–16 |
| 3.6 Recording | Built; audio, live words, upload, queue, intent NOT exercised (simulator shows sample words only) | recording.png vs spec 17 |
| 3.7 Prayer | Built | prayer, prayer-open vs spec 18, 19 |
| 3.8 Progress | Built | progress, progress-habits vs spec 20, 21 |
| 3.9 Stats | Built; sample week's numbers equal the reference (10/13, 100% · 7/7, 1/2/1) | stats, stats-all vs spec 22–24; testWeekStatsAndCells |
| 3.10 Close | Built | week-review, close-review, closed-review vs spec 25–27 |
| 3.11 Plan / Re-plan | Built | plan.png vs spec 08, 09 |
| 3.12 Settings | Built | settings.png vs spec 06, 07 |
| 3.13 Notifications | Built as local notifications with the server's reminder rules and wording | testRemindersMatchTheServerRules |
| Tests | 12 XCTest cases pass on the simulator | scripts/test.sh → "12 passed, 0 failed" |

## Approaches tried and why they failed
- `git push` from the Claude shell: no GitHub credentials there ("could not read Username"). Commits are local until Eddie pushes.
- Mac Catalyst snapshot mode: dropped on Eddie's instruction; one iPhone 14 Pro simulator via simctl is allowed instead.

- XCTest failure output: a failed assertion hangs for 60 s instead of printing the values; print them in the test to see them.

## Decisions
- 2026-11-09: sample data mode (`-UITestSeed 1`, `-OpenScreen <name>`, `-MockNow`) never touches Firebase; `-OpenScreen` is ignored on a real account.
- 2026-11-09: transcribe and summarize follow the web app, not SPEC §2 where they differ (raw audio body with Content-Type and X-Duration; summarize takes {text, focus} and the client writes summary + summaryAt).
- 2026-11-09: reschedule UI not ported: under the grace rule (from 2026-11-08) the web app never offers it.

- 2026-11-09: reminders copy functions/reminders.js (15 min before start-by and before grace ends), not SPEC 3.13's "30 min left".
- 2026-11-09: not built: Control Center control (needs a widget extension target), synthesized sounds (the Sounds switch only saves
  the setting), caffeine wean schedule settings and dose log, review day/hour and home timer settings, life-prayer import link,
  reschedule (dead under the grace rule), light-theme polish pass.

## Open questions for Eddie
- If web push is still on for the PWA and local notifications are turned on in the native app, reminders arrive twice. Turn one off?
- Firebase iOS app is registered with bundle id `om.redeemedtools.WeeklyDirection` (missing "c"). Fix in the Firebase console and re-download the plist.

## Device checklist (only a real iPhone can prove these; use a throwaway week, not the real record)
1. Launch: sign in; fonts are Fraunces/Barlow; Reflect shows this week's entries (§1 bug 1: cause unconfirmed until seen).
2. Check a plain habit → appears in the web app within seconds; the day square fills; last habit keeps the day.
3. Timed habit: tap → timer runs, close and reopen, finishes and completes the habit; Stop timer clears it.
4. Mark failed → final, day marked not kept; shows the same in the web app.
5. Reflect: Write, Edit (stamp kept), Delete one, Select → delete several; compare liveRefl in the web app.
6. Record 10 s: mic and speech permissions, live words appear, "Added to this week"; then airplane mode → "1 waiting · Retry".
7. Shortcuts app → "Reflect" action; Back Tap; long-press the app icon → Reflect.
8. Prayer: new, edit, remove.
9. Settings: theme, Export (share sheet with a JSON file), notifications on → a start-by reminder arrives.
10. Re-plan the throwaway week (marks kept), Close it (percentage, reflection, summary arrives), plan the next one (new week doc).
