# Weekly Direction iOS — progress log

**Current: 0.2 (10) uploaded to TestFlight Nov 11 (through commit 1f400b9: build 9 plus the Practice row removed from Settings). `tidy` function deployed Nov 10 with the edit-never-answer fix. The app is frozen after this build unless Eddie's phone test finds a bug.** Pushed to GitHub through f032c01; later commits are local (`git push` works from Eddie's terminal, token in the Keychain).

## Next update (backlog, not started)
- 2026-11-11, Prayer tab: a spoken prayer log. Eddie: "add a running log of prayers spoken out loud to the prayer tab, below
  the 'things to pray for'. It's just spoken prayer log below." Not designed or built yet.

## After 0.2 (10) (Nov 11, from Eddie's phone): NOT uploaded yet
- Edit / Plan the week: a long vision stays a box of at most 12 lines that scrolls inside itself; scrolling the page puts the keyboard away at once (Seal comes back). From his screen recording: a page-long vision buried the habits and Seal, and the keyboard stayed up over the whole page.
- Reading entries (journal week page, journal list, review, vision log): an empty line between an entry's paragraphs (`Journal.Block.read`). Display only; stored entries keep single line breaks.

## After 0.2 (9) (Nov 10): in 0.2 (10)
- Settings: the Practice mode row is removed (Eddie). The practice code stays in `Store`, unreachable (only `-MockPractice` in sample mode).
- `tidy` function: spoken text is edited, never answered (transcript tags + a guard that returns his own words); deployed Nov 10.

## After 0.2 (8), from Eddie's phone (Nov 10): in 0.2 (9)
- Progress card says "1 of 7 days kept" on one line; "% on time" removed there and from the Habits rows (always 100 since the Nov 8 rule: on time or missed). Still shown on the week's own stats pages.

## Label batch before the freeze (Nov 10, Eddie agreed to the list)
- This Week: "Day N of M" removed; "Review due" is the caps label; the streak card's "N to M" removed.
- Past week's journal page: "Open week" is now "Week summary". Vision page: "swipe for other weeks" removed.
- Settings: intro lines removed from Saturday questions and Caffeine wean; Reminders shows a line only when notifications are blocked.
- Prayer: "Remove from list" in caps. Widget habit names and the Progress habits detail line shrink instead of cutting off.
- Checked: the widget preview's ticked Work Review is the preview's own sample; `WidgetBridge` sends missed as missed.
- Left on purpose: two past-week pages, two pill styles, prayer column width, the "Reflect" naming, X versus chevron.

## The four picks before the freeze (Nov 10, after the debugging run)
- Review: Next / Close the week is a fixed footer; the week's journal is read-only there (edited in the journal); the line being typed stays above the keyboard; nothing scrolls under the grabber.
- Review reflection is kept on the phone (`ReviewDraft`, UserDefaults, never Firestore) until the week closes: survives swipe-down, a widget recording, leaving the app.
- Edit the week: back is Cancel, asks before discarding a change, never writes or resumes a draft (a resumed draft put back old day marks and habits). New-week planning still drafts ("Later").
- Journal week page and entry editor use the app's caps top bar.
- Checked on the simulator with sample data: all four. Not checked: the phone, the real account, the UserDefaults path of the review draft (sample mode keeps it in memory).

