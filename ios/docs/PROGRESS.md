# Weekly Direction iOS — progress log

**Current: run DAY-2026-11-09, item 3.5 Reflect → Journal.** Previous: §1 bugs and 3.1–3.4 done (simulator-checked, not on device).

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

## Approaches tried and why they failed
- `git push` from the Claude shell: no GitHub credentials there ("could not read Username"). Commits are local until Eddie pushes.
- Mac Catalyst snapshot mode: dropped on Eddie's instruction; one iPhone 14 Pro simulator via simctl is allowed instead.

## Decisions
- 2026-11-09: sample data mode (`-UITestSeed 1`, `-OpenScreen <name>`, `-MockNow`) never touches Firebase; `-OpenScreen` is ignored on a real account.
- 2026-11-09: transcribe and summarize follow the web app, not SPEC §2 where they differ (raw audio body with Content-Type and X-Duration; summarize takes {text, focus} and the client writes summary + summaryAt).
- 2026-11-09: reschedule UI not ported: under the grace rule (from 2026-11-08) the web app never offers it.

## Open questions for Eddie
- Firebase iOS app is registered with bundle id `om.redeemedtools.WeeklyDirection` (missing "c"). Fix in the Firebase console and re-download the plist.

## Device checklist (only a real iPhone can prove these)
See the end report in the run file.
