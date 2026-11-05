# Weekly Direction — working rules

Single-file web app (`index.html`) + service worker (`sw.js`), published by GitHub Pages from `main`. Data lives in
Firebase (Firestore) per user; the code never has direct access to it.

## Before every push
- Install the hook once per clone: `git config core.hooksPath .githooks`. It runs the smoke test and refuses the push
  if the app errors or `sw.js` is broken. Run it by hand with `node .github/scripts/smoke.cjs` (needs Playwright + Chromium).
- Bump the service-worker cache on every change by editing `const CACHE='wd-vN'` **in place** (e.g. `sed -i`).
  Never write `sw.js` with a pattern that opens it for writing before reading it — that has emptied it twice.

## Data rules (the owner keeps a strict record)
- Week updates must be field-level: use `store.patchWeek(w,{field:…})`. `store.putWeek` only for a brand-new week.
- Past days are locked at midnight; no undo for checks or failures; closed weeks are read-only.
- Don't change past records on request unless the app itself got it wrong (a bug), not because something was late or missed.

## Local preview without Firebase
Set `window.__WD_MOCK={settings:{…},weeks:[…],prayers:[…]}` before load (see `.github/scripts/smoke.cjs`).
