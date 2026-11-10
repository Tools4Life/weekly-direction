import SwiftUI
import Combine

/// This Week (web: renderWeek): focus word, day strip, the selected day's habits with their live states, streak.
struct ThisWeekView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var now = Now.date
    @State private var nudge: String?
    @State private var finished = Set<String>()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let w = store.activeWeek { week(w) } else { noWeek }
            }
            .fullWidth()
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
        .onReceive(tick) { _ in now = Now.date; finishDue() }
    }

    // MARK: no week in progress

    private var noWeek: some View {
        let resume = (store.draft?["step"] as? String) == "plan" && store.draft?["replan"] as? String == nil
        let first = store.weeks.isEmpty
        return VStack(alignment: .leading, spacing: 14) {
            HStack { Text("This week").title(34).foregroundStyle(Theme.tx); Spacer(); gear }
            Eyebrow(text: first ? "Weekly Direction" : "No week in progress").padding(.top, 40)
            Text(resume ? "Your plan is waiting." : first ? "Plan your first week." : "Plan the next week.")
                .font(Theme.serif(26)).foregroundStyle(Theme.tx)
            Text(resume ? "Pick up where you left off." : "One word and a few daily habits. Seal it, then just live it.")
                .font(Theme.ui(15)).foregroundStyle(Theme.mu)
            Button { router.cover = .plan(replan: nil) } label: {
                Text(resume ? "Resume planning" : first ? "Plan your first week" : "Plan the week")
                    .caps(16).foregroundStyle(Theme.onAc)
                    .padding(.horizontal, 22).frame(height: 50)
                    .background(Theme.ac, in: RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous))
            }
            .buttonStyle(.plain).padding(.top, 8)
        }
    }

    private var gear: some View {
        Button { router.cover = .settings } label: {
            Image(systemName: "gearshape").font(.system(size: 22, weight: .light)).foregroundStyle(Theme.mu)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel("Settings")
    }

    // MARK: the active week

    private struct Ctx {
        let w: Week, days: [Date], todayK: String, selKey: String?, selDay: Date?, due: Bool, end: Date, habitToday: Bool
    }
    private func ctx(_ w: Week) -> Ctx {
        let end = Rules.weekEnd(w.sealedAt, store.settings), todayK = Rules.ymd(now)
        let days = Rules.habitDays(w, store.settings), keys = days.map(Rules.ymd)
        let habitToday = keys.contains(todayK)
        let sel = router.selK.flatMap { $0 <= todayK && keys.contains($0) ? $0 : nil } ?? (habitToday ? todayK : nil)
        return Ctx(w: w, days: days, todayK: todayK, selKey: sel, selDay: sel.flatMap { k in days.first { Rules.ymd($0) == k } },
                   due: now >= end, end: end, habitToday: habitToday)
    }

    @ViewBuilder private func week(_ w: Week) -> some View {
        let x = ctx(w)
        HStack(alignment: .center) {
            Text(w.focus).title(40).foregroundStyle(Theme.tx).lineLimit(1).minimumScaleFactor(0.5)
                .onTapGesture { router.cover = .vision(w.id) }
            Spacer()
            gear
        }
        HStack(alignment: .firstTextBaseline) {
            Eyebrow(text: "This week · " + Fmt.range(w.sealedAt, x.end), color: Theme.ac)
            Spacer()
            if x.due { Text("Review due").font(Theme.serifItalic(17)).foregroundStyle(Theme.ac) } else { Eyebrow(text: dayCount(w, x.end)) }
        }
        .padding(.top, 6)
        strip(x).padding(.top, 16)
        if x.due || reviewDay(w, x) { closeCard(w, due: x.due).padding(.top, 18) }
        if x.selKey == nil, !x.due, reviewDay(w, x) {
            Text("\(Fmt.dowl[store.settings.closeDay]) · review and plan from \(Fmt.hourLabel(store.settings.closeHour))")
                .font(Theme.ui(14)).foregroundStyle(Theme.mu).padding(.top, 16)
        }
        habitsHeader(x).padding(.top, 24)
        VStack(spacing: 6) {
            ForEach(w.commitments.filter { c in x.selDay.map { Rules.onDay(c, $0) } ?? true }) { c in
                HabitCard(week: w, day: x.selKey, todayK: x.todayK, c: c, now: now,
                          onBody: { router.sheet = .habit(week: w.id, habit: c.id, day: x.selKey) },
                          onCheck: { tapCheck(w, x, c) })
                    .modifier(Nudge(on: nudge == c.id))
            }
            if let k = x.selKey, let d = x.selDay { doses(w, k, d, locked: k != x.todayK) }
        }
        .padding(.top, 12)
        if Theme.micFirst { LatestThought(week: w).padding(.top, 14) }
        StreakCard(info: Logic.streak(store.weeks, store.settings)).padding(.top, Theme.micFirst ? 14 : 34)
    }

    private func reviewDay(_ w: Week, _ x: Ctx) -> Bool {
        Rules.weekday(now) == store.settings.closeDay && Rules.ymd(w.sealedAt) != x.todayK
    }

    private func dayCount(_ w: Week, _ end: Date) -> String {
        let d0 = Logic.midnight(w.sealedAt), d1 = Logic.midnight(end)
        let total = Logic.dayDiff(d0, d1) + 1
        let n = min(total, Int(floor(Logic.midnight(now).timeIntervalSince(d0) / 86400)) + 1)
        return "Day \(n) of \(total)"
    }

    // MARK: day strip

    private func strip(_ x: Ctx) -> some View {
        HStack(spacing: 8) {
            ForEach(x.days, id: \.self) { d in
                let k = Rules.ymd(d), fut = k > x.todayK, m = x.w.marks[k]
                Button {
                    router.selK = k == x.todayK ? nil : k
                } label: {
                    VStack(spacing: 5) {
                        DaySquare(mark: m, fraction: m == nil && !fut ? fraction(x.w, d) : 0, future: fut, selected: k == x.selKey)
                            .frame(height: 30)
                        Text(Fmt.dow[Rules.weekday(d)]).font(Theme.label(12)).tracking(1.2)
                            .foregroundStyle(k == x.selKey ? Theme.tx : k == x.todayK ? Theme.mu : Theme.mu2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(fut)
                .accessibilityLabel("\(Fmt.dowl[Rules.weekday(d)]): \(m == "on" ? "kept" : m == "drift" ? "missed" : "not marked")")
            }
        }
    }
    private func fraction(_ w: Week, _ d: Date) -> Double {
        let it = Logic.dayItems(w, d, store.settings), k = Rules.ymd(d)
        return it.isEmpty ? 0 : Double(it.filter { w.flag(k, $0) }.count) / Double(it.count)
    }

    // MARK: close card, habits header, doses

    private func closeCard(_ w: Week, due: Bool) -> some View {
        Button { router.sheet = .close(w.id) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(due ? "Close the week" : "Weekly review").caps(16).foregroundStyle(Theme.tx)
                    Eyebrow(text: "\(Logic.weekStats(w, store.settings).pct)% \(due ? "" : "so far ")· close & plan", color: Theme.mu)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.mu)
            }
            .padding(.horizontal, 17).padding(.vertical, 16)
            .background(Theme.card2, in: RoundedRectangle(cornerRadius: Theme.r(16), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.r(16), style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func habitsHeader(_ x: Ctx) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Button { router.cover = .vision(x.w.id) } label: {
                HStack(spacing: 8) {
                    Eyebrow(text: "Daily habits", color: Theme.mu, size: 12)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.mu)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if let k = x.selKey, k != x.todayK, let d = x.selDay {
                HStack(spacing: 0) {
                    Text("\(Fmt.dowl[Rules.weekday(d)]) · locked · ").foregroundStyle(Theme.mu)
                    Button(x.habitToday ? "today" : "done") { router.selK = nil }.foregroundStyle(Theme.ac)
                }
                .font(Theme.ui(14))
            }
        }
    }

    /// AM / PM caffeine doses: part of the day's items while the wean is on
    @ViewBuilder private func doses(_ w: Week, _ k: String, _ d: Date, locked: Bool) -> some View {
        if store.settings.cafOn {
            let split = Logic.cafSplit(store.settings, Logic.cafLimit(store.settings, d))
            ForEach([("am", "Caffeine · AM", split.am), ("pm", "Caffeine · PM", split.pm)].filter { $0.2 > 0 }, id: \.0) { dose in
                let on = w.flag(k, dose.0)
                HabitCardShell(done: on, dim: false, running: 0, icon: "cup", name: dose.1, meta: "\(dose.2) mg", metaAccent: false,
                               strike: false, check: on ? .done : .open, onBody: {}, onCheck: {
                    if locked { bump(dose.0); return }
                    Haptic.tick()
                    store.setItem(w, k, dose.0, !on)
                })
                .modifier(Nudge(on: nudge == dose.0))
            }
        }
    }

    // MARK: taps

    private func bump(_ id: String) {
        nudge = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if nudge == id { nudge = nil } }
    }

    /// the check tap (web: toggleItem). Past days are locked; done, failed and missed are final.
    private func tapCheck(_ w: Week, _ x: Ctx, _ c: Commitment) {
        guard let k = x.selKey, k == Rules.ymd(Now.date) else { bump(c.id); return }
        let st = Rules.state(w, k, c)
        if st == .done || st == .fail || st == .miss { bump(c.id); return }
        if c.min != nil {
            Haptic.tick()
            if st == .open || st == .late || st == .grace { store.setRun(w, k, c.id, Now.ms) }
            router.cover = .focus(week: w.id, habit: c.id, day: k)
            return
        }
        Haptic.tick()
        store.setItem(w, k, c.id, true)
        if Logic.dayItems(w, x.selDay ?? Now.date, store.settings).allSatisfy({ $0 == c.id || w.flag(k, $0) }) { Haptic.success() }
    }

    /// a timer that ran out while its screen was closed completes the habit (web: the 'fin' pass in renderWeek)
    private func finishDue() {
        guard router.cover == nil, let w = store.activeWeek else { return }
        let x = ctx(w)
        guard let k = x.selKey, let d = x.selDay else { return }
        for c in w.commitments where Rules.onDay(c, d) && Rules.state(w, k, c) == .fin && !finished.contains(k + c.id) {
            finished.insert(k + c.id)
            store.setItem(w, k, c.id, true)
        }
    }
}

private struct Nudge: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        content.offset(x: on ? 5 : 0).animation(on ? .spring(response: 0.12, dampingFraction: 0.2) : .default, value: on)
    }
}

struct DaySquare: View {
    let mark: String?
    var fraction: Double = 0
    var future = false
    var selected = false
    var radius: CGFloat = 8

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.r(radius), style: .continuous)
        ZStack {
            if mark == "on" { shape.fill(Theme.ac) }
            else if mark == "drift" { shape.fill(Color(hex: 0xF2EFEA)) }
            else if fraction > 0 && fraction < 1 {
                GeometryReader { g in
                    VStack(spacing: 0) { Spacer(minLength: 0); Theme.ac.opacity(0.55).frame(height: g.size.height * fraction) }
                }
                .clipShape(shape)
                shape.stroke(Theme.ac.opacity(0.45), lineWidth: 1.5)
            }
            else if future { shape.stroke(Theme.rule, lineWidth: 1.5) }
            else { shape.stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
        }
        .padding(selected ? 0 : 0)
        .overlay {
            if selected { RoundedRectangle(cornerRadius: radius + 3.5, style: .continuous).stroke(Theme.tx, lineWidth: 1.5).padding(-3.5) }
        }
    }
}

