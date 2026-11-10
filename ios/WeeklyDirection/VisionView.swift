import SwiftUI

/// Read-only page for a week (web: openVision). From This Week: the word, verse, vision and the plan by day group.
/// From Stats (`log`): also the result, the reflection and each habit's tally, with ‹ › / swipe between weeks.
struct VisionView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var recorder: Recorder
    @Environment(\.dismiss) private var dismiss
    @State private var replan: SettingsView.PlanRef?
    @State var weekId: String
    let log: Bool

    private var ordered: [Week] { store.weeks.sorted { $0.sealedAtMs < $1.sealedAtMs } }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                if let w = store.week(weekId) {
                    VStack(alignment: .leading, spacing: 0) { page(w) }
                        .fullWidth()
                        .padding(.horizontal, 24).padding(.top, 78).padding(.bottom, 50)
                        .id(w.id)
                }
            }
            .scrollIndicators(.hidden)
            // the page scrolls under Edit and Close: a strip of the page colour keeps them readable
            LinearGradient(stops: [.init(color: Theme.bg, location: 0), .init(color: Theme.bg, location: 0.72), .init(color: Theme.bg.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 70).frame(maxWidth: .infinity).ignoresSafeArea(edges: .top).allowsHitTesting(false)
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 20, weight: .medium)).foregroundStyle(Theme.mu).frame(width: 44, height: 44)
            }
            .padding(.trailing, 12).padding(.top, 10)
            .accessibilityLabel("Close")
        }
        // the open week is edited from here (Eddie, Nov 10 2026): the word, verse, vision and habits, sealed again
        .overlay(alignment: .topLeading) {
            if !log, let w = store.week(weekId), w.isActive {
                Button { replan = SettingsView.PlanRef(id: w.id) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil").font(.system(size: 14))
                        Text(strOf(store.draft?["replan"]) == w.id ? "Resume editing" : "Edit this week")
                    }
                    .caps(15).foregroundStyle(Theme.mu).frame(height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.leading, 24).padding(.top, 10)
                .accessibilityIdentifier("editWeek")
            }
        }
        .fullScreenCover(item: $replan) { r in PlanView(replanId: r.id).environmentObject(store).environmentObject(router).environmentObject(recorder) }
        .background(Theme.bg.ignoresSafeArea())
        .gesture(DragGesture(minimumDistance: 40).onEnded { g in
            guard log, abs(g.translation.width) > 60, abs(g.translation.width) > abs(g.translation.height) * 1.6 else { return }
            step(g.translation.width < 0 ? 1 : -1)
        })
    }

    private func step(_ d: Int) {
        guard let i = ordered.firstIndex(where: { $0.id == weekId }), ordered.indices.contains(i + d) else { return }
        Haptic.tick()
        withAnimation(.easeOut(duration: 0.2)) { weekId = ordered[i + d].id }
    }

    @ViewBuilder private func page(_ w: Week) -> some View {
        let live = w.isActive
        Eyebrow(text: Fmt.weekRange(w, store.settings) + (log && live ? " · in progress" : ""), color: Theme.mu2, size: 12)
        Text(w.focus).font(Theme.serif(44)).foregroundStyle(Theme.tx).padding(.top, 10)
        if w.verse != nil || w.verseRef != nil {
            VStack(alignment: .leading, spacing: 10) {
                if let v = w.verse { Text(v).font(Theme.serifItalic(19)).lineSpacing(6).foregroundStyle(Theme.tx) }
                if let r = w.verseRef { Eyebrow(text: r, color: Theme.mu2, size: 12) }
            }
            .padding(.top, 12)
        }
        if log { strip(w).padding(.top, 22) }
        Rectangle().fill(Theme.line).frame(width: 44, height: 1).padding(.vertical, 30)
        if log { Eyebrow(text: "Vision", color: Theme.mu, size: 12).padding(.bottom, 12) }
        let paras = w.planThoughts.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if paras.isEmpty {
            Text(log ? "No vision written." : "No vision written for this week. Add one with Edit this week.")
                .font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(paras.enumerated()), id: \.offset) { _, p in
                    Text(p).font(Theme.serif(19)).lineSpacing(7).foregroundStyle(Theme.tx)
                }
            }
        }
        if log {
            reflection(w)
            Eyebrow(text: "Habits", color: Theme.mu, size: 12).padding(.top, 34).padding(.bottom, 6)
            ForEach(w.commitments) { c in
                item(c, [c.days == "wd" ? "weekdays" : c.days == "we" ? "weekends" : "", tally(w, c)].filter { !$0.isEmpty }.joined(separator: " · "))
            }
            nav(w)
        } else {
            Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 44)
            let groups = [("Every day", w.commitments.filter { $0.days == nil }), ("Weekdays", w.commitments.filter { $0.days == "wd" }),
                          ("Weekends", w.commitments.filter { $0.days == "we" })].filter { !$0.1.isEmpty }
            ForEach(groups, id: \.0) { g in
                Eyebrow(text: g.0, color: Theme.mu, size: 12).padding(.top, 30).padding(.bottom, 6)
                ForEach(g.1) { c in item(c, c.planMeta) }
            }
        }
    }

    private func item(_ c: Commitment, _ sub: String) -> some View {
        HStack(spacing: 14) {
            Ico(name: c.icon, size: 19).foregroundStyle(Theme.tx)
            VStack(alignment: .leading, spacing: 4) {
                Text(c.name).rowTitle().foregroundStyle(Theme.tx)
                if !sub.isEmpty { Text(sub).font(Theme.label(13)).tracking(1.1).foregroundStyle(Theme.mu2) }
            }
        }
        .padding(.vertical, 11)
    }

    // ---- week log parts ----

    private func strip(_ w: Week) -> some View {
        let st = Logic.weekStats(w, store.settings), ot = Logic.onTimePct(w, store.settings)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                stat("\(st.pct)%", "kept"); stat("\(st.kept)/\(st.days.count)", "days")
                if let ot { stat("\(ot)%", "on time") }
            }
            HStack(spacing: 5) {
                ForEach(st.days, id: \.self) { d in DaySquare(mark: w.marks[Rules.ymd(d)], radius: 4).frame(width: 16, height: 16) }
            }
        }
    }
    private func stat(_ v: String, _ l: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(v).font(Theme.num(18)).foregroundStyle(Theme.tx)
            Text(l).font(Theme.ui(14)).foregroundStyle(Theme.mu)
        }
    }

    @ViewBuilder private func reflection(_ w: Week) -> some View {
        let live = w.isActive
        let closed = w.closedAt.map { " · " + Fmt.date($0) } ?? ""
        Eyebrow(text: (live ? "Reflection so far" : "Reflection") + closed, color: Theme.mu, size: 12).padding(.top, 34).padding(.bottom, 12)
        if !live, let s = w.summary {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "AI summary", color: Theme.mu2)
                Text(s).font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx)
            }
            .padding(.bottom, 16)
        }
        let blocks = Journal.blocks(live ? w.liveRefl : w.reflection)
        if blocks.isEmpty {
            Text(live ? "Written when you close the week on Saturday." : "No reflection written.").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2)
        }
        ForEach(blocks) { b in
            VStack(alignment: .leading, spacing: 5) {
                if let q = b.q { Text(q).font(Theme.serifItalic(17)).foregroundStyle(Theme.mu) }
                if let d = b.d, let t = b.t { Eyebrow(text: "\(d), \(t)") }
                Text(b.x).font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx)
            }
            .padding(.bottom, 16)
        }
    }

    /// "5 on time (1 in grace) · 1 late · 1 rescheduled" for habits with a start-by
    private func tally(_ w: Week, _ c: Commitment) -> String {
        guard c.by != nil else { return "" }
        var on = 0, lt = 0, rs = 0, gr = 0
        let days = Rules.habitDays(w, store.settings)
        for d in days {
            let k = Rules.ymd(d)
            if w.flag(k, c.id + "@rs") { rs += 1 }
            if w.flag(k, c.id) && w.flag(k, c.id + "@grace") { gr += 1 }
            if w.flag(k, c.id) { if w.flag(k, c.id + "@late") { lt += 1 } else { on += 1 } }
        }
        guard on + lt + rs > 0 else { return "" }
        let graceWeek = Rules.graceDay(Rules.ymd(days.first ?? Now.date))
        return "\(on) on time" + (gr > 0 ? " (\(gr) in grace)" : "") + (lt > 0 ? " · \(lt) late" : graceWeek ? "" : " · 0 late") + (rs > 0 ? " · \(rs) rescheduled" : "")
    }

    private func nav(_ w: Week) -> some View {
        let i = ordered.firstIndex { $0.id == w.id } ?? 0
        let pv = i > 0 ? ordered[i - 1] : nil, nx = i + 1 < ordered.count ? ordered[i + 1] : nil
        return HStack {
            if let pv { Button("‹ \(pv.focus)") { step(-1) }.foregroundStyle(Theme.mu) }
            Spacer()
            Text("swipe for other weeks").font(Theme.ui(12)).foregroundStyle(Theme.mu2)
            Spacer()
            if let nx { Button("\(nx.focus) ›") { step(1) }.foregroundStyle(Theme.mu) }
        }
        .font(Theme.ui(14))
        .padding(.top, 40)
    }
}
