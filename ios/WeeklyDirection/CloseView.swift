import SwiftUI

/// Close the week (web: openClose / renderClose): the result as recorded, the Saturday questions, the reflection
/// (starts as this week's journal), then Close. Closing writes status, closedAt, percentage and reflection, nothing else.
struct CloseSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let weekId: String
    @State private var answers: [String] = []
    @State private var questions: [String] = []
    @State private var reflection = ""
    @State private var loaded = false

    var body: some View {
        ScrollView {
            if let w = store.week(weekId) {
                let st = Logic.weekStats(w, store.settings)
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: Fmt.weekRange(w, store.settings), color: Theme.mu2, size: 12)
                    Text(w.focus).font(Theme.serif(34)).foregroundStyle(Theme.tx).padding(.top, 6)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(st.pct)").font(Theme.num(32)).foregroundStyle(Theme.tx)
                            Text("%").font(Theme.num(16)).foregroundStyle(Theme.tx)
                        }
                        Text("\(st.kept) of \(st.days.count) days kept").font(Theme.ui(15)).foregroundStyle(Theme.mu)
                    }
                    .padding(.top, 18)
                    HStack(spacing: 8) {
                        ForEach(st.days, id: \.self) { d in
                            VStack(spacing: 5) {
                                DaySquare(mark: w.marks[Rules.ymd(d)]).frame(height: 30)
                                Text(Fmt.dow[Rules.weekday(d)]).font(Theme.label(12)).tracking(1.2).foregroundStyle(Theme.mu2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 14)
                    let unm = st.days.filter { w.marks[Rules.ymd($0)] == nil }.count
                    Text(unm > 0 ? "\(unm) \(unm == 1 ? "day wasn’t" : "days weren’t") kept. Days are recorded as they happened." : "Days are recorded as they happened.")
                        .font(Theme.ui(14)).foregroundStyle(Theme.mu).padding(.top, 12)
                    if store.settings.cafOn {
                        let lim = Logic.cafLimit(store.settings, Now.date.addingTimeInterval(86400)), sp = Logic.cafSplit(store.settings, lim)
                        Eyebrow(text: "Caffeine next week", color: Theme.mu, size: 12).padding(.top, 22)
                        Text(lim > 0 ? "Starts at \(lim) mg · AM \(sp.am) · PM \(sp.pm)" : "Caffeine-free").font(Theme.ui(15)).foregroundStyle(Theme.tx).padding(.top, 6)
                    }
                    ForEach(Array(questions.enumerated()), id: \.offset) { i, q in
                        Text(q).font(Theme.serif(18)).lineSpacing(5).foregroundStyle(Theme.tx).padding(.top, 24)
                        box(text: Binding(get: { i < answers.count ? answers[i] : "" }, set: { if i < answers.count { answers[i] = $0 } }), placeholder: "Answer", minHeight: 72)
                            .padding(.top, 10)
                    }
                    HStack(spacing: 12) {
                        Eyebrow(text: "Reflection", color: Theme.mu, size: 12)
                        Eyebrow(text: "optional", color: Theme.mu2, size: 12)
                    }
                    .padding(.top, 28)
                    box(text: $reflection, placeholder: "Anything else from the week?", minHeight: 96).padding(.top, 10)
                    Button { close() } label: {
                        Text("Close the week").caps(16).foregroundStyle(Theme.onAc)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Theme.ac, in: RoundedRectangle(cornerRadius: Theme.r(16), style: .continuous))
                    }
                    .buttonStyle(.plain).padding(.top, 26)
                    .accessibilityIdentifier("closeWeek")
                }
                .fullWidth().padding(.horizontal, 20).padding(.top, 34).padding(.bottom, 30)
                .onAppear {
                    guard !loaded else { return }
                    loaded = true
                    questions = Logic.qsOf(w, store.settings)
                    answers = Array(repeating: "", count: questions.count)
                    reflection = w.liveRefl
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
    }

    private func box(text: Binding<String>, placeholder: String, minHeight: CGFloat) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(Theme.serif(17)).lineSpacing(6).foregroundStyle(Theme.tx)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    /// joinRef: each answered question as "question\nanswer", then the reflection, separated by blank lines
    private func joined() -> String {
        var parts = questions.enumerated().compactMap { i, q -> String? in
            let a = answers[i].trimmingCharacters(in: .whitespacesAndNewlines)
            return a.isEmpty ? nil : "\(q)\n\(a)"
        }
        let r = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !r.isEmpty { parts.append(r) }
        return parts.joined(separator: "\n\n")
    }

    private func close() {
        guard let cur = store.week(weekId), cur.isActive else { router.sheet = nil; return }
        let st = Logic.weekStats(cur, store.settings), text = joined()
        store.patchWeek(cur, ["status": "closed", "closedAt": Now.ms, "percentage": st.pct, "reflection": text])
        Haptic.success()
        router.sheet = nil
        router.selK = nil
        let store = store, id = weekId, focus = cur.focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.cover = .closed(id) }
        Task { try? await Task.sleep(nanoseconds: 800_000_000); await Summary.write(store: store, weekId: id, focus: focus, text: text) }
    }
}

