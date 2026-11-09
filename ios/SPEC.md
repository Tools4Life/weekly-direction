# Weekly Direction iOS — full build spec (long run)

Goal: a native SwiftUI app that does everything the web app does, looks like the screenshots in `spec/screens/`,
and reads/writes the same Firestore data so the web app and the iPhone app can be used side by side.

**The web app (`../index.html`) is the reference for every behavior.** When this spec and the web app disagree, the web
app wins. Before building a screen, read the matching function(s) named below. Screenshots are dark theme, 390×844 pt,
rendered from the web app with sample data (the sample week is Nov 7–14 2026, "today" is Wed Nov 11, 10:00 am).

Owner: personal use only, iPhone 14 Pro (iOS 18, no Action button). Dark theme first; light theme second.

---

## 0. Ground rules for the run
- Build with `xcodebuild` from Terminal for the device (`-destination 'generic/platform=iOS'`); do **not** boot a simulator
  and do not leave the debugger attached (the Mac has 16 GB; lldb alone took 6 GB). Re-run `xcodegen` after adding files.
- Work screen by screen in the order of section 3. After each screen: build clean, commit, push to `main`.
- Never write a field the web app doesn't write. Every write is field-level (see section 2). Test writes against a
  throwaway week first, never against the owner's real record.
- Past days lock at midnight, closed weeks are read-only, no undo for checks or failures. Don't "fix" past records.
- Keep `Rules.swift` identical to the web app's rules. If a rule needs changing, change the web app too.

## 1. Known bugs in the current native build (fix first)
1. **Reflect shows "Nothing yet this week" although the week has entries.** Entry parsing in `JournalView.swift`
   (`Entry.parse`) is broken; match the web's `rfBlocks`: split `liveRefl` on `/\n\s*\n/`, first line matching
   `^(Sunday|…|Saturday), (\d{1,2}:\d{2} [ap]m)$` is the stamp.
2. **Reflect tab content is pillarboxed** (narrow column with black bars). The ScrollView/VStack isn't taking full width;
   use `.frame(maxWidth: .infinity, alignment: .leading)` on the content and check nothing caps the width.
3. Fonts are system fallbacks; bundle **Fraunces** (serif: titles, focus word, entries) and **Barlow** + **Barlow
   Condensed** (UI and small-caps labels). All three are free (Google Fonts, OFL). Register them in Info.plist (`UIAppFonts`).

## 2. Data model (Firestore, project ops-hub-9bebc)
```
users/{uid}/weeklyDirection/settings            doc   closeDay(0-6, default 6=Sat), closeHour(default 17), theme, sounds, cafOn, timerMode…
users/{uid}/weeklyDirection/draft               doc   in-progress plan (see Plan)
users/{uid}/weeklyDirection/push                doc   web-push settings (ignore in native)
users/{uid}/weeklyDirection/data/weeks/{id}     week docs
users/{uid}/weeklyDirection/data/prayers/{id}   {text, icon, body, created, pinned?}
users/{uid}/weeklyDirection/data/library/{id}   habit library chips {name, icon, order}
users/{uid}/weeklyDirection/data/caffeine/{day} {items:[…]}  (optional feature, off for owner)
```
Week doc fields: `focus, verse?, verseRef?, status('active'|'closed'), sealedAt(ms), closedAt?, percentage?,
planThoughts (vision), commitments[{id,name,icon,by?,byWe?,days?('wd'|'we'),min?,about?}], qs (Saturday questions),
done{dayKey:{habitId:true, habitId@fail, habitId@grace, habitId@late, habitId@rs}}, marks{dayKey:'on'|'drift'},
runs{dayKey:{habitId:startMs}}, liveRefl (this week's journal), reflection (closing reflection), summary?, summaryAt?`.
`dayKey` = local `yyyy-MM-dd`.

Writes the web app makes (mirror exactly; all `setData(…, merge: true)` with nested maps):
| Web function | Native equivalent |
|---|---|
| `store.setDay(w,k,items,mark)` | `done.{k}` merged with `items`; `marks.{k}` = mark or deleted |
| `store.setRun(w,k,id,ts)` | `runs.{k}.{id}` = ts or deleted |
| `store.mark(w,k,v)` | `marks.{k}` |
| `store.patchWeek(w,fields)` | merge only those fields (liveRefl, reflection, focus…) |
| `store.putWeek(w)` | full write, **only for a brand-new week** (sealing) |
| `putPrayer / delPrayer`, `putChip / delChip`, `putDraft / delDraft`, `setSettings` | as named |
Checking a habit = `setItem` in the web app: sets `{id:true, id@late, id@grace}` per the grace rule and recomputes the day's mark.

