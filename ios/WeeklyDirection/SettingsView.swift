import SwiftUI

/// Settings (web: renderSettings). Reworked Nov 10 2026 (Eddie): the first page is short rows you can take in at a
/// glance; Saturday questions and the caffeine wean each have their own page. The settings written are the web's.
/// Editing the open week moved to the page the focus word opens (VisionView).
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var notifier: Notifier
    @Environment(\.dismiss) private var dismiss
    enum Page { case main, questions, caffeine }
    struct QItem: Identifiable { let id = UUID(); var text: String }
    struct QGroup: Identifiable { let id = UUID(); var name: String; var qs: [QItem] }
    struct PlanRef: Identifiable { let id: String }
    @State private var page: Page = .main
    @State private var anchor = ""
    @State private var groups: [QGroup] = []
    /// the library as it was when the page loaded, in the form this page writes: no write unless something was edited
    @State private var baseline = ""
    @State private var cafStart = ""
    @State private var cafStep = ""
    @State private var cafDays = ""
    @State private var loaded = false
    @State private var exportURL: URL?
    @State private var confirmSignOut = false
    @FocusState private var focus: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { if page == .main { commit(); dismiss() } else { focus = nil; commit(); withAnimation(.easeOut(duration: 0.18)) { page = .main } } } label: {
                    HStack(spacing: 10) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium)); Text(page == .main ? "This week" : "Settings") }
                        .caps(16).foregroundStyle(Theme.mu)
                }
                .buttonStyle(.plain)
                Spacer()
                if focus != nil { Button("Done") { focus = nil }.caps(16).foregroundStyle(Theme.ac) }
            }
            .padding(.horizontal, 24).frame(height: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch page {
                    case .main: main
                    case .questions: questions
                    case .caffeine: caffeine
                    }
                }
                .fullWidth().padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 50)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            guard !loaded else { return }
            loaded = true
            anchor = store.settings.anchorQ
            groups = Self.parse(store.settings.qLib); baseline = Self.text(groups)
            loadCaf()
            notifier.refresh()
            if let p = router.settingsPage { page = p == "questions" ? .questions : p == "caffeine" ? .caffeine : .main; router.settingsPage = nil }
        }
        .onDisappear(perform: commit)
        .onChange(of: focus) { old, _ in if old != nil { commit() } }
        .sheet(item: $exportURL) { url in ShareSheet(items: [url]) }
        .confirmationDialog("Sign out on this device?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { router.cover = nil; store.signOut() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: first page

    @ViewBuilder private var main: some View {
        let s = store.settings
        Text("Settings").title(34).foregroundStyle(Theme.tx).padding(.bottom, 22)
        group {
            HStack {
                Text("Appearance").caps(16).foregroundStyle(Theme.tx)
                Spacer()
                Seg(options: [("dark", "Dark"), ("light", "Light"), ("auto", "Auto")],
                    value: Binding(get: { store.settings.theme }, set: { store.setSettings(["theme": $0]) }))
            }
            .padding(.horizontal, 16).frame(minHeight: 54)
            divider
            toggle("Sounds", nil, Binding(get: { store.settings.sounds }, set: { on in
                store.setSettings(["sounds": on])
                if on { var s = store.settings.raw; s["sounds"] = true; Sound.play(.done, Settings(s)) }
            }))
            divider
            // the note is only worth the space when reminders are off or blocked
            toggle("Reminders", notifier.on ? nil : notifier.note, Binding(get: { notifier.on }, set: { want in Task { await notifier.set(want, store: store) } }))
        }
        group {
            Button { go(.questions) } label: {
                let n = Logic.libGroups(s).reduce(0) { $0 + $1.qs.count }
                line("Saturday questions", value: "\(n) in library", chevron: true)
            }
            .buttonStyle(.plain)
            divider
            Button { go(.caffeine) } label: {
                let mg = Logic.cafLimit(s, Now.date)
                line("Caffeine wean", value: !s.cafOn ? "Off" : mg > 0 ? "\(mg) mg today" : "Caffeine-free", chevron: true)
            }
            .buttonStyle(.plain)
        }
        if store.practice || !store.isMock {
            group {
                Button {
                    Haptic.tick()
                    if store.practice { store.exitPractice() } else { store.enterPractice() }
                    dismiss()
                } label: { line(store.practice ? "Leave practice mode" : "Practice mode", value: store.practice ? nil : "Sample week", chevron: !store.practice) }
                .buttonStyle(.plain)
            }
        }
        group {
            Button { exportURL = export() } label: { line("Export my data", value: nil, chevron: true) }.buttonStyle(.plain)
            divider
            Button { confirmSignOut = true } label: { line("Sign out", value: nil, chevron: false) }.buttonStyle(.plain)
        }
        Text("\(store.email ?? "Not signed in") · \(store.practice ? "practice mode, nothing is saved" : store.isMock ? "preview data" : "synced to your account")")
            .font(Theme.ui(14)).foregroundStyle(Theme.mu2).padding(.top, 14).padding(.horizontal, 4)
    }

    private func go(_ p: Page) { Haptic.tick(); withAnimation(.easeOut(duration: 0.18)) { page = p } }

    // MARK: Saturday questions

    @ViewBuilder private var questions: some View {
        Text("Saturday questions").title(30).foregroundStyle(Theme.tx)
        label("Anchor · every week")
        group {
            TextField("Anchor question", text: $anchor, axis: .vertical)
                .font(Theme.serif(18)).lineSpacing(4).foregroundStyle(Theme.tx).focused($focus, equals: "anchor").padding(16)
        }
        ForEach($groups) { $g in
            HStack {
                TextField("Group name", text: $g.name)
                    .font(Theme.label(12)).tracking(2.4).textCase(.uppercase).foregroundStyle(Theme.mu).focused($focus, equals: "g" + g.id.uuidString)
                Spacer()
                Text("\(g.qs.count)").font(Theme.label(12)).foregroundStyle(Theme.mu2)
            }
            .padding(.top, 30).padding(.bottom, 10)
            group {
                ForEach($g.qs) { $q in
                    HStack(alignment: .top, spacing: 10) {
                        TextField("Question", text: $q.text, axis: .vertical)
                            .font(Theme.serif(17)).lineSpacing(4).foregroundStyle(Theme.tx).focused($focus, equals: q.id.uuidString)
                        Button { remove(q.id, from: g.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.mu2).frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain).accessibilityLabel("Remove question")
                    }
                    .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 12)
                    divider
                }
                Button { add(to: g.id) } label: {
                    HStack(spacing: 8) { Image(systemName: "plus").font(.system(size: 13)); Text("Add question").caps(15) }
                        .foregroundStyle(Theme.ac).fullWidth().padding(16).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        Button {
            let g = QGroup(name: "", qs: [QItem(text: "")]); groups.append(g); focus = "g" + g.id.uuidString
        } label: {
            HStack(spacing: 8) { Image(systemName: "plus").font(.system(size: 13)); Text("New group").caps(15) }.foregroundStyle(Theme.mu)
        }
        .buttonStyle(.plain).padding(.top, 26)
    }

    private func add(to gid: UUID) {
        guard let i = groups.firstIndex(where: { $0.id == gid }) else { return }
        let q = QItem(text: ""); groups[i].qs.append(q); focus = q.id.uuidString
    }
    private func remove(_ qid: UUID, from gid: UUID) {
        focus = nil
        // after the keyboard lets go of the row, so the field being removed is not still bound
        DispatchQueue.main.async {
            guard let i = groups.firstIndex(where: { $0.id == gid }) else { return }
            groups[i].qs.removeAll { $0.id == qid }
            if groups[i].qs.isEmpty { groups.remove(at: i) }
            commit()
        }
    }

    /// the library text: one question per line, `# Name` starts a group (the web's format)
    static func parse(_ t: String) -> [QGroup] {
        var out: [QGroup] = []
        for l in t.components(separatedBy: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) where !l.isEmpty {
            if l.hasPrefix("#") { out.append(QGroup(name: l.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression), qs: [])) }
            else { if out.isEmpty { out.append(QGroup(name: "", qs: [])) }; out[out.count - 1].qs.append(QItem(text: l)) }
        }
        return out
    }
    static func text(_ gs: [QGroup]) -> String {
        var lines: [String] = []
        for g in gs {
            let qs = g.qs.map { $0.text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let name = g.name.trimmingCharacters(in: .whitespaces)
            if qs.isEmpty { continue }
            if !name.isEmpty || !lines.isEmpty { lines.append("# " + (name.isEmpty ? "Questions" : name)) }
            lines += qs
        }
        return lines.joined(separator: "\n")
    }

    // MARK: caffeine wean

    @ViewBuilder private var caffeine: some View {
        let s = store.settings
        Text("Caffeine wean").title(30).foregroundStyle(Theme.tx).padding(.bottom, 22)
        group {
            toggle("Track caffeine wean", nil, Binding(get: { store.settings.cafOn }, set: { on in
                Haptic.tick()
                var v: [String: Any] = ["cafOn": on]
                if on, store.settings.cafFrom == nil { v["cafFrom"] = Logic.midnight(Now.date).timeIntervalSince1970 * 1000 }
                store.setSettings(v)
            }))
        }
        if s.cafOn {
            let plan = Logic.cafPlan(s), from = Logic.cafFromDate(s), today = Logic.dayDiff(from, Now.date)
            let total = plan.reduce(0) { $0 + $1.len }, mg = Logic.cafLimit(s, Now.date), sp = Logic.cafSplit(s, mg)
            label("Today")
            if mg > 0 {
                Text("\(mg) mg").font(Theme.num(30)).foregroundStyle(Theme.tx)
                Text("Morning \(sp.am) mg · afternoon \(sp.pm) mg").font(Theme.ui(15)).foregroundStyle(Theme.mu).padding(.top, 2)
            } else {
                // a finished plan shows no doses on This Week: say so, and offer the way back in
                Text("Caffeine-free").font(Theme.num(26)).foregroundStyle(Theme.tx)
                Text("This plan reached zero on \(Fmt.date(Rules.cal.date(byAdding: .day, value: total, to: from) ?? from)), so This Week shows no doses.")
                    .font(Theme.ui(15)).foregroundStyle(Theme.mu).padding(.top, 2)
                Button("Start a new wean today") {
                    Haptic.tick(); store.setSettings(["cafFrom": Logic.midnight(Now.date).timeIntervalSince1970 * 1000])
                }
                .caps(16).foregroundStyle(Theme.ac).padding(.top, 14)
            }
            label("Plan")
            group {
                number("Starting limit", "mg", $cafStart, "cafStart")
                divider
                number("Drop by", "mg", $cafStep, "cafStep")
                divider
                number("Reach 0 in", "days", $cafDays, "cafDays")
                divider
                DatePicker(selection: Binding(get: { Logic.cafFromDate(store.settings) },
                                              set: { store.setSettings(["cafFrom": Logic.midnight($0).timeIntervalSince1970 * 1000]) }),
                           displayedComponents: .date) { Text("Started").caps(16).foregroundStyle(Theme.tx) }
                    .tint(Theme.ac).padding(.horizontal, 16).frame(minHeight: 54)
            }
            label("Steps")
            group {
                ForEach(Array(plan.enumerated()), id: \.offset) { _, l in
                    let a = Rules.cal.date(byAdding: .day, value: l.from, to: from) ?? from
                    let b = Rules.cal.date(byAdding: .day, value: l.from + l.len - 1, to: from) ?? from
                    let cur = today >= l.from && today < l.from + l.len, past = today >= l.from + l.len, x = Logic.cafSplit(s, l.mg)
                    step("\(x.am) / \(x.pm)", l.len > 1 ? "\(Fmt.date(a)) – \(Fmt.date(b))" : Fmt.date(a), "\(l.len) \(l.len == 1 ? "day" : "days")", cur: cur, past: past)
                    divider
                }
                step("0 mg", "from \(Fmt.date(Rules.cal.date(byAdding: .day, value: total, to: from) ?? from))", "", cur: mg == 0, past: false)
            }
        }
    }

    private func step(_ a: String, _ b: String, _ c: String, cur: Bool, past: Bool) -> some View {
        HStack(spacing: 12) {
            Text(a).font(Theme.num(16)).foregroundStyle(cur ? Theme.ac : past ? Theme.mu2 : Theme.tx).frame(width: 92, alignment: .leading)
            Text(b).font(Theme.ui(15)).foregroundStyle(past ? Theme.mu2 : Theme.mu)
            Spacer()
            Text(cur ? "now" : c).font(Theme.label(13)).tracking(1.2).foregroundStyle(cur ? Theme.ac : Theme.mu2)
        }
        .padding(.horizontal, 16).frame(minHeight: 46)
    }

    private func number(_ t: String, _ unit: String, _ v: Binding<String>, _ key: String) -> some View {
        HStack(spacing: 8) {
            Text(t).caps(16).foregroundStyle(Theme.tx)
            Spacer()
            TextField("0", text: v).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .font(Theme.num(17)).foregroundStyle(Theme.tx).frame(width: 70).focused($focus, equals: key)
            Text(unit).font(Theme.ui(15)).foregroundStyle(Theme.mu).frame(width: 36, alignment: .leading)
        }
        .padding(.horizontal, 16).frame(minHeight: 54)
    }

    private func loadCaf() {
        let s = store.settings
        cafStart = "\(s.cafStart)"; cafStep = "\(s.cafStep)"; cafDays = "\(s.cafDays)"
    }

    // MARK: pieces

    private func label(_ t: String) -> some View { Eyebrow(text: t, color: Theme.mu, size: 12).padding(.top, 30).padding(.bottom, 10) }
    private var divider: some View { Rectangle().fill(Theme.rule).frame(height: 1).padding(.leading, 16) }
    private func group<V: View>(@ViewBuilder _ c: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 0) { c() }.fullWidth().card(18).padding(.bottom, 12)
    }
    /// one settings row: a name, what it is set to, and a chevron when it opens something
    private func line(_ t: String, value: String?, chevron: Bool) -> some View {
        HStack(spacing: 10) {
            Text(t).caps(16).foregroundStyle(Theme.tx)
            Spacer()
            if let value { Text(value).font(Theme.ui(15)).foregroundStyle(Theme.mu).lineLimit(1) }
            if chevron { Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.mu2) }
        }
        .padding(.horizontal, 16).frame(minHeight: 54).contentShape(Rectangle())
    }
    private func toggle(_ t: String, _ sub: String?, _ on: Binding<Bool>) -> some View {
        Toggle(isOn: on) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t).caps(16).foregroundStyle(Theme.tx)
                if let sub, !sub.isEmpty { Text(sub).font(Theme.ui(14)).foregroundStyle(Theme.mu).multilineTextAlignment(.leading) }
            }
        }
        .tint(Theme.ac).padding(.horizontal, 16).padding(.vertical, 8).frame(minHeight: 54)
    }

    /// fields save when you leave them (web: onchange); each writes only its own setting, and only when it changed
    private func commit() {
        guard loaded else { return }
        let s = store.settings
        let a = anchor.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if !a.isEmpty, a != s.anchorQ { store.setSettings(["anchorQ": a]) }
        let l = Self.text(groups)
        if l != baseline { baseline = l; store.setSettings(["qLib": l]) }
        // web: Math.max(min, Math.round(value))
        for (key, text, low, cur) in [("cafStart", cafStart, 0, s.cafStart), ("cafStep", cafStep, 1, s.cafStep), ("cafDays", cafDays, 1, s.cafDays)] {
            let v = max(low, Int(text.trimmingCharacters(in: .whitespaces)) ?? 0)
            if v != cur { store.setSettings([key: v]) }
        }
        if focus == nil { DispatchQueue.main.async { loadCaf() } }
    }

    /// everything in one JSON file, same shape as the web export
    private func export() -> URL? {
        func clean(_ v: Any) -> Any {
            if let d = v as? [String: Any] { return d.mapValues(clean) }
            if let a = v as? [Any] { return a.map(clean) }
            if v is String || v is NSNumber || v is NSNull { return v }
            return "\(v)"
        }
        func withId(_ id: String, _ raw: [String: Any]) -> [String: Any] { var r = raw; r["id"] = id; return r }
        let data: [String: Any] = [
            "app": "Weekly Direction", "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "settings": clean(store.settings.raw), "weeks": store.weeks.map { clean(withId($0.id, $0.raw)) },
            "library": store.library.map { clean(withId($0.id, $0.raw)) }, "prayers": store.prayers.map { clean(withId($0.id, $0.raw)) },
            "draft": store.draft.map(clean) ?? NSNull()
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("weekly-direction-\(Rules.ymd(Date())).json")
        do { try json.write(to: url, options: .atomic); return url } catch { return nil }
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
