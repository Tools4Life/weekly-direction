import SwiftUI

/// Reflect (web: rfRender / renderPrayer): Journal | Prayer. The journal is one card, one week at a time, that always
/// fits above the mic; earlier weeks are a swipe away.
struct ReflectView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var recorder: Recorder

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Reflect").font(Theme.serif(44)).foregroundStyle(Theme.tx)
                Spacer()
                Seg(options: [("j", "Journal"), ("p", "Prayer")], value: $router.reflectView)
            }
            .padding(.horizontal, 24).padding(.top, 20)
            if router.reflectView == "p" {
                PrayerList()
            } else {
                journal
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg)
    }

    /// this week first, then closed weeks that have something written, newest first
    private var weeks: [Week] {
        let closed = store.weeks.filter { w in
            w.status == "closed" && (!(w.reflection.isEmpty ? w.liveRefl : w.reflection).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || w.summary != nil)
        }.sorted { $0.sealedAtMs > $1.sealedAtMs }
        return (store.activeWeek.map { [$0] } ?? []) + closed
    }

    private var journal: some View {
        let W = weeks, idx = min(router.reflectIndex, max(0, W.count - 1))
        return VStack(spacing: 0) {
            if W.isEmpty {
                Text("Nothing yet.").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2).fullWidth().padding(24)
            } else {
                JournalCard(week: W[idx], active: W[idx].id == store.activeWeek?.id, hasEarlier: idx < W.count - 1, hasLater: idx > 0,
                            go: { d in go(d, W.count) })
                    .padding(.horizontal, 24).padding(.top, 22)
                    .id(W[idx].id)
                    .transition(.opacity)
            }
            Spacer(minLength: 12)
            if store.activeWeek != nil { MicDock().padding(.bottom, 14) }
        }
    }

    private func go(_ d: Int, _ count: Int) {
        let k = d == -99 ? 0 : max(0, min(count - 1, router.reflectIndex + d))
        guard k != router.reflectIndex else { return }
        Haptic.tick()
        withAnimation(.easeOut(duration: 0.2)) { router.reflectIndex = k }
    }
}

private struct JournalCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var recorder: Recorder
    let week: Week
    let active: Bool
    let hasEarlier: Bool, hasLater: Bool
    let go: (Int) -> Void

    var body: some View {
        let text = active ? week.liveRefl : (week.reflection.isEmpty ? week.liveRefl : week.reflection)
        let ents = Journal.entries(text)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                arrow("chevron.left", enabled: hasEarlier) { go(1) }.accessibilityLabel("Earlier week")
                Spacer()
                Eyebrow(text: (active ? "This week · " : "") + Fmt.weekRange(week, store.settings), color: active ? Theme.ac : Theme.mu2, size: 14)
                Spacer()
                arrow("chevron.right", enabled: hasLater) { go(-1) }.accessibilityLabel("Later week")
            }
            .padding(.horizontal, -8)
            Text(week.focus).font(Theme.serif(26)).foregroundStyle(Theme.tx).padding(.top, 12)
            if active { activeBody(ents) } else { pastBody(ents, text) }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.ac.opacity(0.22), lineWidth: 1))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 30).onEnded { g in
            if abs(g.translation.width) > 55, abs(g.translation.width) > abs(g.translation.height) * 1.5 { go(g.translation.width > 0 ? 1 : -1) }
        })
    }

    private func arrow(_ name: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 15, weight: .medium)).foregroundStyle(enabled ? Theme.mu : Theme.line)
                .frame(width: 40, height: 40).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled)
    }

    @ViewBuilder private func activeBody(_ ents: [Journal.Block]) -> some View {
        if week.verse != nil || week.verseRef != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let v = week.verse { Text(v).font(Theme.serifItalic(16)).lineSpacing(5).foregroundStyle(Theme.mu).lineLimit(2) }
                if let r = week.verseRef { Eyebrow(text: r, color: Theme.mu2) }
            }
            .padding(.top, 10)
        }
        Rectangle().fill(Theme.rule).frame(height: 1).padding(.vertical, 18)
        if let e = ents.last {
            VStack(alignment: .leading, spacing: 6) {
                if let d = e.d, let t = e.t {
                    Eyebrow(text: "\(d == Fmt.dowl[Rules.weekday(Now.date)] ? "Today" : d) · \(t)", color: Theme.mu2)
                }
                Text(e.x).font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx).truncationMode(.tail)
            }
            .fullWidth()
            .contentShape(Rectangle())
            .onTapGesture { Haptic.tick(); router.cover = .weekPage(week.id) }
            .onLongPressGesture(minimumDuration: 0.5) { Haptic.tick(); router.entryMenu = e.i }
        } else {
            Text("Nothing yet this week.").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2)
        }
        HStack {
            if ents.count > 1 {
                Button("All \(ents.count) entries ›") { router.cover = .weekPage(week.id) }.foregroundStyle(Theme.mu)
            }
            Spacer()
            Button {
                if recorder.state == .idle { Haptic.tick(); router.cover = .write }
            } label: {
                HStack(spacing: 7) { Image(systemName: "pencil.line").font(.system(size: 15)); Text("Write") }.foregroundStyle(Theme.ac)
            }
        }
        .font(Theme.ui(16)).buttonStyle(.plain)
        .padding(.top, 16)
    }

    @ViewBuilder private func pastBody(_ ents: [Journal.Block], _ text: String) -> some View {
        Rectangle().fill(Theme.rule).frame(height: 1).padding(.vertical, 18)
        VStack(alignment: .leading, spacing: 6) {
            if week.summary != nil { Eyebrow(text: "AI summary", color: Theme.mu2) }
            Text(week.summary ?? Journal.blocks(text).first?.x ?? "").font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx)
        }
        HStack {
            Button("Read the week" + (ents.isEmpty ? "" : " · \(ents.count) \(ents.count == 1 ? "entry" : "entries")") + " ›") { router.cover = .weekPage(week.id) }
            Spacer()
            if store.activeWeek != nil { Button("This week") { go(-99) } }
        }
        .font(Theme.ui(16)).foregroundStyle(Theme.mu).buttonStyle(.plain)
        .padding(.top, 16)
    }
}