Cloud Functions (already deployed; auth = `Authorization: Bearer <Firebase ID token>`):
- `POST https://us-central1-ops-hub-9bebc.cloudfunctions.net/transcribe` multipart `file` (m4a/mp4) → `{text}`
- `POST …/summarize` `{weekId}` → writes `summary` on the week
- `POST …/liveToken` → `{value}` ephemeral OpenAI key for realtime transcription (WebRTC, `https://api.openai.com/v1/realtime/calls`)

## 3. Screens (build in this order)

### 3.1 This Week — `renderWeek` · screens 01, 02, 25
- Header: focus word (Fraunces ~44pt), gear (→ Settings) top right. Line under it: **THIS WEEK · NOV 7 — 14** in accent
  (left) and **DAY 5 OF 8** (right, muted); on review day it shows **Review due** in accent italics instead.
- Day strip: one square per habit day (`habitDays`), letters S M T W T F S under them. Fill = share of the day's habits
  done (accent, partial fills), today outlined, selected day ringed. Tap a past day → list shows that day, header line
  reads "Monday · locked" with a "today" link back (02).
- **DAILY HABITS ›** label, then one row per habit for the selected day: icon, name, subtitle (start-by time, "15 min"
  for timed, "missed"/"failed" muted, grace countdown in accent), check circle on the right. Done rows have the accent
  fill (01). Tap the check → `setItem`. Timed habits: tap starts a timer (`runs`), shows a focus timer (`openFocus`),
  completes when time is up. Tap the row body → habit detail sheet.
- Streak card at the bottom: "0 days in a row", Best, milestone track 1·3·7·14·30·90.
- On review day/after close time: a **Close the week ›** card above the habits (25) → Close sheet.
- States and colors come from `Rules.state` (done/fail/run/fin/open/grace/miss/late). Locked days are read-only.

### 3.2 Habit detail sheet — `openHabit` · screen 03
Bottom sheet: icon + name, "every day · start by 6:00 pm", ABOUT text (always includes a Bible verse), today's status
("Not done today yet."), **Mark failed** (accent text, confirms; final). Done closes.

