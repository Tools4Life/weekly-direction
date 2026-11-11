import SwiftUI

/// Reflect → Prayer (web: renderPrayer): the pinned life prayer on top, then the list.
struct PrayerList: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var recorder: Recorder
    @State private var deleting: PrayerEntry?

    var body: some View {
        let life = store.prayers.first { $0.pinned }, rest = store.prayers.filter { !$0.pinned }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: "Your prayers", color: Theme.mu, size: 12)
                    Spacer()
                    Button { router.sheet = .prayer(nil, pinned: false) } label: {
                        HStack(spacing: 8) { Image(systemName: "plus").font(.system(size: 15)); Text("New").caps(16) }.foregroundStyle(Theme.ac)
                    }
                    .buttonStyle(.plain)
                }
                Button { router.sheet = .prayer(life?.id, pinned: true) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Life prayer", color: Theme.mu, size: 12)
                        Text(life?.text ?? "Add the prayer that covers your whole life")
                            .font(life == nil ? Theme.serifItalic(19) : Theme.serif(19)).foregroundStyle(life == nil ? Theme.mu : Theme.tx)
                            .multilineTextAlignment(.leading)
                    }
                    .fullWidth().padding(.horizontal, 19).padding(.vertical, 18)
                    .background(life == nil ? Color.clear : Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(20), style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r(20), style: .continuous)
                        .stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: life == nil ? [4, 4] : [])))
                }
                .buttonStyle(.plain).padding(.top, 18).padding(.bottom, 12).rise(0)
                if rest.isEmpty {
                    Text("What else are you praying for? Tap New to name it, then go as deep as you want.")
                        .font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2).padding(.top, 14)
                }
                ForEach(Array(rest.enumerated()), id: \.element.id) { n, p in
                    Button { router.half = p.body.isEmpty; router.sheet = .prayer(p.id, pinned: false) } label: {
                        HStack(spacing: 12) {
                            Ico(name: p.icon ?? "hands", size: 18).foregroundStyle(Theme.mu).opacity(p.icon == nil ? 0.5 : 1)
                            Text(p.text).font(Theme.serif(18)).foregroundStyle(Theme.tx).multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).rise(1 + n)
                    Rectangle().fill(Theme.rule).frame(height: 1)
                }
                log
            }
            .fullWidth().padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .alert("Delete this prayer from the log? This can’t be undone.", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) { if let d = deleting { store.delPrayerLog(d.id) }; deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        }
    }

    /// Prayers spoken out loud (Eddie, Nov 11 2026): on this tab the mic records a prayer, and it lands here, newest
    /// first, under its day. Press and hold one to delete it.
    @ViewBuilder private var log: some View {
        Eyebrow(text: "Prayer log", color: Theme.mu, size: 12).padding(.top, 40)
        RecorderStatus().padding(.top, 8)
        // recordings still on the phone hold their place until they are written down
        ForEach(recorder.waitingPrayers.reversed()) { p in
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Fmt.clock(p.at)) · \(recorder.sending ? "writing it down" : "waiting to send")").font(Theme.serifItalic(13)).foregroundStyle(Theme.ac)
                Text(p.text ?? "Spoken prayer, \(Fmt.mmss(Double(p.seconds)))").font(Theme.serif(17)).lineSpacing(6).foregroundStyle(Theme.mu)
            }
            .fullWidth().padding(.top, 18)
        }
        if store.prayerLog.isEmpty, recorder.waitingPrayers.isEmpty {
            Text("Tap the button below and pray out loud. It is written down here.")
                .font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2).padding(.top, 14)
        }
        ForEach(days, id: \.0) { day, entries in
            HStack(alignment: .firstTextBaseline) {
                Text(day == Rules.ymd(Now.date) ? "Today" : Fmt.dowl[Rules.weekday(entries[0].date)]).font(Theme.serif(20)).foregroundStyle(Theme.tx)
                Spacer()
                Eyebrow(text: Fmt.date(entries[0].date), color: Theme.mu2, size: 12)
            }
            .padding(.top, 30)
            ForEach(entries) { e in
                VStack(alignment: .leading, spacing: 6) {
                    Text(Fmt.clock(e.date)).font(Theme.serifItalic(13)).foregroundStyle(Theme.mu2)
                    Text(e.read).font(Theme.serif(18)).lineSpacing(7).foregroundStyle(Theme.tx)
                }
                .fullWidth().padding(.top, 16)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.5) { Haptic.tick(); deleting = e }
            }
        }
    }

    /// the log by day, newest day first, newest prayer first within a day
    private var days: [(String, [PrayerEntry])] {
        var out: [(String, [PrayerEntry])] = []
        for e in store.prayerLog {
            let k = Rules.ymd(e.date)
            if out.last?.0 == k { out[out.count - 1].1.append(e) } else { out.append((k, [e])) }
        }
        return out
    }
}