/// one habit for one day: icon, name, subtitle, check
struct HabitCard: View {
    let week: Week
    /// nil when the week has no habit day selected (plain list, no checks)
    let day: String?
    let todayK: String
    let c: Commitment
    let now: Date
    let onBody: () -> Void
    let onCheck: () -> Void

    var body: some View {
        if let k = day {
            let st0 = Rules.state(week, k, c, now: now)
            let st: HabitState = k < todayK && st0 != .done && st0 != .fail ? .miss : st0
            let r = week.run(k, c.id)
            let rp: Double = st == .run && r != nil ? min(1, (now.timeIntervalSince1970 * 1000 - r!) / Double((c.min ?? 1) * 60000)) : 0
            let timerIcon = st == .run || (c.min != nil && (st == .open || st == .late || st == .grace) && k == todayK)
            HabitCardShell(done: st == .done, dim: st == .miss || st == .fail, running: st == .run ? max(rp, 0.001) : 0,
                           icon: c.icon, name: c.name, meta: meta(st, k, r), metaAccent: st == .miss || st == .fail || st == .run || st == .grace,
                           strike: st == .miss || st == .fail,
                           check: st == .done ? .done : st == .miss || st == .fail ? .x : timerIcon ? .timer : .open,
                           onBody: onBody, onCheck: onCheck)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(c.name): \(st.rawValue)")
        } else {
            HabitCardShell(done: false, dim: false, running: 0, icon: c.icon, name: c.name, meta: c.timeLabel(), metaAccent: false,
                           strike: false, check: nil, onBody: onBody, onCheck: {})
        }
    }