### 3.3 Timer focus — `openFocus`
Full-screen countdown for timed habits (e.g. Morning Devotion 15 min), close ✕, finishes the habit when time is up.
(Screenshot 04 missed this view; open it in the web app to see it: tap a timed habit that isn't done.)

### 3.4 Vision page — `openVision` · screen 05
Overlay: dates, focus word, verse + ref, the week's vision text (`planThoughts`), then the plan grouped
EVERY DAY / WEEKDAYS / WEEKENDS with each habit's start-by, weekend time and minutes. Swipe/‹ › between weeks. View-only.

### 3.5 Reflect → Journal — `rfRender`, `rfBody` · screens 10, 11, 12, 13, 14, 15, 16
- Header "Reflect" + **JOURNAL | PRAYER** segmented control on the same line.
- One card that never scrolls past the mic (10): **‹ THIS WEEK · NOV 7 — 14 ›** (accent), focus word, verse (2 lines max),
  divider, **TODAY · 6:52 AM** then the latest entry clamped to the space left, footer **All N entries ›** / **✎ Write**.
- ‹ or swipe right steps to earlier weeks (11): grey dates, focus word, AI SUMMARY text, **Read the week · N entries ›**,
  **This week**.
- Week page (12): ‹ Journal, dates, focus word, verse, entries grouped by day (newest first), Saturday review answers for
  closed weeks. This week only: **Select** (13) → circles, **Delete N entries** red button, confirm, permanent.
- Press and hold an entry (this week only) → action sheet with the entry preview, **Edit**, **Delete**, **Cancel** (14).
- Edit (15): full-screen editor, "EDIT ENTRY · WEDNESDAY, 6:52 AM", Save keeps the stamp. Write (16): "NEW ENTRY · …",
  keyboard up immediately, **Add** appends `"{Weekday}, {h:mm am}\n{text}"` to `liveRefl` separated by a blank line.
  Collapse blank lines inside an entry to single newlines (a blank line would split it).

### 3.6 Recording — `vcStart`, `vcStop`, `vcSend`, `liveStart`, `vcWave` · screen 17
- Mic button: 84pt accent circle centered above the tab bar on the Journal view only.
- Tap → recording screen (fade + the orb rises from the mic position): Cancel · timer, live words in large serif,
  scrolling bar waveform of the voice level (newest on the right, older bars fade), orb with a stop square; tap to finish.
- Record with `AVAudioRecorder` (AAC m4a, mono, 16 kHz is fine). On finish: POST to `transcribe`, append the text as a
  new stamped entry, show "Added to this week" briefly. Offline: queue the file on disk, retry on reconnect, show
  "N waiting · Retry". Under 1.5 s → "Too short", nothing saved.
- Live words: `liveToken` → WebRTC to OpenAI realtime (transcription session), show deltas as they arrive. Display only;
  the saved entry always comes from the full recording. (Native alternative if WebRTC is painful: `SFSpeechRecognizer`
  on-device for the live display only.)
- **App Intent "Reflect"** that opens straight into recording, so the owner can map it to Back Tap
  (Settings › Accessibility › Touch › Back Tap), Control Center (iOS 18 control), Siri and a Home Screen quick action.

### 3.7 Reflect → Prayer — `renderPrayer`, `openPrayer` · screens 18, 19
List "YOUR PRAYERS" with **+ New**; a pinned LIFE PRAYER card on top ("Add the prayer that covers your whole life");
rows with icon + title. Open (19): date, Edit / Done, title, body text. Edit sheet: title, icon picker, body. No mic here.

### 3.8 Progress — `renderHistory` · screens 20, 21
"Progress" title; hero card: THIS WEEK · {word} 14%, "1 of 7 days · 100% on time", mini day squares; right half
**WEEKLY TREND** avg + sparkline. Tap the card → Stats. **WEEKS | HABITS** segmented list: each closed week with name,
dates, 6 dot squares, percentage (tap → that week's stats). Habits view: one row per habit with last-6-weeks squares.

### 3.9 Stats — `openStats`, `openAllStats`, `stChart`, `cellOf` · screens 22, 23, 24
Overlay with **ALL TIME | WEEK** switch and ✕.
- Week (22, 23): ‹ dates › + Vision pill, focus word + big % + delta vs last week, DAILY TREND line chart, stat grid
  (days kept, habits done, on time, in grace, missed, failed; numbers centered), DAY BY DAY grid (habit × day cells:
  on time, grace, late, missed, failed), BY HABIT rows with % bars. Swipe changes week.
- All time (24): "Since Oct 17, 2026 · 4 weeks", big %, WEEKLY TREND chart with avg and best, stat grid, BY HABIT.
Use Swift Charts.

### 3.10 Close the week — `openClose`, `renderClose`, `clGo`, `closeMoment` · screens 25, 26, 27
Sheet: dates, word, % "1 of 7 days kept", day squares, note about unrecorded days, the Saturday questions with answer
boxes, REFLECTION (prefilled with this week's journal), **Close the week**. On close: status closed, closedAt,
percentage, reflection; then the closing moment screen and a button to plan next week (never auto-open the plan).
Then call `summarize` for that week.

### 3.11 Plan / Re-plan — `openPlan`, `renderChips`, `renderPlanQs` · screens 08, 09
Focus word, focus verse (ref + text, optional), week started date, DAILY HABITS (chips from the library; each with
start-by, weekend time, minutes, days, about), Saturday questions (anchor + two picked), vision text, **Seal the week**
(`putWeek` for a new week; re-plan patches the active week). Draft autosaves to `draft`. Re-plan is reachable only from
Settings (editing habits mid-week is intentionally hard).

### 3.12 Settings — `renderSettings` · screens 06, 07
Account (email, sign out), THIS WEEK (Re-plan this week), APPEARANCE Dark/Light/Auto, Sounds toggle, NOTIFICATIONS,
YOUR DATA (Export my data → JSON share sheet), Caffeine wean toggle, Saturday question library editor (07).

### 3.13 Native notifications (replaces web push)
Local notifications scheduled from the active week: before each start-by, when grace is about to end ("30 min left"),
an evening reminder for unfinished habits (skip missed ones), and the Saturday close reminder. Reschedule on every
data change. Ask permission the first time from Settings.

## 4. Visual system
Colors (dark): bg `#0B0B0C`, card `#151517`, card2 `#1C1C1F`, text `#F7F4EF`, muted `#ABA69F`, muted2 `#8A857F`,
rule `#222225`, accent `#E8743B`, onAccent `#0B0B0C`. Light theme: see `html[data-theme=light]` in index.html.
Type: Fraunces for titles/focus word/entries; Barlow Condensed 12pt, letter-spaced, uppercase for labels and dates;
Barlow for UI text. Cards: 18–22pt corner radius. Tab bar: three square icons (calendar-check, pen-in-square, chart in
square), 32pt, accent when selected, small bounce on select. Icons: map the web's `ICON_CHOICES` names to SF Symbols.
Motion: screens rise in (spring), sheets slide up, haptic tick on checks.

## 5. Done means
Every screenshot has a matching native screen; every write shows up in the web app within seconds and vice versa;
the owner can go a full week (check habits, record, pray, close, plan) without opening the web app.