## Debugging run on iOS 27, iPhone 14 Pro simulator (Nov 10, after 0.2 (7))
- Every `-OpenScreen` screen shot in dark, eight in light; then by hand in sample data: check / uncheck / fail a habit, About note, day strip, vision, edit the week, habit editor, journal add / menu / delete, earlier weeks and swiping, recording screen (preview words only), prayer add / open / edit, the Saturday review, rating, closing, planning and sealing the next week. Plus a read-only code audit.
- Fixed: a recording whose week closed before it was sent is kept instead of deleted; Stop / Cancel while the mic is still opening no longer leaves a hidden recording or a stuck mic; the phone stays awake while recording; a thought that arrives after the review opens is included when the week closes; rating proposals are asked again if the first request failed; the habit editor only raises the keyboard for a new habit; text no longer runs under Edit / Close on the vision page; the entry menu no longer shows the mic through its gap; a not-kept day is dark in the light theme (was invisible); VoiceOver says "Journal" and plain habit states.
- Verified: 15 tests, device build, shots of the vision page, entry menu and the light week. Not verified: every recorder fix (the simulator's sample mode never opens the microphone), anything on the phone.

## Prayers without a full page (Nov 10)
- A prayer that is only its name opens as a half sheet with "Add to this prayer"; Edit or that line lifts it to the full page. A prayer with text, the life prayer and New still open full height. The list stays plain rows (a text preview line was tried and removed the same day: Eddie wants the list simple).
- Layout only: no change to what is saved. Verified: simulator shots `prayer`, `prayer-short`. Not verified: on the phone; the lift to full height when Edit is tapped.

## Sphere page (Nov 10, after 0.2 (3))
- Tap a row in Progress → Growth to open the sphere: "Better in N of the last M weeks", weeks without slipping, a running line (better steps up, worse steps down), and "In your words": the sentence each rating rested on, newest first.
- Each rating now also saves `t`, the sentence, but only when he kept the proposed rating (a rating he changed has no sentence that fits). Ratings made by hand, and every week closed before this, have none.
- Journal: "Write" is "+ NEW" on the section line, same as Prayer.
- Verified: 15 tests, shot `sphere`. Not verified: on the phone; real sentences (they need the undeployed `tidy` function).

## After 0.2 (2) (Nov 10)
- Sounds (`Sound.swift`, the web's tones as short sine notes): a rising note when a timer starts, a two-note chime when a habit is finished, four rising notes when the day is kept or a week is closed. Follows the Sounds setting and the silent switch; never plays while the mic is open.
- Practice mode (Settings → Practice mode): the app switches to the sample week on a Saturday evening so the review, rating, planning and sealing can be tried. The account's listeners are detached, every write stays in memory (`Store.isMock`), widgets and reminders are left alone, and leaving reloads the real data. Voice and AI functions still work in it. Recordings made in practice never reach the real journal, and real ones waiting on the phone are not sent during practice. His own settings (theme, questions) stay.
- Widgets: true black background. Habit sheet: icon, name and Done on one centre line.
- Verified: 15 tests, shots `week-practice` (banner via `-MockPractice 1`), `habit`. Not verified: the sounds (not heard), entering / leaving practice with a real account, on the phone.

## After 0.2 (1): Eddie's first device pass "looks good" (Nov 10)
- Small fixes: tab-bar mic 60 → 72; a finished habit's icon is white; habit sheet shows when / start-by / timer as one quiet line each; a plain habit (no start-by, no timer) can be unchecked the same day, timed ones stay final.
- Offline dictation: a recording made offline stays on the phone with the words the phone itself heard (sidecar `.txt`), shows in Journal and on This Week as a "waiting to send" placeholder, and becomes a normal entry when the server has it. On-device live words already work offline where the phone supports them.
- Widget extension `WeeklyDirectionWidgets` (new target, App Group `group.com.redeemedtools.WeeklyDirection`, URL scheme `weeklydirection://`):
  - Live Activity / Dynamic Island for the running habit timer (`TimerLiveActivity`), kept in step by `WidgetBridge.sync` whenever the weeks change or the app comes forward / goes back.
  - This Week widget in small, medium, large and Lock Screen rectangular; large shows range, focus word, verse, today's habits and a Dictate button. Read-only: habits cannot be checked from a widget.
  - Dictate: round Lock Screen widget, an iOS 18 control (Lock Screen buttons, Control Center, Action button), and a Shortcuts / Siri action (`DictateIntent`).
- Verified: 15 tests, the Home Screen widget layouts via `-OpenScreen widgets` (same views, drawn in the app), simulator build of both targets. **Not verified: anything in the extension running for real** (widgets on a Home Screen, the Dynamic Island, the control, the App Group hand-off), offline recording on a device.

## Dictation screen and growth by sphere (Nov 10, late)
- Recording screen: live words in Georgia 17 from the top of the page down (auto-scrolls once full), wave, elapsed time as the one number, smaller orb. "Tap to finish" and the header timer are gone. The dictation card in plan / review shows up to 10 lines.
- Growth is by sphere, not by exact question (questions change week to week): each rating is saved with `s`, the question's group in the library ("Anchor" for the anchor question, "Other" if it is in no group). A sphere's week is the balance of its questions. The rating step shows the sphere above each question.
- Verified: 14 tests, shots `recording`, `progress-growth`, `close-rate`. Not verified: live words scrolling on a real recording, on the phone.

## Growth from reflections (Nov 10)
- Eddie picked option A (one colour; green / red rejected because red and orange both read as alerts) and past weeks stay empty.
- Review is two steps: reflect, then "How did it go?" with Worse / Same / Better per question. The `tidy` function (mode `rate`) proposes each rating with the sentence it rests on; he confirms or changes it; tap again clears it. Without the function the buttons start empty and work by hand.
- Closing saves `growth: [{q, v}]` on the week (v 1 / 0 / -1, only rated questions). **A field the web app does not write or read**, approved by Eddie for this feature.
- Progress has a third view, Growth (`Growth.swift`): a row per question, a square per closed week (last 8, newest right), and improving / steady / slipping once a question has four rated weeks (last three against the three before).
- The mockup view is gone (`GrowthMock.swift` removed); its screenshots stay in docs/design/findings/2026-11-10-growth.
- Verified: 14 tests (rows, empty cell, trend), shots `progress-growth`, `close-rate`. Not verified: the AI's proposals, closing a rated week, on the phone. `tidy` still not deployed.

## Questions are prompts (Nov 10)
- Review page: the Saturday questions are shown as prompts only; there is one free reflection (spoken or typed) and this week's journal. Closing saves the journal plus the reflection as one more stamped entry ("Saturday, 5:32 pm" + text, no blank lines inside). iOS no longer writes "question + answer" blocks; weeks closed on the web still have them and still display.
- `tidy` is now `{mode: "vision" | "reflection", text}` → `{text}` only (the per-question split is gone). Still not deployed.
- Verified: shot `close`, 13 tests. Not verified: closing a week with a spoken reflection, on the phone.

## Review on the main page (Nov 10)
- This Week on review day / when due: a block under the day strip with "Reflect on this week" (the mic opens the review and starts listening; the row opens it to read or type) and "Plan next week" (muted until the week is closed; opens the review). Replaces the old "Weekly review" card.
- Timing (Eddie, later Nov 10): the block shows from the close hour on, or earlier on review day once every habit of the day is done, failed or missed; before that the page is just the week. Whenever the block shows, the habit list is tucked under one row ("Daily habits · done for today" or "· N still open", tap to open).
- Review page: no boxes, no standing subtext.
- Verified: shots `week-review`, `week-due` (habits still open, so not tucked), 13 tests. Not verified: the tucked state, the mic auto-start, on the phone.

## Talk first: review and plan by voice (Nov 10)
- `DictateCard` (Dictate.swift): "Reflect on this week" on the close sheet, "Plan next week" / "Talk through this week" above the Vision field. Records with the same recorder, transcribes with `transcribe`, hands the text to the screen; nothing joins the journal and nothing is saved until the screen's own Close / Seal.
- New Cloud Function `tidy` (`functions/tidy.js`, exported in `functions/index.js`): cleans spoken text (fillers, repeats, false starts) without summarizing; review mode places what was said under the Saturday questions (`answers`, `other`). **Not deployed**: Eddie runs `npx firebase-tools deploy --only functions:weekly-direction:tidy`. Until then the app falls back to the words as spoken and says so.
- Review: answers are added to what is already typed; `other` goes under Reflection. Plan: tidied text is appended to the vision and the draft saves as usual.
- Not built: AI suggesting habits or a focus word (Eddie was unsure he needs it).
- Verified: simulator shots `close`, `plan` (idle card only), 13 tests, `node --check` on the function. Not verified: recording, transcription, the tidy function's output, anything on the phone.

## Edit / plan the week restyle (Nov 10)
- Layout only; the draft, seal and field-level writes are untouched. Serif page title ("Edit the week" / "Plan the week") under an accent eyebrow. Order is now word, verse, vision, habits, Saturday questions, week started (vision used to be last).
- Verse is one card: the words in italic, the reference under them. Habit rows show the time under the name (it was cut off). Library chips use the caps font. Questions are one card. Week started is one row.
- Seal is an accent button in a fixed footer ("Seal the changes" when editing), with the missing-piece hint above it; the footer hides while the keyboard is up.
- Verified: simulator shot `plan` (top of the page only), 13 tests. Not verified: the lower half of the page, typing with the keyboard, sealing, on the phone.

## Timer restyle (Nov 10)
- The kitchen-timer face (own colours, overlapping numbers, plain-text Stop) is replaced: accent eyebrow "Timer · N min", the habit name as a serif page title, one accent ring that empties on a quiet track with the time and "ends h:mm" inside, and Stop timer as the app's outlined row. Uses the theme colours, so it follows light mode. The ring draws in on open. Timer rules and writes are unchanged.
- Verified: simulator shots `focus`, `focus-light`. Not verified: on the phone; the finish moment; habits longer than 60 min (the ring is now always the habit's own length, the old face was out of 60).

## Week swiping and motion (Nov 10)
- Week page (Journal → a week): swipe sideways for the week before / after, or tap the older / newer focus words at the bottom. Slides in from the side swiped. Off while selecting entries.
- Motion ported from the web (`rise`, `wordland`, `sqpop` / `ckpop`), in `Theme.swift`: This Week (focus word settles out of a blur; day strip, habits, latest thought, streak rise in a stagger; check and day square pop when they change), Journal entries, Prayer rows, Progress hero. Entrances and tap responses only, nothing loops; skipped with Reduce Motion.
- Not verified: how any of it feels (screenshots only show the settled pages); the swipe gesture next to vertical scrolling; on the phone.

## Settings rework (Nov 10)
- First page is short rows: Appearance, Sounds, Reminders, Saturday questions (count), Caffeine wean (state), Export, Sign out; the account is one quiet line at the bottom.
- Saturday questions has its own page: anchor, then each group as a list of editable questions with add / remove and New group. Still saved as the web's one text (`qLib`, `# Group` lines); nothing is written unless something was edited.
- Caffeine wean has its own page with what the web has and iOS lacked: starting limit, drop, days, start date (`cafStart`, `cafStep`, `cafDays`, `cafFrom`), today's dose and the steps. A finished plan says so and offers "Start a new wean today". Turning it on sets `cafFrom` when it was empty (the web does this at launch).
- Editing the open week moved from Settings to the page the focus word opens ("Edit this week", VisionView).
- Not verified: on the phone; editing questions and caffeine numbers with the keyboard (screenshots only); real data.

## Mic feedback (Nov 10)
- Starting a recording: heavy knock + system begin-record tone (1113) on the tap, before the microphone opens. Stopping: rigid knock + end-record tone (1114). Cancel keeps the light tick. Haptics are now allowed while the recording session is active (iOS mutes them by default, which is likely why it felt soft).
- Not verified: any of it. The simulator has no haptics and the tones were not heard; needs the phone.

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
