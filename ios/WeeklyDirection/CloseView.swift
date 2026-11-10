import SwiftUI

/// Close the week (web: openClose / renderClose): the result as recorded, the Saturday questions as prompts, one free
/// reflection (spoken or typed), and this week's journal, then Close. Then a rating per question that he
/// confirms. Closing writes status, closedAt, percentage, reflection and (when rated) growth, nothing else.
struct CloseSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let weekId: String
    /// the reflection spoken or typed on this page
    @State private var review = ""
    @State private var questions: [String] = []
    @State private var reflection = ""
    @State private var loaded = false
    /// step 2 of the review: a rating per question (1 better, 0 same, -1 worse, nil not said), proposed by the `tidy`
    /// function from what he wrote and confirmed or changed by him before closing
    @State private var rating = false
    @State private var ratings: [Int?] = []
    @State private var quotes: [String] = []
    /// what was proposed for each question: the sentence is only kept with a rating he left as proposed
    @State private var proposed: [Int?] = []
    @State private var asked = false
    @State private var reading = false

    private func toRatings() {
        guard !questions.isEmpty else { close(); return }
        Haptic.tick()
        withAnimation(.easeOut(duration: 0.2)) { rating = true }
        guard !asked else { return }
        asked = true
        let text = joined()
        guard text.count >= 8 else { return }
        reading = true
        Task {
            let r = await Tidy.rate(store, text, questions)
            reading = false
            guard let r else { return }
            // a rating he already tapped while it was reading stays his
            for i in ratings.indices where ratings[i] == nil { ratings[i] = r[i].v; quotes[i] = r[i].quote; proposed[i] = r[i].v }
        }
    }

    @ViewBuilder private var rateStep: some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { rating = false } } label: {
            HStack(spacing: 8) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium)); Text("Reflection") }
                .caps(15).foregroundStyle(Theme.mu)
        }
        .buttonStyle(.plain)
        Text("How did it go?").title(30).foregroundStyle(Theme.tx).padding(.top, 14)
        if reading {
            HStack(spacing: 10) { ProgressView().tint(Theme.ac); Text("Reading your reflection…").font(Theme.ui(15)).foregroundStyle(Theme.mu) }.padding(.top, 14)
        }
        ForEach(Array(questions.enumerated()), id: \.offset) { i, q in
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: Growth.sphere(q, store.settings), color: Theme.ac, size: 11)
                Text(q).font(Theme.serif(18)).lineSpacing(3).foregroundStyle(Theme.tx)
                if i < quotes.count, !quotes[i].isEmpty {
                    Text("“\(quotes[i])”").font(Theme.serifItalic(15)).lineSpacing(3).foregroundStyle(Theme.mu)
                }
                HStack(spacing: 8) { pick("Worse", -1, i); pick("Same", 0, i); pick("Better", 1, i) }.padding(.top, 2)
            }
            .padding(.top, 26)
        }
        Button { close() } label: {
            Text("Close the week").caps(16).foregroundStyle(Theme.onAc)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Theme.ac, in: RoundedRectangle(cornerRadius: Theme.r(16), style: .continuous))
        }
        .buttonStyle(.plain).padding(.top, 34)
        .accessibilityIdentifier("closeWeek")
    }

    /// tap to choose, tap again to clear (not said); one colour: only Better carries the accent
    private func pick(_ t: String, _ v: Int, _ i: Int) -> some View {
        let on = i < ratings.count && ratings[i] == v
        return Button { Haptic.tick(); if i < ratings.count { ratings[i] = on ? nil : v } } label: {
            Text(t).caps(14).foregroundStyle(on ? (v > 0 ? Theme.onAc : Theme.tx) : Theme.mu2)
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(on ? (v > 0 ? Theme.ac : Theme.card2) : Color.clear, in: RoundedRectangle(cornerRadius: Theme.r(11), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.r(11), style: .continuous).stroke(on ? (v > 0 ? Theme.ac : Theme.mu2) : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// spoken reflection: tidied, then added to what is already written; the questions are prompts, not fields
    private func spoken(_ raw: String) async -> String? {
        let tidy = await Tidy.clean(store, raw, mode: "reflection")
        let text = tidy ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let cur = review.trimmingCharacters(in: .whitespacesAndNewlines)
        review = cur.isEmpty ? text : cur + "\n\n" + text
        return tidy == nil ? Tidy.asSpoken : nil
    }

    var body: some View {
        ScrollView {
            if let w = store.week(weekId) {
                let st = Logic.weekStats(w, store.settings)
                VStack(alignment: .leading, spacing: 0) {
                    if rating { rateStep } else {
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
                    if store.settings.cafOn {
                        let lim = Logic.cafLimit(store.settings, Now.date.addingTimeInterval(86400)), sp = Logic.cafSplit(store.settings, lim)
                        Eyebrow(text: "Caffeine next week", color: Theme.mu, size: 12).padding(.top, 22)
                        Text(lim > 0 ? "Starts at \(lim) mg · AM \(sp.am) · PM \(sp.pm)" : "Caffeine-free").font(Theme.ui(15)).foregroundStyle(Theme.tx).padding(.top, 6)
                    }
                    DictateCard(title: "Reflect on this week", autoStart: router.dictateOnOpen, onText: spoken).padding(.top, 28)
                    // the Saturday questions are prompts to talk or write from (Eddie, Nov 10 2026): nothing to fill in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(questions, id: \.self) { q in
                            Text(q).font(Theme.serifItalic(16)).lineSpacing(3).foregroundStyle(Theme.mu)
                        }
                    }
                    .padding(.top, 22)
                    Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 22)
                    line(text: $review, placeholder: "Your reflection").padding(.top, 18)
                    Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 22)
                    Eyebrow(text: "This week’s journal", color: Theme.mu, size: 12).padding(.top, 18)
                    line(text: $reflection, placeholder: "Nothing written this week.").padding(.top, 8)
                    Button { toRatings() } label: {
                        Text(questions.isEmpty ? "Close the week" : "Next").caps(16).foregroundStyle(Theme.onAc)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Theme.ac, in: RoundedRectangle(cornerRadius: Theme.r(16), style: .continuous))
                    }
                    .buttonStyle(.plain).padding(.top, 26)
                    .accessibilityIdentifier("reviewNext")
                    }
                }
                .fullWidth().padding(.horizontal, 20).padding(.top, 34).padding(.bottom, 30)
                .onAppear {
                    guard !loaded else { return }
                    loaded = true
                    router.dictateOnOpen = false
                    questions = Logic.qsOf(w, store.settings)
                    ratings = Array(repeating: nil, count: questions.count)
                    quotes = Array(repeating: "", count: questions.count)
                    proposed = Array(repeating: nil, count: questions.count)
                    if router.rateOnOpen, store.isMock {      // screenshots: the step with a proposal in place
                        router.rateOnOpen = false; asked = true; rating = true
                        ratings = [1, 0, nil]; quotes = ["I caught it twice before it went anywhere.", "Worship was freer Sunday; midweek my mind was on the job.", ""]
                    }
                    reflection = w.liveRefl
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
    }

    /// writing straight on the page: no box around it
    private func line(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx).fullWidth()
    }

    /// what is saved as the week's reflection: the journal as it stands, then this reflection as one more stamped entry
    /// (the same shape as a journal entry, so it has no blank lines inside)
    private func joined() -> String {
        let r = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        return Journal.appended(r, at: Now.date, text: review) ?? r
    }

    private func close() {
        guard let cur = store.week(weekId), cur.isActive else { router.sheet = nil; return }
        let st = Logic.weekStats(cur, store.settings), text = joined()
        var fields: [String: Any] = ["status": "closed", "closedAt": Now.ms, "percentage": st.pct, "reflection": text]
        // only the questions he rated; a week with none gets no `growth` field at all
        let rated: [[String: Any]] = questions.indices.compactMap { i in
            guard let v = ratings[i] else { return nil }
            var r: [String: Any] = ["q": questions[i], "v": v, "s": Growth.sphere(questions[i], store.settings)]
            // his own sentence, kept so the sphere's page can show growth in his words
            if proposed[i] == v, !quotes[i].isEmpty { r["t"] = quotes[i] }
            return r
        }
        if !rated.isEmpty { fields["growth"] = rated }
        store.patchWeek(cur, fields)
        Haptic.success()
        Sound.play(.day, store.settings)
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
        guard store.online, t.count >= 20, store.week(weekId)?.summary == nil else { return }
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
