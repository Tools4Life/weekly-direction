import SwiftUI

/// Habit detail (web: openHabit): what it is, its About note, the day's status, and Mark failed (final).
struct HabitSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let weekId: String
    let habitId: String
    /// the day the list was showing, or nil when no habit day is selected
    let day: String?
    @State private var about = ""
    @State private var loaded = false
    @State private var confirmFail = false

    private var week: Week? { store.week(weekId) }
    private var habit: Commitment? { week?.commitments.first { $0.id == habitId } }

    var body: some View {
        ScrollView {
            if let w = week, let c = habit {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 10) {
                        Ico(name: c.icon, size: 22).foregroundStyle(Theme.ac).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(c.name).font(Theme.serif(26)).foregroundStyle(Theme.tx)
                            Text(metaLine(c)).font(Theme.label(15)).tracking(1.4).foregroundStyle(Theme.mu2)
                        }
                        Spacer()
                        Button("Done") { router.sheet = nil }.font(Theme.ui(18, .semibold)).foregroundStyle(Theme.ac)
                    }
                    Eyebrow(text: "About", color: Theme.mu, size: 14).padding(.top, 22)
                    TextEditor(text: $about)
                        .font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                        .padding(.horizontal, -4).padding(.top, 6)
                        .overlay(alignment: .topLeading) {
                            if about.isEmpty {
                                Text("Why this habit matters, and the verse behind it.")
                                    .font(Theme.serifItalic(18)).foregroundStyle(Theme.mu2).padding(.top, 14).allowsHitTesting(false)
                            }
                        }
                    if let k = day {
                        Text(stateLine(w, c, k)).font(Theme.ui(16)).foregroundStyle(Theme.mu).padding(.top, 18)
                        actions(w, c, k).padding(.top, 26)
                    }
                }
                .fullWidth()
                .padding(.horizontal, 20).padding(.top, 34).padding(.bottom, 30)
                .onAppear { if !loaded { about = c.about ?? ""; loaded = true } }
            }
        }
        .background(Theme.bg)
        .onDisappear { if let w = week, let c = habit, loaded { store.saveAbout(w, c, about) } }
    }

    private func metaLine(_ c: Commitment) -> String {
        [c.days == "wd" ? "weekdays" : c.days == "we" ? "weekends" : "every day", c.planMeta].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// the status sentence, word for word from the web app
    private func stateLine(_ w: Week, _ c: Commitment, _ k: String) -> String {
        let today = Rules.ymd(Now.date), st = Rules.state(w, k, c), late = w.flag(k, c.id + "@late")
        let dayName = k == today ? "today" : Fmt.dowl[Rules.weekday(Logic.noon(k))]
        let by = Rules.byOf(w, k, c).map(Fmt.clock) ?? ""
        let graceEnd = Rules.deadline(k, c, w).map { Fmt.clock($0.addingTimeInterval(Rules.graceSeconds)) } ?? ""
        var s: String
        if k < today {
            s = st == .done ? (late ? "Done \(dayName), late. Locked." : "Done \(dayName). Locked.")
                : st == .fail ? "Failed \(dayName). Locked." : "Missed \(dayName). Locked."
        } else {
            switch st {
            case .done: s = late ? "Done \(dayName), late." : "Done \(dayName)."
            case .late: s = "Not started by \(by). You can still do it; it’ll be logged as late."
            case .grace: s = "Past \(by). Start by \(graceEnd) and it still counts on time. After that it’s missed."
            case .miss: s = "Missed today. The grace window closed at \(graceEnd). This is final."
            case .fail: s = "Failed \(dayName). This is final."
            case .run: s = "Timer running."
            default: s = "Not done \(dayName) yet."
            }
        }
        if c.by != nil, w.flag(k, c.id + "@rs"), let base = Rules.baseBy(k, c) {
            s += " Rescheduled today from \(Fmt.clock(base)) to \(by)."
        }
        return s
    }

    @ViewBuilder private func actions(_ w: Week, _ c: Commitment, _ k: String) -> some View {
        let st = Rules.state(w, k, c)
        if k >= Rules.ymd(Now.date), st != .miss, st != .fail {
            VStack(spacing: 18) {
                if st == .run {
                    Button {
                        router.sheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.cover = .focus(week: w.id, habit: c.id, day: k) }
                    } label: {
                        Text("Open timer").font(Theme.ui(17, .medium)).foregroundStyle(Theme.tx)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Button("Mark failed") { confirmFail = true }
                    .font(Theme.ui(17)).foregroundStyle(Theme.ac).frame(maxWidth: .infinity)
                    .accessibilityIdentifier("markFailed")
            }
            .confirmationDialog("Mark \(c.name) failed for \(k == Rules.ymd(Now.date) ? "today" : "this day")? The day won’t be kept, and this can’t be undone.",
                                isPresented: $confirmFail, titleVisibility: .visible) {
                Button("Mark failed", role: .destructive) {
                    // re-read: the day may have rolled over or the habit changed while the dialog was open
                    guard let cur = store.week(weekId), k >= Rules.ymd(Now.date) else { router.sheet = nil; return }
                    let now = Rules.state(cur, k, c)
                    if now != .miss && now != .fail { store.fail(cur, k, c); Haptic.tick() }
                    router.sheet = nil
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
