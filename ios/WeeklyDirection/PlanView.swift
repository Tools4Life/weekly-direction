import SwiftUI

/// Plan the week / Re-plan (web: openPlan … plSeal). The draft autosaves to the `draft` doc. Sealing a new week is the
/// one full week write (`putWeek`); re-planning patches the active week and keeps its checks and marks.
struct PlanView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss
    /// the active week to re-plan, or nil to plan a new week
    let replanId: String?

    @State private var focus = ""
    @State private var verse = ""
    @State private var verseRef = ""
    @State private var thoughts = ""
    @State private var tray: [[String: Any]] = []
    @State private var qs: [String] = []
    @State private var start: Date?
    @State private var first = false
    @State private var replan: String?
    @State private var marks: [String: Any]?
    @State private var saved = ""
    @State private var loaded = false
    /// false while the fields are being filled on open, so opening the plan never writes a draft
    @State private var ready = false
    @State private var sealed = false
    @State private var saveToken = 0
    @State private var chipSheet: ChipEdit?
    @State private var pickQs = false
    @State private var blocked = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { leave() } label: {
                    HStack(spacing: 10) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium)); Text("Later") }
                        .font(Theme.ui(16)).foregroundStyle(Theme.mu)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(saved).font(Theme.label(12)).tracking(1.5).foregroundStyle(Theme.mu2)
            }
            .padding(.horizontal, 24).frame(height: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { form }
                    .fullWidth().padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 50)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear(perform: load)
        .sheet(item: $chipSheet) { e in
            ChipSheet(edit: e, onTray: applyTray, onAdd: addHabit)
                .environmentObject(store)
                .presentationDragIndicator(.visible).presentationCornerRadius(28).presentationBackground(Theme.bg)
        }
        .sheet(isPresented: $pickQs) {
            QuestionPicker(qs: $qs, onChange: saveDraft).environmentObject(store)
                .presentationDragIndicator(.visible).presentationCornerRadius(28).presentationBackground(Theme.bg)
        }
        .alert("A week is already in progress. Close it before sealing a new one.", isPresented: $blocked) { Button("OK", role: .cancel) {} }
    }

    @ViewBuilder private var form: some View {
        Text(replan != nil ? "Re-plan this week" : first ? "Plan your first week" : "Plan the next week")
            .font(Theme.serifItalic(17)).foregroundStyle(Theme.mu)
        Eyebrow(text: "Focus word", color: Theme.mu, size: 12).padding(.top, 20)
        TextField("One word", text: $focus)
            .font(Theme.serif(40)).foregroundStyle(Theme.tx).autocorrectionDisabled()
            .onChange(of: focus) { _, v in
                let t = v.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                if t != v { focus = t } else { saveDraft() }
            }
            .accessibilityIdentifier("planFocus")
        Rectangle().fill(Theme.line).frame(height: 1).padding(.top, 4)
        HStack(spacing: 8) {
            Eyebrow(text: "Focus verse", color: Theme.mu, size: 12)
            Text("OPTIONAL").font(Theme.label(13)).tracking(2.8).italic().foregroundStyle(Theme.mu)
        }
        .padding(.top, 22)
        field { TextField("Reference, e.g. Daniel 1:8", text: $verseRef).font(Theme.ui(16)).onChange(of: verseRef) { _, _ in saveDraft() } }.padding(.top, 10)
        field { TextField("The verse", text: $verse, axis: .vertical).font(Theme.serif(17)).lineSpacing(5).onChange(of: verse) { _, _ in saveDraft() } }.padding(.top, 8)
        if first || replan != nil {
            field {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Week started", color: Theme.mu, size: 12)
                    DatePicker("", selection: Binding(get: { start ?? Now.date }, set: { start = $0; saveDraft() }), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden().tint(Theme.ac)
                }
            }
            .padding(.top, 24)
        }
        HStack {
            let cd = store.settings.closeDay
            Eyebrow(text: "Daily habits · \(Fmt.dowl[(cd + 1) % 7].prefix(3)) – \(Fmt.dowl[cd].prefix(3))", color: Theme.mu, size: 12)
            Spacer()
            Text("\(tray.count)").font(Theme.label(13)).foregroundStyle(Theme.mu)
        }
        .padding(.top, 30)
        trayCard.padding(.top, 10)
        chips.padding(.top, 14)
        HStack {
            Eyebrow(text: "Saturday questions", color: Theme.mu, size: 12)
            Spacer()
            Button("Change") { pickQs = true }.font(Theme.ui(15)).foregroundStyle(Theme.ac)
        }
        .padding(.top, 34)
        ForEach(qs, id: \.self) { q in
            let anchor = q == store.settings.anchorQ
            field(stroke: anchor ? Theme.ac.opacity(0.35) : Theme.line) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(q).font(Theme.serif(17)).lineSpacing(5).foregroundStyle(Theme.tx)
                    if anchor { Eyebrow(text: "Anchor · every week", color: Theme.mu, size: 12) }
                }
            }
            .padding(.top, 8)
        }
        Eyebrow(text: "Vision", color: Theme.mu, size: 12).padding(.top, 34)
        field {
            TextField("What do you want this week to be?", text: $thoughts, axis: .vertical)
                .font(Theme.serif(17)).lineSpacing(6).frame(minHeight: 120, alignment: .topLeading)
                .onChange(of: thoughts) { _, _ in saveDraft() }
        }
        .padding(.top, 10)
        let ok = !focus.isEmpty && !tray.isEmpty
        Button { seal() } label: {
            Text("Seal the week").font(Theme.serif(19)).foregroundStyle(Color(hex: 0x0B0B0C))
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Color(hex: 0xF7F4EF).opacity(ok ? 1 : 0.35), in: RoundedRectangle(cornerRadius: Theme.r(16), style: .continuous))
        }
        .buttonStyle(.plain).disabled(!ok).padding(.top, 34)
        .accessibilityIdentifier("sealWeek")
        if !ok {
            Text(focus.isEmpty && tray.isEmpty ? "Choose a focus word and at least one habit." : focus.isEmpty ? "Choose a focus word." : "Add at least one habit.")
                .font(Theme.ui(13)).foregroundStyle(Theme.mu2).frame(maxWidth: .infinity).padding(.top, 10)
        }
    }

    private func field<V: View>(stroke: Color = Theme.line, @ViewBuilder _ content: () -> V) -> some View {
        content()
            .foregroundStyle(Theme.tx)
            .fullWidth().padding(.horizontal, 15).padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous).stroke(stroke, lineWidth: 1))
    }

    private var trayCard: some View {
        VStack(spacing: 0) {
            if tray.isEmpty { Text("Tap a habit below to add it.").font(Theme.serifItalic(16)).foregroundStyle(Theme.mu2).fullWidth().padding(.vertical, 16) }
            ForEach(Array(tray.enumerated()), id: \.offset) { i, raw in
                if let c = Commitment(raw) {
                    HStack(spacing: 12) {
                        Ico(name: c.icon, size: 17).foregroundStyle(Theme.mu)
                        Text(c.name).font(Theme.ui(16)).foregroundStyle(Theme.tx).lineLimit(1).layoutPriority(1)
                        Spacer(minLength: 6)
                        Text(c.timeLabel()).font(Theme.label(13)).tracking(0.8).foregroundStyle(Theme.mu2).lineLimit(1)
                        Button { tray.remove(at: i); saveDraft() } label: {
                            Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(Theme.mu).frame(width: 34, height: 40)
                        }
                        .buttonStyle(.plain).accessibilityLabel("Remove \(c.name)")
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { chipSheet = ChipEdit(mode: .tray, source: raw) }
                    if i < tray.count - 1 { Rectangle().fill(Theme.rule).frame(height: 1) }
                }
            }
        }
        .padding(.horizontal, 15).padding(.vertical, 6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(16), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.r(16), style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    /// library chips: tap adds, press and hold edits
    private var chips: some View {
        let inTray = Set(tray.compactMap { strOf($0["chipId"]) }), names = Set(tray.compactMap { $0["name"] as? String })
        return Flow(spacing: 8) {
            ForEach(store.library) { ch in
                let used = inTray.contains(ch.id) || names.contains(ch.name)
                chip(icon: Theme.symbol(ch.icon), text: ch.name, serif: true)
                    .opacity(used ? 0.35 : 1)
                    .onTapGesture { if !used { add(chip: ch) } }
                    .onLongPressGesture(minimumDuration: 0.48) { Haptic.tick(); var r = ch.raw; r["id"] = ch.id; chipSheet = ChipEdit(mode: .edit, source: r) }
            }
            chip(icon: "plus", text: "Write your own", serif: false, dashed: true).onTapGesture { chipSheet = ChipEdit(mode: .new, source: [:]) }
        }
    }
    private func chip(icon: String, text: String, serif: Bool, dashed: Bool = false) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 14, weight: .light)).foregroundStyle(Theme.mu)
            Text(text).font(serif ? Theme.serif(17) : Theme.ui(16)).foregroundStyle(dashed ? Theme.mu : Theme.tx)
        }
        .padding(.horizontal, 13).frame(height: 42)
        .background(dashed ? Color.clear : Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(12), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.r(12), style: .continuous).stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : [])))
        .contentShape(Rectangle())
    }

    // MARK: state (web: openPlan)

    private func load() {
        guard !loaded else { return }
        loaded = true
        let s = store.settings, rw = replanId.flatMap { store.week($0) }.flatMap { $0.isActive ? $0 : nil }
        var d: [String: Any]? = (store.draft?["step"] as? String) == "plan" ? store.draft : nil
        if rw == nil, let r = strOf(d?["replan"]), !store.weeks.contains(where: { $0.id == r && $0.isActive }) { d = nil }
        var fresh = false
        if let rw, strOf(d?["replan"]) != rw.id {
            d = ["focus": rw.focus, "verse": rw.verse ?? "", "verseRef": rw.verseRef ?? "", "tray": rw.commitments.map(\.raw),
                 "thoughts": rw.planThoughts, "start": rw.sealedAtMs, "replan": rw.id, "marks": rw.raw["marks"] as? [String: Any] ?? [:]]
            fresh = true
        }
        if d == nil, rw == nil, let carry = store.weeks.filter({ $0.status == "closed" }).max(by: { $0.sealedAtMs < $1.sealedAtMs }) {
            d = ["focus": "", "tray": carry.commitments.map { c -> [String: Any] in var r = c.raw; r["id"] = newUid(); return r }, "thoughts": ""]
            fresh = true
        }
        replan = strOf(d?["replan"])
        first = replan == nil && store.weeks.isEmpty
        focus = d?["focus"] as? String ?? ""
        verse = d?["verse"] as? String ?? ""
        verseRef = d?["verseRef"] as? String ?? ""
        thoughts = d?["thoughts"] as? String ?? ""
        tray = (d?["tray"] as? [[String: Any]] ?? []).map { Self.habit($0, id: strOf($0["id"]) ?? newUid(), chipId: strOf($0["chipId"])) }
        start = msOf(d?["start"]).map { Date(timeIntervalSince1970: $0 / 1000) } ?? (first ? Logic.lastClose(s) : nil)
        marks = d?["marks"] as? [String: Any]
        let latest = store.weeks.max { $0.sealedAtMs < $1.sealedAtMs }
        qs = Logic.normQs((d?["qs"] as? [Any])?.compactMap { $0 as? String } ?? rw?.qs ?? Logic.qsOf(latest, s), s)
        saved = d != nil && !fresh ? "DRAFT RESUMED" : ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { ready = true }
    }

    /// tmg: only the timing fields that are set (weekend time only if different and not weekdays-only)
    static func timing(_ c: [String: Any]) -> [String: Any] {
        var o: [String: Any] = [:]
        let days = c["days"] as? String, by = strOf(c["by"]), byWe = strOf(c["byWe"])
        if days == "wd" || days == "we" { o["days"] = days }
        if let by { o["by"] = by }
        if let by, let byWe, byWe != by, days != "wd" { o["byWe"] = byWe }
        if let m = intOf(c["min"]), m > 0 { o["min"] = m }
        if let a = strOf(c["about"]) { o["about"] = a }
        return o
    }
    /// a week habit: {id, chipId, name, icon, …timing}
    static func habit(_ c: [String: Any], id: String, chipId: String?) -> [String: Any] {
        var o: [String: Any] = ["id": id, "chipId": chipId ?? NSNull() as Any, "name": c["name"] as? String ?? "", "icon": strOf(c["icon"]) ?? "check"]
        o.merge(timing(c)) { $1 }
        return o
    }

    private func draftOf() -> [String: Any] {
        ["step": "plan", "focus": focus, "verse": verse, "verseRef": verseRef, "tray": tray, "thoughts": thoughts, "qs": qs,
         "start": start.map { $0.timeIntervalSince1970 * 1000 as Any } ?? NSNull(), "replan": replan ?? NSNull() as Any,
         "marks": marks ?? NSNull() as Any, "updatedAt": Now.ms]
    }
    private func saveDraft() {
        guard ready, !sealed else { return }
        saveToken += 1
        let token = saveToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard token == saveToken, !sealed else { return }
            store.putDraft(draftOf())
            saved = "DRAFT SAVED"
        }
    }
    private func leave() {
        saveToken += 1
        if !sealed, !focus.isEmpty || !tray.isEmpty || !thoughts.isEmpty { store.putDraft(draftOf()) }
        dismiss()
    }

    private func add(chip ch: Chip) {
        guard !tray.contains(where: { strOf($0["chipId"]) == ch.id }) else { return }
        Haptic.tick()
        tray.append(Self.habit(ch.raw, id: newUid(), chipId: ch.id))
        saveDraft()
    }
    private func applyTray(_ id: String, _ fields: [String: Any]) {
        guard let i = tray.firstIndex(where: { $0["id"] as? String == id }) else { return }
        var rest = tray[i]
        for k in ["by", "byWe", "min", "about", "days"] { rest[k] = nil }
        rest["name"] = fields["name"]; rest["icon"] = fields["icon"]
        rest.merge(Self.timing(fields)) { $1 }
        tray[i] = rest
        saveDraft()
    }
    private func addHabit(_ h: [String: Any]) { tray.append(h); saveDraft() }

    // MARK: seal (web: plSeal)

    private func seal() {
        guard !focus.isEmpty, !tray.isEmpty, !sealed else { return }
        let old = replan.flatMap { store.week($0) }
        if replan != nil && old?.isActive != true { blocked = true; return }      // the week it re-plans is gone or closed
        if replan == nil && store.activeWeek != nil { blocked = true; return }    // never a second active week
        let now = Now.ms
        let sealedAt = (first || replan != nil) ? (start.map { $0.timeIntervalSince1970 * 1000 } ?? now) : now
        var id = replan ?? Rules.ymd(Date(timeIntervalSince1970: sealedAt / 1000))
        if replan == nil, store.weeks.contains(where: { $0.id == id }) { id += "-" + String(newUid().suffix(4)) }
        let week: [String: Any] = [
            "status": "active", "focus": focus,
            "verse": verse.trimmingCharacters(in: .whitespacesAndNewlines), "verseRef": verseRef.trimmingCharacters(in: .whitespacesAndNewlines),
            "sealedAt": sealedAt, "closedAt": NSNull(),
            "commitments": tray.map { Self.habit($0, id: $0["id"] as? String ?? newUid(), chipId: strOf($0["chipId"])) },
            "percentage": NSNull(), "reflection": "",
            "planThoughts": thoughts.trimmingCharacters(in: .whitespacesAndNewlines), "qs": Logic.normQs(qs, store.settings),
            "editedAt": NSNull(), "createdAt": old.flatMap { msOf($0.raw["createdAt"]) } ?? now,
            "marks": marks ?? [:], "replannedAt": old != nil ? now as Any : NSNull()
        ]
        sealed = true
        saveToken += 1
        if let old { store.patchWeek(old, week) } else { store.putWeek(id: id, week) }
        store.delDraft()
        Haptic.success()
        router.selK = nil
        router.tab = "week"
        router.cover = nil
        dismiss()
    }
}

