# Weekly Direction iOS — progress log

**Current: a past day of the open week can be changed to failed from the habit sheet (Nov 10) BUILT, not on the phone yet; next TestFlight upload is 0.2 (1).** Open: prayer icon pick, device check of dictation. Nothing pushed (no git credentials in the Claude shell).

## Prayers without a full page (Nov 10)
- A prayer that is only its name opens as a half sheet with "Add to this prayer"; Edit or that line lifts it to the full page. A prayer with text, the life prayer and New still open full height. The list shows one muted line of a prayer's text under its name.
- Layout only: no change to what is saved. Verified: simulator shots `prayer`, `prayer-short`. Not verified: on the phone; the lift to full height when Edit is tapped.

## Past-day correction (Nov 10)
- Habit sheet on a past day of the open week: "Change <day> to failed" plus a confirm that names the day and what is recorded. Works for a done or a missed habit; a failure stays final; a past day still cannot be checked off. Writes what a same-day failure writes (`id: false`, `id@fail: true`, mark `drift`). Closed weeks stay read-only.
- iOS only: the web app still closes the sheet on past days, but shows the failure.
- Verified: unit test (13 pass), simulator shot `habit-past`. Not verified: on the phone, on real data.

## Polish pass (Nov 9, evening)
- Habit names now match the web: Barlow Regular 16.5, no extra tracking (was Medium 18 + tracking); meta Barlow Condensed 13.
- Type scale down everywhere: screen titles 34 (focus word on This Week 40), rows 16, descriptions 14, labels 12, stats numbers a step smaller. Journal entry text stays 18.
- Journal: card shows the latest three entries (latest in full, older shortened); week page has quiet italic times and roomier lines; new-entry screen has a placeholder, this week's questions as read-only prompts, and keeps an unfinished entry on the phone (UserDefaults `entryDraft.<weekId>`, never Firestore).
- Not verified: anything on the phone; the kept-draft path (sample-data mode skips it); older entries on the card clamp to one line in the simulator although two are allowed.
- Flat style: Eddie tried the idea and said "keep original" (Nov 9). The Settings switch is removed; the preview stays behind `-MockStyle 1/2` in sample-data mode only.
- Caps font (Eddie, Nov 9): habit names, row titles, buttons and controls use Barlow Condensed SemiBold caps (`.caps()` in Theme.swift). Page titles and journal text keep the serif; sentences, descriptions, typed text and the account email keep Barlow.
- Mic-first layout (Eddie, Nov 9): tab bar is This Week, Journal, mic (raised, records from any screen), Prayer, Progress. This Week shows the latest thought under the habits. Reflect is `JournalList.swift`: this week's entries newest first, then earlier weeks, Write at the top. The old journal card, the Journal | Prayer switch and the mic dock are removed; `-OpenScreen reflect-past` is gone. Layout only: entries are read and written as before. Starting a recording no longer switches tabs.
- Not verified: recording from the centre mic on a device; the "Transcribing… / N waiting · Retry" line in its new places (This Week above the latest thought, top of Journal).
- Dictation (Nov 9, late): the recording space is an overlay (0.16 s fade, orb grows from the tab mic), not a full-screen cover. Finishing closes it at once; transcription runs behind (`Recorder.sending`), the latest-thought strip shows the on-device words as "Just now · transcribing" until the real text lands, and a new recording can start meanwhile. Audio session and recorder set-up run off the main thread; live words start 0.35 s after the screen opens. Not verified on a device: any of it (sample data records nothing).
- Journal page (Eddie, Nov 9: "paper for light mode, not dark"): the journal list, week page and editor use their own page: warm brown-black in dark mode, the web's cream paper in light mode, Georgia throughout, plain-word buttons, italic stamps (`Theme.j*`). Georgia in light mode too is Claude's call (the paper mockup he saw was Fraunces); one line to switch back.
- Stats (Eddie approved the mockup, Nov 9): one headline, week grid, one quiet line for what slipped, habits as bars. A week in progress is never compared with a finished one; the all-time trend shows finished weeks only. Old six-box grid, daily trend and habit cards removed.
- Journal colours (Eddie, Nov 9): warm / paper tones on the write and edit screen ONLY. The Journal list and week page use the app's default colours (they keep Georgia and plain-word buttons). A ruled "Earlier weeks" divider separates this week from prior weeks.
- Habit tap opens a half sheet (medium detent, pull up for full).
- TestFlight: `scripts/testflight.sh` (archive + local .ipa) and `scripts/testflight.sh upload`. Build number = build time. `ITSAppUsesNonExemptEncryption` = false. Upload needs an App Store Connect app record for com.redeemedtools.WeeklyDirection and is Eddie's call each time.
- Previous state: run DAY-2026-11-09 DONE.

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
| 3.5 Journal | Built | reflect, week-page, week-page-select, entry-menu, edit, write vs spec 10–16 |
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