/// One prayer (web: openPrayer / savePrayer): opens read-only, Edit switches to the editor, and it saves itself when
/// the sheet closes. A new prayer opens straight in the editor.
struct PrayerSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let prayerId: String?
    let pinned: Bool
    @State private var editing = false
    @State private var title = ""
    @State private var bodyText = ""
    @State private var icon: String?
    @State private var newId = newUid()
    @State private var created = Now.ms
    @State private var loaded = false
    @State private var removed = false
    @State private var confirmRemove = false
    @State private var confirmRevise = false
    @FocusState private var focus: Field?
    enum Field { case title, body }

    static let icons: [(String, String)] = [("compass", "Direction"), ("family", "Family"), ("heart", "Relationships"), ("work", "Work"),
                                            ("church", "Church"), ("health", "Health"), ("money", "Provision"), ("self", "Myself"), ("world", "Others")]

    private var existing: Prayer? { prayerId.flatMap { id in store.prayers.first { $0.id == id } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: existing.map { Fmt.date(Date(timeIntervalSince1970: $0.created / 1000)) } ?? "New prayer", color: Theme.mu2, size: 12)
                    Spacer()
                    if !editing {
                        Button("Edit") { if pinned { confirmRevise = true } else { startEdit() } }.caps(16).foregroundStyle(Theme.mu).padding(.trailing, 22)
                    }
                    Button("Done") { router.sheet = nil }.caps(16).foregroundStyle(Theme.ac)
                }
                if editing { editor } else { reader }
            }
            .fullWidth().padding(.horizontal, 20).padding(.top, 34).padding(.bottom, 30)
        }
        .background(Theme.bg)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let p = existing { title = p.text; bodyText = p.body; icon = p.icon } else { editing = true; focus = .title }
        }
        .onDisappear(perform: save)
        .confirmationDialog("Revise your life prayer?", isPresented: $confirmRevise, titleVisibility: .visible) {
            Button("Revise") { startEdit() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Remove this prayer from your list?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let p = existing { removed = true; store.delPrayer(p.id); router.sheet = nil }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func startEdit() { router.detent = .large; editing = true; focus = .body }

    private var reader: some View {
        let paras = bodyText.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 18) {
            Text(title).font(Theme.serif(24)).foregroundStyle(Theme.tx)
            ForEach(Array(paras.enumerated()), id: \.offset) { _, p in
                Text(p).font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx)
            }
            if pinned, !paras.isEmpty { Eyebrow(text: "Amen", color: Theme.mu2, size: 12).frame(maxWidth: .infinity).padding(.top, 10) }
            // only a name so far: one tap to write under it
            if paras.isEmpty, !pinned {
                Button { startEdit() } label: {
                    Text("Add to this prayer").font(Theme.serifItalic(18)).foregroundStyle(Theme.mu2).fullWidth().contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("What are you praying for?", text: $title, axis: .vertical)
                .font(Theme.serif(24)).foregroundStyle(Theme.tx).focused($focus, equals: .title)
                .submitLabel(.next).onSubmit { focus = .body }
            if !pinned {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.icons, id: \.0) { t in
                            Button { icon = icon == t.0 ? nil : t.0 } label: {
                                HStack(spacing: 6) { Ico(name: t.0, size: 15); Text(t.1).font(Theme.ui(14)) }
                                    .foregroundStyle(icon == t.0 ? Theme.onAc : Theme.mu)
                                    .padding(.leading, 6).padding(.trailing, 12).frame(height: 36)
                                    .background(icon == t.0 ? Theme.ac : Theme.card, in: Theme.pill)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            TextEditor(text: $bodyText)
                .font(Theme.serif(18)).lineSpacing(6).foregroundStyle(Theme.tx).scrollContentBackground(.hidden)
                .frame(minHeight: 260).padding(.horizontal, -5).focused($focus, equals: .body)
                .overlay(alignment: .topLeading) {
                    if bodyText.isEmpty { Text("Go as deep as you want.").font(Theme.serifItalic(18)).foregroundStyle(Theme.mu2).padding(.top, 8).allowsHitTesting(false) }
                }
            if existing != nil, !pinned {
                Button("Remove from list") { confirmRemove = true }.caps(15).foregroundStyle(Theme.danger).frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 20)
    }

    /// savePrayer: writes only when something changed; an edited prayer that already had a body gets `edited`
    private func save() {
        guard loaded, !removed else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let bd = bodyText.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        if t.isEmpty && bd.isEmpty { return }
        let first = bd.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").first ?? ""
        let text = t.isEmpty ? String(first.prefix(60)) : t
        var fields: [String: Any]
        let id: String
        if let p = existing {
            guard text != p.text || bd != p.body || icon != p.icon else { return }
            fields = p.raw; fields["id"] = nil; id = p.id
            if !p.body.isEmpty { fields["edited"] = Now.ms }
        } else if pinned {
            id = "life"; fields = ["pinned": true, "created": created, "since": created]
        } else {
            id = newId; fields = ["created": created]
        }
        fields["text"] = text
        fields["body"] = bd
        fields["icon"] = icon ?? NSNull() as Any
        store.putPrayer(id: id, fields)
    }
}
