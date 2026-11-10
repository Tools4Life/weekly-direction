import SwiftUI

// The journal list itself is JournalList.swift; this file holds the week page, the entry menu and the editor.

/// One week on its own page (web: rfOpenWeek / rfBody): everything said that week, newest day first.
/// This week only: Select several to delete, press and hold one to edit or delete.
struct WeekPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var recorder: Recorder
    @Environment(\.dismiss) private var dismiss
    /// the week on the page; swiping sideways moves to the week before or after
    @State var weekId: String
    @State private var forward = true
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
                    // the app's one top bar: back in muted caps, the action in accent caps (as in Settings)
                    Button { dismiss() } label: {
                        HStack(spacing: 10) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium)); Text("Journal") }
                            .foregroundStyle(Theme.mu)
                    }
                    Spacer()
                    if let w = store.week(weekId), w.isActive, !Journal.entries(w.liveRefl).isEmpty {
                        Button(selecting ? "Cancel" : "Select") { Haptic.tick(); selecting.toggle(); picked = [] }.foregroundStyle(Theme.ac)
                    }
                }
                .caps(16).buttonStyle(.plain)
                .padding(.horizontal, 24).frame(height: 52)
                ScrollView {
                    if let w = store.week(weekId) {
                        VStack(alignment: .leading, spacing: 0) { page(w); weekNav }
                            .fullWidth().padding(.horizontal, 24).padding(.top, 12).padding(.bottom, selecting ? 110 : 50)
                    }
                }
                .scrollIndicators(.hidden)
                // a new week slides in from the side it was swiped from
                .id(weekId)
                .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { g in
                    guard !selecting, abs(g.translation.width) > 60, abs(g.translation.width) > abs(g.translation.height) * 1.6 else { return }
                    step(g.translation.width < 0 ? 1 : -1)
                })
            }
            if selecting {
                Button { confirmDelete = true } label: {
                    Text(picked.isEmpty ? "Delete" : "Delete \(picked.count) \(picked.count == 1 ? "entry" : "entries")")
                        // the app's own button shape: a quiet outlined row, red only in the words (no filled red slab)
                        .caps(16).foregroundStyle(picked.isEmpty ? Theme.mu2 : Theme.danger)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Theme.card2, in: RoundedRectangle(cornerRadius: Theme.r(13), style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.r(13), style: .continuous)
                            .stroke(picked.isEmpty ? Theme.line : Theme.danger.opacity(0.55), lineWidth: 1))
                }
                .buttonStyle(.plain).disabled(picked.isEmpty)
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
                // a solid footer: entries scroll behind it, never past it
                .background(Theme.bg.ignoresSafeArea(edges: .bottom))
                .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
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
        .fullScreenCover(isPresented: $vision) { VisionView(weekId: weekId, log: true).environmentObject(store).environmentObject(router).environmentObject(recorder) }
    }

    private var ordered: [Week] { store.weeks.sorted { $0.sealedAtMs < $1.sealedAtMs } }
    private func neighbour(_ d: Int) -> Week? {
        guard let i = ordered.firstIndex(where: { $0.id == weekId }), ordered.indices.contains(i + d) else { return nil }
        return ordered[i + d]
    }
    private func step(_ d: Int) {
        guard let n = neighbour(d) else { return }
        Haptic.tick()
        forward = d > 0
        selecting = false; picked = []
        withAnimation(.easeOut(duration: 0.22)) { weekId = n.id }
    }

    /// the week before and after, by their focus words: tap, or swipe the page sideways
    @ViewBuilder private var weekNav: some View {
        let older = neighbour(-1), newer = neighbour(1)
        if !selecting, older != nil || newer != nil {
            Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 30)
            HStack {
                if let older {
                    Button { step(-1) } label: {
                        HStack(spacing: 8) { Image(systemName: "chevron.left").font(.system(size: 13, weight: .medium)); Text(older.focus) }
                    }
                }
                Spacer()
                if let newer {
                    Button { step(1) } label: {
                        HStack(spacing: 8) { Text(newer.focus); Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)) }
                    }
                }
            }
            .font(Theme.jserif(17)).foregroundStyle(Theme.mu).buttonStyle(.plain).padding(.top, 16)
        }
    }

    @ViewBuilder private func page(_ w: Week) -> some View {
        let active = w.isActive
        let all = Journal.blocks(active ? w.liveRefl : (w.reflection.isEmpty ? w.liveRefl : w.reflection))
        let ents = all.filter { $0.q == nil }, qa = all.filter { $0.q != nil }
        Eyebrow(text: Fmt.weekRange(w, store.settings), color: Theme.mu2, size: 12)
        Text(w.focus).font(Theme.jserif(34)).foregroundStyle(Theme.tx).padding(.top, 6)
        if let s = w.summary {
            SummaryBlock(text: s).padding(.top, 18)
        }
        if w.verse != nil || w.verseRef != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let v = w.verse { Text(v).font(Theme.jitalic(16)).lineSpacing(5).foregroundStyle(Theme.mu) }
                if let r = w.verseRef { Eyebrow(text: r, color: Theme.mu2) }
            }
            .padding(.top, 16)
        }
        ForEach(groups(ents), id: \.first!.i) { g in
            dayHead(w, g[0].d, active: active)
            ForEach(g) { e in entry(e, active: active) }
        }
        if !qa.isEmpty {
            Text("Saturday review").font(Theme.jserif(20)).foregroundStyle(Theme.tx).padding(.top, 36).padding(.bottom, 8)
            ForEach(qa) { e in
                VStack(alignment: .leading, spacing: 6) {
                    Text(e.q ?? "").font(Theme.jitalic(17)).foregroundStyle(Theme.mu)
                    Text(e.x).font(Theme.jserif(18)).lineSpacing(6).foregroundStyle(Theme.tx)
                }
                .padding(.top, 14)
            }
        }
        if ents.isEmpty && qa.isEmpty {
            Text(active ? "Nothing yet this week." : "Nothing written this week.").font(Theme.jitalic(17)).foregroundStyle(Theme.mu2).padding(.top, 30)
        }
        HStack {
            Spacer()
            if active {
                Button { router.cover = .write } label: {
                    HStack(spacing: 8) { Image(systemName: "plus").font(.system(size: 15)); Text("New").caps(16) }.foregroundStyle(Theme.ac)
                }
            } else {
                Button("Open week") { vision = true }.foregroundStyle(Theme.mu)
            }
        }
        .font(Theme.ui(15)).buttonStyle(.plain).padding(.top, 34)
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
            // entries without a day stamp: in a closed week that is what was written at the review; in the open week, loose thoughts
            Text(today ? "Today" : d ?? (active ? "Thoughts" : "Reflection")).font(Theme.jserif(20)).foregroundStyle(Theme.tx)
            Spacer()
            if let d, let x = dates[d] { Eyebrow(text: (today ? d + " · " : "") + Fmt.date(x), color: Theme.mu2, size: 12) }
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
                if let t = e.t { Text(t).font(Theme.jitalic(13)).foregroundStyle(Theme.mu2) }
                Text(e.x).font(Theme.jserif(18)).lineSpacing(8).foregroundStyle(Theme.tx)
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
                                    Eyebrow(text: b.d.map { "\($0), \(b.t ?? "")" } ?? "Entry", color: Theme.mu2, size: 12)
                                    Text(b.x).font(Theme.serif(17)).lineSpacing(5).foregroundStyle(Theme.mu).lineLimit(3)
                                }
                                .fullWidth().padding(.horizontal, 18).padding(.vertical, 16)
                                Rectangle().fill(Theme.rule).frame(height: 1)
                                Button("Edit") { router.entryMenu = nil; onEdit(i) }
                                    .caps(16).foregroundStyle(Theme.ac).frame(maxWidth: .infinity).frame(height: 58)
                                Rectangle().fill(Theme.rule).frame(height: 1)
                                Button("Delete") { target = i; confirm = true }
                                    .caps(16).foregroundStyle(Theme.danger).frame(maxWidth: .infinity).frame(height: 58)
                            }
                            .background(Theme.card2, in: RoundedRectangle(cornerRadius: Theme.r(18), style: .continuous))
                            Button("Cancel") { router.entryMenu = nil }
                                .caps(16).foregroundStyle(Theme.tx).frame(maxWidth: .infinity).frame(height: 58)
                                .background(Theme.card2, in: RoundedRectangle(cornerRadius: Theme.r(18), style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.r(18), style: .continuous))
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
                .foregroundStyle(Theme.jmu)
                Spacer()
                Button(entry == nil ? "Add" : "Save") { save(); dismiss() }.foregroundStyle(Theme.jac)
            }
            .caps(16).buttonStyle(.plain)
            .frame(height: 52)
            Text(entry == nil ? Fmt.stamp(opened) : (blk?.d.map { "\($0), \(blk?.t ?? "")" } ?? "Edit entry"))
                .font(Theme.jitalic(15)).foregroundStyle(Theme.jmu2).padding(.top, 14)
            Text(w?.focus ?? "").font(Theme.jserif(20)).foregroundStyle(Theme.jtx).padding(.top, 12)
            if entry == nil, !prompts.isEmpty {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(prompts, id: \.self) { q in
                            Text(q).font(Theme.jitalic(14)).foregroundStyle(Theme.jmu2).lineLimit(2)
                                .frame(width: 230, alignment: .leading)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.top, 10)
                .accessibilityLabel("This week's questions")
            }
            TextEditor(text: $text)
                .font(Theme.jserif(19)).lineSpacing(10).foregroundStyle(Theme.jtx)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(.horizontal, -5).padding(.top, 6)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("What is on your heart?").font(Theme.jitalic(19)).foregroundStyle(Theme.jmu2)
                            .padding(.top, 14).allowsHitTesting(false)
                    }
                }
                .onChange(of: text) { _, t in keep(t) }
        }
        .padding(.horizontal, 24)
        .background(Theme.jbg.ignoresSafeArea())
        .onAppear {
            guard !loaded else { return }
            loaded = true; opened = Now.date
            if let blk { text = blk.x } else if let k = draftKey, let t = UserDefaults.standard.string(forKey: k) { text = t }
            focused = true
        }
        .confirmationDialog("Discard this entry?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { keep(""); dismiss() }
            Button("Keep writing", role: .cancel) {}
        }
    }

    /// this week's Saturday questions, shown as optional prompts for a new entry (never written into it)
    private var prompts: [String] { Logic.qsOf(store.activeWeek, store.settings).filter { !$0.isEmpty } }

    /// An unfinished new entry is kept on this phone only (never in Firestore) until it is added or discarded.
    private var draftKey: String? {
        guard entry == nil, !store.isMock, let w = store.activeWeek else { return nil }
        return "entryDraft.\(w.id)"
    }
    private func keep(_ t: String) {
        guard loaded, let k = draftKey else { return }
        if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { UserDefaults.standard.removeObject(forKey: k) }
        else { UserDefaults.standard.set(t, forKey: k) }
    }

    private func save() {
        defer { keep("") }
        guard let w = store.activeWeek else { return }
        if let entry {
            // empty text removes the entry, exactly as the web app does
            if let t = Journal.replaced(w.liveRefl, index: entry, text: text), t != w.liveRefl { store.patchWeek(w, ["liveRefl": t]) }
        } else if let t = Journal.appended(w.liveRefl, at: Now.date, text: text) {
            store.patchWeek(w, ["liveRefl": t])
        }
    }
}