/// One week on its own page (web: rfOpenWeek / rfBody): everything said that week, newest day first.
/// This week only: Select several to delete, press and hold one to edit or delete.
struct WeekPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss
    let weekId: String
    @State private var selecting = false
    @State private var picked = Set<Int>()
    @State private var confirmDelete = false
    @State private var editing: EditRef?
    @State private var vision = false

    struct EditRef: Identifiable { let id: Int }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 8) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium)); Text("Journal") }
                    }
                    Spacer()
                    if let w = store.week(weekId), w.isActive, !Journal.entries(w.liveRefl).isEmpty {
                        Button(selecting ? "Cancel" : "Select") { Haptic.tick(); selecting.toggle(); picked = [] }
                    }
                }
                .font(Theme.ui(18)).foregroundStyle(Theme.ac)
                .padding(.horizontal, 22).frame(height: 52)
                ScrollView {
                    if let w = store.week(weekId) {
                        VStack(alignment: .leading, spacing: 0) { page(w) }
                            .fullWidth().padding(.horizontal, 24).padding(.top, 12).padding(.bottom, selecting ? 110 : 50)
                    }
                }
                .scrollIndicators(.hidden)
            }
            if selecting {
                Button { confirmDelete = true } label: {
                    Text(picked.isEmpty ? "Delete" : "Delete \(picked.count) \(picked.count == 1 ? "entry" : "entries")")
                        .font(Theme.ui(18, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Theme.danger.opacity(picked.isEmpty ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain).disabled(picked.isEmpty)
                .padding(.horizontal, 24).padding(.bottom, 12)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { if router.selectMode { selecting = true; router.selectMode = false; if store.isMock { picked = [1] } } }
        .alert("Delete \(picked.count) \(picked.count == 1 ? "entry" : "entries")? This can’t be undone.", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let w = store.week(weekId), w.isActive, !picked.isEmpty {
                    store.patchWeek(w, ["liveRefl": Journal.removed(w.liveRefl, indexes: Array(picked))])
                }
                selecting = false; picked = []
            }
            Button("Cancel", role: .cancel) {}
        }
        .modifier(EntryMenu(onEdit: { i in editing = EditRef(id: i) }))
        .fullScreenCover(item: $editing) { e in EntryEditor(entry: e.id).environmentObject(store).environmentObject(router) }
        .fullScreenCover(isPresented: $vision) { VisionView(weekId: weekId, log: true).environmentObject(store) }
    }

    @ViewBuilder private func page(_ w: Week) -> some View {
        let active = w.isActive
        let all = Journal.blocks(active ? w.liveRefl : (w.reflection.isEmpty ? w.liveRefl : w.reflection))
        let ents = all.filter { $0.q == nil }, qa = all.filter { $0.q != nil }
        Eyebrow(text: Fmt.weekRange(w, store.settings), color: Theme.mu2, size: 14)
        Text(w.focus).font(Theme.serif(40)).foregroundStyle(Theme.tx).padding(.top, 6)
        if let s = w.summary {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "AI summary", color: Theme.mu2)
                Text(s).font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx)
            }
            .padding(.top, 16)
        }
        if w.verse != nil || w.verseRef != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let v = w.verse { Text(v).font(Theme.serifItalic(16)).lineSpacing(5).foregroundStyle(Theme.mu) }
                if let r = w.verseRef { Eyebrow(text: r, color: Theme.mu2) }
            }
            .padding(.top, 16)
        }
        ForEach(groups(ents), id: \.first!.i) { g in
            dayHead(w, g[0].d, active: active)
            ForEach(g) { e in entry(e, active: active) }
        }
        if !qa.isEmpty {
            Text("Saturday review").font(Theme.serif(24)).foregroundStyle(Theme.tx).padding(.top, 36).padding(.bottom, 8)
            ForEach(qa) { e in
                VStack(alignment: .leading, spacing: 6) {
                    Text(e.q ?? "").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu)
                    Text(e.x).font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx)
                }
                .padding(.top, 14)
            }
        }
        if ents.isEmpty && qa.isEmpty {
            Text(active ? "Nothing yet this week." : "Nothing written this week.").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2).padding(.top, 30)
        }
        HStack {
            Spacer()
            if active {
                Button { router.cover = .write } label: {
                    HStack(spacing: 7) { Image(systemName: "pencil.line").font(.system(size: 15)); Text("Write") }.foregroundStyle(Theme.ac)
                }
            } else {
                Button("Open week") { vision = true }.foregroundStyle(Theme.mu)
            }
        }
        .font(Theme.ui(16)).buttonStyle(.plain).padding(.top, 34)
    }

    /// consecutive entries of the same day, newest day first, newest entry first
    private func groups(_ ents: [Journal.Block]) -> [[Journal.Block]] {
        var out: [[Journal.Block]] = []
        for e in ents {
            if let last = out.last, last[0].d == e.d { out[out.count - 1].append(e) } else { out.append([e]) }
        }
        return out.reversed().map { $0.reversed() }
    }

    private func dayHead(_ w: Week, _ d: String?, active: Bool) -> some View {
        // the first seven days from sealing give each weekday name its date
        var dates: [String: Date] = [:]
        let s0 = Rules.cal.date(bySettingHour: 12, minute: 0, second: 0, of: w.sealedAt)!
        for i in 0..<7 { let x = s0.addingTimeInterval(Double(i) * 86400); dates[Fmt.dowl[Rules.weekday(x)]] = x }
        let today = active && d == Fmt.dowl[Rules.weekday(Now.date)]
        return HStack(alignment: .firstTextBaseline) {
            Text(today ? "Today" : d ?? "Notes").font(Theme.serif(24)).foregroundStyle(Theme.tx)
            Spacer()
            if let d, let x = dates[d] { Eyebrow(text: (today ? d + " · " : "") + Fmt.date(x), color: Theme.mu2, size: 14) }
        }
        .padding(.top, 36)
    }

    private func entry(_ e: Journal.Block, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if selecting {
                ZStack {
                    Circle().stroke(picked.contains(e.i) ? Theme.ac : Theme.mu2, lineWidth: 1.5)
                    if picked.contains(e.i) {
                        Circle().fill(Theme.ac)
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.onAc)
                    }
                }
                .frame(width: 22, height: 22).padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 6) {
                if let t = e.t { Eyebrow(text: t, color: Theme.mu2) }
                Text(e.x).font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx)
            }
        }
        .fullWidth()
        .padding(.top, 18)
        .contentShape(Rectangle())
        .onTapGesture {
            guard active, selecting else { return }
            Haptic.tick()
            if picked.contains(e.i) { picked.remove(e.i) } else { picked.insert(e.i) }
        }
        .onLongPressGesture(minimumDuration: 0.5) { if active, !selecting { Haptic.tick(); router.entryMenu = e.i } }
    }
}