/// which habit the sheet edits: a new one, a library habit, or one of this plan's habits
struct ChipEdit: Identifiable {
    enum Mode { case new, edit, tray }
    let mode: Mode
    let source: [String: Any]
    let id = UUID()
}

/// habit sheet: write your own / edit (web: openChipSheet)
struct ChipSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let edit: ChipEdit
    let onTray: (String, [String: Any]) -> Void
    let onAdd: ([String: Any]) -> Void
    @State private var name = ""
    @State private var icon = "sun"
    @State private var days = ""
    @State private var by: Date?
    @State private var byWe: Date?
    @State private var minutes = ""
    @State private var about = ""
    @State private var needName = false
    @State private var confirmRemove = false
    @FocusState private var nameFocus: Bool

    static let icons = ["sun", "hands", "book", "bookmark", "scroll", "pen", "brain", "cross", "church", "flame", "moon", "sunfull", "heart", "handheart",
                        "music", "leaf", "drop", "eye", "phone", "cup", "walk", "clock", "home", "bed", "users", "briefcase", "hardhat", "hammer", "wrench",
                        "laptop", "clipboard", "calendar", "list", "mail", "target", "chart", "money", "bulb", "handshake", "car", "timer", "check"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(edit.mode == .edit ? "Edit habit" : edit.mode == .tray ? "This week’s habit" : "New habit").font(Theme.serif(24)).foregroundStyle(Theme.tx)
                TextField("Habit name", text: $name).font(Theme.ui(17)).foregroundStyle(Theme.tx).focused($nameFocus)
                    .padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous).stroke(needName ? Theme.ac : Theme.line, lineWidth: 1))
                    .onChange(of: name) { _, _ in needName = false }
                    .padding(.top, 16)
                Eyebrow(text: "Days", color: Theme.mu, size: 12).padding(.top, 22)
                HStack(spacing: 8) {
                    ForEach([("", "Every day"), ("wd", "Weekdays"), ("we", "Weekends")], id: \.0) { d in
                        Button(d.1) { days = d.0 }
                            .font(Theme.ui(15)).foregroundStyle(days == d.0 ? Color(hex: 0x0B0B0C) : Theme.tx)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(days == d.0 ? Color(hex: 0xF7F4EF) : Color.clear, in: RoundedRectangle(cornerRadius: Theme.r(12), style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.r(12), style: .continuous).stroke(Theme.line, lineWidth: 1))
                    }
                }
                .buttonStyle(.plain).padding(.top, 8)
                timeRow("Start by", $by).padding(.top, 20)
                if days != "wd" { timeRow("Weekends", $byWe).padding(.top, 10) }
                HStack {
                    Text("Minutes (timed habit)").font(Theme.ui(16)).foregroundStyle(Theme.tx)
                    Spacer()
                    TextField("0", text: $minutes).keyboardType(.numberPad).multilineTextAlignment(.trailing).font(Theme.ui(16)).foregroundStyle(Theme.tx).frame(width: 70)
                }
                .padding(.top, 14)
                Eyebrow(text: "About", color: Theme.mu, size: 12).padding(.top, 22)
                TextField("Why it matters, and the verse behind it", text: $about, axis: .vertical)
                    .font(Theme.serif(17)).lineSpacing(5).foregroundStyle(Theme.tx).frame(minHeight: 70, alignment: .topLeading)
                    .padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous).stroke(Theme.line, lineWidth: 1)).padding(.top, 8)
                Eyebrow(text: "Icon", color: Theme.mu, size: 12).padding(.top, 22)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(Self.icons, id: \.self) { n in
                        Button { icon = n } label: {
                            Ico(name: n, size: 18).foregroundStyle(icon == n ? Theme.onAc : Theme.mu).frame(maxWidth: .infinity).frame(height: 42)
                                .background(icon == n ? Theme.ac : Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(10), style: .continuous))
                        }
                        .buttonStyle(.plain).accessibilityLabel(n)
                    }
                }
                .padding(.top, 8)
                actions.padding(.top, 26)
            }
            .fullWidth().padding(.horizontal, 20).padding(.top, 34).padding(.bottom, 30)
        }
        .background(Theme.bg)
        .onAppear {
            let s = edit.source
            name = s["name"] as? String ?? ""; icon = strOf(s["icon"]) ?? "sun"; days = s["days"] as? String ?? ""
            by = strOf(s["by"]).flatMap(Self.time); byWe = strOf(s["byWe"]).flatMap(Self.time)
            minutes = intOf(s["min"]).map(String.init) ?? ""; about = s["about"] as? String ?? ""
            if edit.mode != .edit { nameFocus = true }
        }
        .confirmationDialog("Remove “\(name)” from your library? Past weeks keep their own copy.", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { if let id = edit.source["id"] as? String { store.delChip(id) }; dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private static func time(_ hm: String) -> Date? { Rules.localDate("2026-01-01", hm) }
    private static func hm(_ d: Date) -> String {
        let c = Rules.cal.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }

    private func timeRow(_ label: String, _ t: Binding<Date?>) -> some View {
        HStack {
            Text(label).font(Theme.ui(16)).foregroundStyle(Theme.tx)
            Spacer()
            if let v = t.wrappedValue {
                DatePicker("", selection: Binding(get: { v }, set: { t.wrappedValue = $0 }), displayedComponents: .hourAndMinute).labelsHidden().tint(Theme.ac)
                Button { t.wrappedValue = nil } label: { Image(systemName: "xmark.circle").foregroundStyle(Theme.mu) }.buttonStyle(.plain).accessibilityLabel("Clear \(label)")
            } else {
                Button("Set a time") { t.wrappedValue = Self.time("07:00") }.font(Theme.ui(15)).foregroundStyle(Theme.ac)
            }
        }
        .frame(minHeight: 36)
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: 12) {
            switch edit.mode {
            case .tray: primary("Save for this week") { save("tray") }
            case .edit:
                primary("Save") { save("save") }
                Button("Remove from library") { confirmRemove = true }.font(Theme.ui(15)).foregroundStyle(Theme.danger)
            case .new:
                primary("Save to library and add") { save("lib") }
                Button("This week only") { save("week") }.font(Theme.ui(16)).foregroundStyle(Theme.tx).frame(maxWidth: .infinity).frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }
    private func primary(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(Theme.ui(16, .semibold)).foregroundStyle(Color(hex: 0x0B0B0C)).frame(maxWidth: .infinity).frame(height: 50)
                .background(Color(hex: 0xF7F4EF), in: RoundedRectangle(cornerRadius: Theme.r(14), style: .continuous))
        }
    }

    private func save(_ a: String) {
        let nm = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nm.isEmpty else { needName = true; nameFocus = true; return }
        let d: String? = days.isEmpty ? nil : days
        let ab = about.trimmingCharacters(in: .whitespacesAndNewlines)
        let byS = by.map(Self.hm), weS = byWe.map(Self.hm)
        let we: String? = byS != nil && d != "wd" && weS != nil && weS != byS ? weS : nil
        let mn = max(0, min(240, Int(minutes) ?? 0))
        // every field, null when unset (what the web writes when it saves a library habit)
        let full: [String: Any] = ["name": nm, "icon": icon, "by": byS ?? NSNull() as Any, "byWe": we ?? NSNull() as Any,
                                   "min": mn > 0 ? mn as Any : NSNull(), "about": ab.isEmpty ? NSNull() as Any : ab, "days": d ?? NSNull() as Any]
        switch a {
        case "tray":
            if let id = edit.source["id"] as? String { onTray(id, full) }
        case "save":
            guard let id = edit.source["id"] as? String else { break }
            var doc = store.library.first { $0.id == id }?.raw ?? [:]
            doc["id"] = nil
            doc.merge(full) { $1 }
            store.putChip(id: id, doc)
        default:
            let chipId = newUid()
            if a == "lib" {
                var doc: [String: Any] = ["name": nm, "icon": icon, "order": (store.library.map(\.order).max() ?? -1) + 1]
                doc.merge(PlanView.timing(full)) { $1 }
                store.putChip(id: chipId, doc)
            }
            onAdd(PlanView.habit(full, id: newUid(), chipId: a == "lib" ? chipId : nil))
        }
        dismiss()
    }
}

/// pick two questions from the library; the anchor is always included (web: renderQsSheet)
struct QuestionPicker: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @Binding var qs: [String]
    let onChange: () -> Void

    var body: some View {
        let a = store.settings.anchorQ, picked = qs.filter { $0 != a }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Pick two questions · \(picked.count)/2").font(Theme.serif(20)).foregroundStyle(Theme.tx)
                    Spacer()
                    Button("Done") { dismiss() }.font(Theme.ui(16, .semibold)).foregroundStyle(Theme.ac)
                }
                Eyebrow(text: "Anchor · every week", color: Theme.mu, size: 12).padding(.top, 18)
                Text(a).font(Theme.serif(17)).foregroundStyle(Theme.tx).padding(.top, 6)
                ForEach(Logic.libGroups(store.settings), id: \.title) { g in
                    Eyebrow(text: g.title, color: Theme.mu, size: 12).padding(.top, 24).padding(.bottom, 4)
                    ForEach(g.qs.filter { $0 != a }, id: \.self) { q in
                        let on = picked.contains(q)
                        Button {
                            if on { qs = [a] + picked.filter { $0 != q } } else if picked.count < 2 { qs = [a] + picked + [q] } else { return }
                            Haptic.tick(); onChange()
                        } label: {
                            Text(q).font(Theme.serif(17)).lineSpacing(4).foregroundStyle(Theme.tx).multilineTextAlignment(.leading)
                                .fullWidth().padding(13)
                                .background(on ? Theme.acSoft : Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(12), style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Theme.r(12), style: .continuous).stroke(on ? Theme.ac : Theme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain).padding(.top, 8)
                    }
                }
            }
            .fullWidth().padding(.horizontal, 20).padding(.top, 34).padding(.bottom, 30)
        }
        .background(Theme.bg)
    }
}

/// wrapping row layout for the habit chips
struct Flow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > 0, x + z.width > w { x = 0; y += row + spacing; row = 0 }
            x += z.width + spacing; row = max(row, z.height)
        }
        return CGSize(width: w == .infinity ? x : w, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + z.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; row = max(row, z.height)
        }
    }
}