    /// the subtitle, word for word from the web app
    private func meta(_ st: HabitState, _ k: String, _ r: Double?) -> String {
        let rs = week.flag(k, c.id + "@rs"), late = week.flag(k, c.id + "@late")
        let by = Rules.byOf(week, k, c).map(Fmt.clock) ?? ""
        let minutes = c.min.map { "\($0) min" } ?? ""
        switch st {
        case .miss: return "missed"
        case .fail: return "failed"
        case .late: return "late · \(by)"
        case .grace:
            return Rules.deadline(k, c, week).map { "grace · until \(Fmt.clock($0.addingTimeInterval(Rules.graceSeconds)))" } ?? "grace"
        case .run:
            guard let r, let m = c.min else { return "" }
            return Fmt.mmss((r + Double(m) * 60000 - now.timeIntervalSince1970 * 1000) / 1000)
        case .done:
            if rs && !late { return c.min != nil ? "done · rescheduled · \(minutes)" : "done · rescheduled" }
            if late { return c.min != nil ? "done late · \(minutes)" : "done late" }
            return minutes
        case .open where rs: return "\(by) · rescheduled"
        default: return [by, minutes].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }
}

struct HabitCardShell: View {
    enum Check { case done, x, timer, open }
    let done: Bool, dim: Bool
    /// 0 = not running, else the share of the timer that has run
    let running: Double
    let icon: String?, name: String, meta: String, metaAccent: Bool, strike: Bool
    let check: Check?
    let onBody: () -> Void, onCheck: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.r(13), style: .continuous)
        HStack(spacing: 0) {
            Button(action: onBody) {
                HStack(spacing: 13) {
                    Ico(name: icon, size: 19).foregroundStyle(done || running > 0 ? Theme.ac : Theme.mu)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name).rowTitle().foregroundStyle(Theme.tx).lineLimit(1)
                            .strikethrough(strike, color: Theme.tx.opacity(0.35))
                        if !meta.isEmpty {
                            Text(meta).font(Theme.label(12)).tracking(0.8).monospacedDigit()
                                .foregroundStyle(metaAccent ? Theme.ac : done ? Theme.tx.opacity(0.55) : Theme.mu2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 14).padding(.vertical, 9)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let check {
                Rectangle().fill(Theme.line.opacity(0.7)).frame(width: 1)
                Button(action: onCheck) { mark(check).frame(width: 54).frame(maxHeight: .infinity).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background {
            ZStack(alignment: .leading) {
                shape.fill(Theme.card2)
                if done { shape.fill(LinearGradient(colors: [Theme.ac.opacity(0.28), Theme.ac.opacity(0.12)], startPoint: .leading, endPoint: .trailing)) }
                if running > 0 { GeometryReader { g in Theme.ac.opacity(0.14).frame(width: g.size.width * running) }.clipShape(shape) }
            }
        }
        .overlay(shape.stroke(done ? Theme.ac.opacity(0.45) : running > 0 ? Theme.ac.opacity(0.55) : Theme.line, lineWidth: 1))
        .opacity(dim ? 0.5 : 1)
    }

    @ViewBuilder private func mark(_ c: Check) -> some View {
        switch c {
        case .done:
            ZStack {
                Theme.dot.fill(Color.white.opacity(0.14)).frame(width: 38, height: 38)
                Theme.dot.fill(Color(hex: 0xF2EFEA)).frame(width: 30, height: 30)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: 0x0B0B0C))
            }
        case .x:
            ZStack {
                Theme.dot.stroke(Theme.mu2, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: 28, height: 28)
                Image(systemName: "xmark").font(.system(size: 11, weight: .regular)).foregroundStyle(Theme.mu)
            }
        case .timer:
            ZStack {
                Theme.dot.stroke(Theme.mu, lineWidth: 1).frame(width: 28, height: 28)
                Image(systemName: "timer").font(.system(size: 13, weight: .regular)).foregroundStyle(Theme.mu)
            }
        case .open:
            Theme.dot.stroke(Theme.mu, lineWidth: 1).frame(width: 28, height: 28)
        }
    }
}

struct StreakCard: View {
    let info: (cur: Int, best: Int)

    var body: some View {
        let cur = info.cur, best = info.best, next = Logic.miles.first { $0 > cur }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Streak", color: Theme.mu, size: 12)
                Spacer()
                Text(best > cur ? "Best \(best)" : cur > 0 ? "Your best" : "").font(Theme.label(13)).tracking(1).foregroundStyle(Theme.mu2)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(cur)").font(Theme.num(24)).foregroundStyle(Theme.tx)
                Text("\(cur == 1 ? "day" : "days") in a row").font(Theme.ui(14)).foregroundStyle(Theme.mu)
                Spacer()
                Text(next.map { "\($0 - cur) to \($0)" } ?? "All milestones").font(Theme.label(14)).tracking(1).foregroundStyle(Theme.ac)
            }
            .padding(.top, 6)
            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(Logic.miles.enumerated()), id: \.offset) { i, m in
                    let prev = i == 0 ? 0 : Logic.miles[i - 1]
                    let f: Double = cur >= m ? 1 : cur <= prev ? 0 : Double(cur - prev) / Double(m - prev)
                    VStack(alignment: .trailing, spacing: 7) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Theme.pill.fill(Theme.line)
                                Theme.pill.fill(Theme.ac).frame(width: g.size.width * f)
                            }
                        }
                        .frame(height: 5)
                        .overlay { if m == next { Theme.pill.stroke(Theme.ac.opacity(0.45), lineWidth: 1).padding(-1) } }
                        Text("\(m)").font(Theme.label(13)).tracking(0.8).foregroundStyle(cur >= m ? Theme.ac : Theme.mu2)
                    }
                }
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 16)
        .card(18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak: \(cur)")
    }
}