/// Press and hold an entry from this week: its preview, Edit, Delete, Cancel (web: rfMenu)
struct EntryMenu: ViewModifier {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let onEdit: (Int) -> Void
    @State private var confirm = false
    @State private var target: Int?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let i = router.entryMenu, let w = store.activeWeek, let b = Journal.blocks(w.liveRefl).first(where: { $0.i == i }) {
                    ZStack(alignment: .bottom) {
                        Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { router.entryMenu = nil }
                        VStack(spacing: 8) {
                            VStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Eyebrow(text: b.d.map { "\($0), \(b.t ?? "")" } ?? "Entry", color: Theme.mu2, size: 14)
                                    Text(b.x).font(Theme.serif(17)).lineSpacing(5).foregroundStyle(Theme.mu).lineLimit(3)
                                }
                                .fullWidth().padding(.horizontal, 18).padding(.vertical, 16)
                                Rectangle().fill(Theme.rule).frame(height: 1)
                                Button("Edit") { router.entryMenu = nil; onEdit(i) }
                                    .font(Theme.ui(19)).foregroundStyle(Theme.ac).frame(maxWidth: .infinity).frame(height: 58)
                                Rectangle().fill(Theme.rule).frame(height: 1)
                                Button("Delete") { target = i; confirm = true }
                                    .font(Theme.ui(19)).foregroundStyle(Theme.danger).frame(maxWidth: .infinity).frame(height: 58)
                            }
                            .background(Theme.card2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            Button("Cancel") { router.entryMenu = nil }
                                .font(Theme.ui(19, .semibold)).foregroundStyle(Theme.tx).frame(maxWidth: .infinity).frame(height: 58)
                                .background(Theme.card2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10).padding(.bottom, 8)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: router.entryMenu)
            .alert("Delete this entry? This can’t be undone.", isPresented: $confirm) {
                Button("Delete", role: .destructive) {
                    if let i = target, let w = store.activeWeek, let t = Journal.replaced(w.liveRefl, index: i, text: "") { store.patchWeek(w, ["liveRefl": t]) }
                    router.entryMenu = nil
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}

/// Write a new entry, or edit one keeping its stamp (web: openJournal with fresh / ent)
struct EntryEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    /// block index to edit, or nil for a new entry
    let entry: Int?
    @State private var text = ""
    @State private var opened = Now.date
    @State private var loaded = false
    @State private var confirmDiscard = false
    @FocusState private var focused: Bool

    var body: some View {
        let w = store.activeWeek
        let blk = entry.flatMap { i in w.flatMap { Journal.blocks($0.liveRefl).first { $0.i == i } } }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Cancel") {
                    if entry == nil, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { confirmDiscard = true } else { dismiss() }
                }
                .font(Theme.ui(18)).foregroundStyle(Theme.mu)
                Spacer()
                Button(entry == nil ? "Add" : "Save") { save(); dismiss() }.font(Theme.ui(18, .semibold)).foregroundStyle(Theme.ac)
            }
            .frame(height: 52)
            Eyebrow(text: entry == nil ? "New entry · \(Fmt.stamp(opened))" : "Edit entry" + (blk?.d.map { " · \($0), \(blk?.t ?? "")" } ?? ""),
                    color: Theme.mu, size: 14).padding(.top, 8)
            Text(w?.focus ?? "").font(Theme.serif(24)).foregroundStyle(Theme.tx).padding(.top, 12)
            TextEditor(text: $text)
                .font(Theme.serif(20)).lineSpacing(8).foregroundStyle(Theme.tx)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(.horizontal, -5).padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            guard !loaded else { return }
            loaded = true; opened = Now.date
            if let blk { text = blk.x }
            focused = true
        }
        .confirmationDialog("Discard this entry?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep writing", role: .cancel) {}
        }
    }

    private func save() {
        guard let w = store.activeWeek else { return }
        if let entry {
            // empty text removes the entry, exactly as the web app does
            if let t = Journal.replaced(w.liveRefl, index: entry, text: text), t != w.liveRefl { store.patchWeek(w, ["liveRefl": t]) }
        } else if let t = Journal.appended(w.liveRefl, at: Now.date, text: text) {
            store.patchWeek(w, ["liveRefl": t])
        }
    }
}
