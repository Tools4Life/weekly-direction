# Weekly Direction

Plan on Saturday evening, live the week, review the next Saturday.

Live at https://tools4life.github.io/weekly-direction/

- `index.html`: the whole app (markup, styles, script).
- `sw.js`: offline cache so the home-screen app opens with no signal. Bump `CACHE` on every release.
- Data: Firestore in the shared Tools4Life Firebase project, under `users/{uid}/weeklyDirection/…`
  (`settings`, `draft`, and `data/library/*`, `data/weeks/*`). The Firebase web config in `index.html` identifies the project; it is not a secret.

Icons: [Phosphor Icons](https://phosphoricons.com) (regular weight), MIT licence.