/// AI week summary (web: sumWeek): asked once after closing, stored beside the reflection, never replacing it
enum Summary {
    static let url = URL(string: "https://us-central1-ops-hub-9bebc.cloudfunctions.net/summarize")!

    @MainActor static func write(store: Store, weekId: String, focus: String, text: String) async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !store.isMock, t.count >= 20, store.week(weekId)?.summary == nil else { return }
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer " + (try await store.token()), forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["text": t, "focus": focus])
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let s = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["summary"] as? String,
                  let cur = store.week(weekId), cur.summary == nil else { return }
            store.patchWeek(cur, ["summary": s.trimmingCharacters(in: .whitespacesAndNewlines), "summaryAt": Date().timeIntervalSince1970 * 1000])
        } catch {}
    }
}

/// The week's close (web: closeMoment): the % counts up and the days fill in. Planning the next week is a button here;
/// it never opens by itself.
struct ClosedMoment: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let weekId: String
    @State private var shown = 0
    @State private var lit = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if let w = store.week(weekId) {
                let st = Logic.weekStats(w, store.settings)
                Eyebrow(text: "Week closed", color: Theme.mu2, size: 12)
                Text(w.focus).font(Theme.serif(34)).foregroundStyle(Theme.tx).padding(.top, 10)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(shown)").font(Theme.num(72)).foregroundStyle(Theme.tx).contentTransition(.numericText())
                    Text("%").font(Theme.ui(24)).foregroundStyle(Theme.mu)
                }
                .padding(.top, 18)
                Text("\(st.kept) of \(st.days.count) days kept").font(Theme.ui(15)).foregroundStyle(Theme.mu)
                HStack(spacing: 8) {
                    ForEach(Array(st.days.enumerated()), id: \.offset) { i, d in
                        VStack(spacing: 5) {
                            DaySquare(mark: i < lit ? w.marks[Rules.ymd(d)] : nil).frame(width: 34, height: 30)
                            Text(Fmt.dow[Rules.weekday(d)]).font(Theme.label(12)).foregroundStyle(Theme.mu2)
                        }
                    }
                }
                .padding(.top, 26)
                .onAppear { run(st) }
            }
            Spacer()
            Button { router.cover = .plan(replan: nil) } label: {
                Text("Plan the next week").caps(16).foregroundStyle(Theme.onAc)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Theme.ac, in: RoundedRectangle(cornerRadius: Theme.r(16), style: .continuous))
            }
            .buttonStyle(.plain)
            Button("Later") { router.cover = nil }.caps(16).foregroundStyle(Theme.mu).padding(.top, 18).padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func run(_ st: Logic.WeekStats) {
        for i in 0...20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.045) {
                let k = Double(i) / 20, e = 1 - pow(1 - k, 3)
                withAnimation(.linear(duration: 0.04)) { shown = Int((Double(st.pct) * e).rounded()) }
            }
        }
        for i in 0..<st.days.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(i) * 0.11) { withAnimation(.spring(response: 0.3)) { lit = i + 1 } }
        }
    }
}
