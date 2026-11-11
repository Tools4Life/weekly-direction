import SwiftUI

/// The prayer log week by week (Eddie, Nov 11 2026): each week's prayers with an AI summary of what he prayed about,
/// swiped through like the journal's weeks, to see how his prayers change over time.
struct PrayerWeek: Identifiable, Equatable {
    /// the week's id, or "earlier" for prayers from before the first week
    let id: String
    let week: Week?
    let entries: [PrayerEntry]
}

enum PrayerWeeks {
    /// Newest week first. A prayer belongs to the week that was sealed last before it was prayed, so a prayer after
    /// Saturday's sealing is already next week's.
    static func pages(_ log: [PrayerEntry], _ weeks: [Week]) -> [PrayerWeek] {
        let ws = weeks.sorted { $0.sealedAtMs < $1.sealedAtMs }
        var by: [String: [PrayerEntry]] = [:]
        for e in log { by[ws.last { $0.sealedAtMs <= e.at }?.id ?? "earlier", default: []].append(e) }
        var out = ws.reversed().compactMap { w in by[w.id].map { PrayerWeek(id: w.id, week: w, entries: $0.sorted { $0.at > $1.at }) } }
        if let e = by["earlier"] { out.append(PrayerWeek(id: "earlier", week: nil, entries: e.sorted { $0.at > $1.at })) }
        return out
    }

    /// A week is summarized once it is over: its week is closed, or (before the first week) newer prayers exist.
    static func finished(_ p: PrayerWeek, newest: Bool) -> Bool { p.week.map { !$0.isActive } ?? !newest }

    /// what is sent to be summarized: the week's prayers in the order he prayed them
    static func text(_ p: PrayerWeek) -> String {
        p.entries.sorted { $0.at < $1.at }.map { Fmt.stamp($0.date) + "\n" + $0.text }.joined(separator: "\n\n")
    }

    private static var asking = Set<String>()

    /// Asked once per finished week and stored beside the prayers; the prayers themselves are never changed.
    @MainActor static func summarize(_ p: PrayerWeek, newest: Bool, store: Store) async {
        let t = text(p)
        guard store.online, finished(p, newest: newest), store.prayerSummaries[p.id] == nil, t.count >= 20, !asking.contains(p.id) else { return }
        asking.insert(p.id)
        defer { asking.remove(p.id) }
        do {
            var req = URLRequest(url: Summary.url)
            req.httpMethod = "POST"
            req.setValue("Bearer " + (try await store.token()), forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["mode": "prayers", "text": t, "focus": p.week?.focus ?? ""])
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  // a server that does not know prayers yet answers without this: its summary would be a journal one
                  j["mode"] as? String == "prayers",
                  let s = (j["summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
                  store.prayerSummaries[p.id] == nil else { return }
            store.putPrayerSummary(p.id, s)
        } catch {}
    }
}

struct PrayerWeeksView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var forward = true
    @State private var deleting: PrayerEntry?
    @State private var loaded = false

    var body: some View {
        let pages = PrayerWeeks.pages(store.prayerLog, store.weeks)
        let i = min(index, max(0, pages.count - 1))
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 10) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium)); Text("Prayer") }
                        .caps(16).foregroundStyle(Theme.mu)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 24).frame(height: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if pages.isEmpty {
                        Text("No prayers yet.").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2).padding(.top, 20)
                    } else {
                        page(pages[i])
                        nav(pages, i)
                    }
                }
                .fullWidth().padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 50)
            }
            .scrollIndicators(.hidden)
            // a new week slides in from the side it was swiped from
            .id(pages.isEmpty ? "" : pages[i].id)
            .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { g in
                guard abs(g.translation.width) > 60, abs(g.translation.width) > abs(g.translation.height) * 1.6 else { return }
                // swipe left for the newer week, right for the older one, as in the journal
                step(g.translation.width < 0 ? -1 : 1, pages.count)
            })
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            guard !loaded else { return }
            loaded = true
            index = min(router.prayerWeekStart, max(0, pages.count - 1)); router.prayerWeekStart = 0
        }
        // finished weeks that have no summary yet get one, newest first
        .task {
            for (n, p) in pages.enumerated().prefix(6) { await PrayerWeeks.summarize(p, newest: n == 0, store: store) }
        }
        .alert("Delete this prayer from the log? This can’t be undone.", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) { if let d = deleting { store.delPrayerLog(d.id) }; deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        }
    }

    /// d > 0 goes to the older week (pages are newest first)
    private func step(_ d: Int, _ count: Int) {
        let n = index + d
        guard n >= 0, n < count else { return }
        Haptic.tick()
        forward = d < 0
        withAnimation(.easeOut(duration: 0.22)) { index = n }
    }

    @ViewBuilder private func page(_ p: PrayerWeek) -> some View {
        if let w = p.week {
            Eyebrow(text: (w.isActive ? "This week · " : "") + Fmt.weekRange(w, store.settings), color: w.isActive ? Theme.ac : Theme.mu2, size: 12)
            Text(w.focus).font(Theme.serif(34)).foregroundStyle(Theme.tx).padding(.top, 6)
        } else {
            Eyebrow(text: "Before the first week", color: Theme.mu2, size: 12)
            Text("Earlier").font(Theme.serif(34)).foregroundStyle(Theme.tx).padding(.top, 6)
        }
        if let s = store.prayerSummaries[p.id] { SummaryBlock(text: s).padding(.top, 18) }
        PrayerDays(entries: p.entries, deleting: $deleting)
    }

    /// the week before and after, by their focus words: tap, or swipe the page sideways
    @ViewBuilder private func nav(_ pages: [PrayerWeek], _ i: Int) -> some View {
        let older = i + 1 < pages.count ? pages[i + 1] : nil, newer = i > 0 ? pages[i - 1] : nil
        if older != nil || newer != nil {
            Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 30)
            HStack {
                if let older {
                    Button { step(1, pages.count) } label: {
                        HStack(spacing: 8) { Image(systemName: "chevron.left").font(.system(size: 13, weight: .medium)); Text(older.week?.focus ?? "Earlier") }
                    }
                }
                Spacer()
                if let newer {
                    Button { step(-1, pages.count) } label: {
                        HStack(spacing: 8) { Text(newer.week?.focus ?? "Earlier"); Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)) }
                    }
                }
            }
            .font(Theme.jserif(17)).foregroundStyle(Theme.mu).buttonStyle(.plain).padding(.top, 16)
        }
    }
}
