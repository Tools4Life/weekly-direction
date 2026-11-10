import SwiftUI

/// Settings (web: renderSettings): account, re-plan, appearance, sounds, caffeine wean, Saturday questions,
/// notifications on this phone, export.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var notifier: Notifier
    @Environment(\.dismiss) private var dismiss
    @State private var anchor = ""
    @State private var library = ""
    @State private var loaded = false
    @State private var replan: PlanRef?
    @State private var exportURL: URL?
    @State private var confirmSignOut = false
    @FocusState private var focus: Field?
    enum Field { case anchor, library }
    struct PlanRef: Identifiable { let id: String }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { commit(); dismiss() } label: {
                    HStack(spacing: 10) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium)); Text("This week") }
                        .font(Theme.ui(16)).foregroundStyle(Theme.mu)
                }
                .buttonStyle(.plain)
                Spacer()
                if focus != nil { Button("Done") { focus = nil }.font(Theme.ui(16, .semibold)).foregroundStyle(Theme.ac) }
            }
            .padding(.horizontal, 24).frame(height: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content }
                    .fullWidth().padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 50)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            guard !loaded else { return }
            loaded = true; anchor = store.settings.anchorQ; library = store.settings.qLib
            notifier.refresh()
        }
        .onChange(of: focus) { old, _ in if old != nil { commit() } }
        .fullScreenCover(item: $replan) { r in PlanView(replanId: r.id).environmentObject(store).environmentObject(router) }
        .sheet(item: $exportURL) { url in ShareSheet(items: [url]) }
        .confirmationDialog("Sign out on this device?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { router.cover = nil; store.signOut() }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder private var content: some View {
        Text("Settings").font(Theme.serif(34)).foregroundStyle(Theme.tx)
        label("Account")
        group {
            row { VStack(alignment: .leading, spacing: 3) {
                Text(store.email ?? "Not signed in").font(Theme.ui(16)).foregroundStyle(Theme.tx)
                Text(store.isMock ? "Preview data" : "Synced to your account").font(Theme.ui(14)).foregroundStyle(Theme.mu)
            } }
            divider
            Button { confirmSignOut = true } label: { row { Text("Sign out on this device").font(Theme.ui(16)).foregroundStyle(Theme.tx) } }.buttonStyle(.plain)
        }
        if let aw = store.activeWeek {
            label("This week")
            group {
                Button { replan = PlanRef(id: aw.id) } label: {
                    row { titled(strOf(store.draft?["replan"]) == aw.id ? "Resume re-planning" : "Re-plan this week",
                                 "Change the word, habits or notes, then seal again. Day marks are kept.") }
                }
                .buttonStyle(.plain)
            }
        }
        label("Appearance")
        group {
            HStack(spacing: 6) {
                ForEach([("dark", "Dark"), ("light", "Light"), ("auto", "Auto")], id: \.0) { t in
                    let on = store.settings.theme == t.0
                    Button(t.1) { Haptic.tick(); store.setSettings(["theme": t.0]) }
                        .font(Theme.ui(16)).foregroundStyle(on ? Color(hex: 0x0B0B0C) : Theme.tx)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(on ? Color(hex: 0xF7F4EF) : Color.clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(on ? Color.clear : Theme.line, lineWidth: 1))
                }
            }
            .buttonStyle(.plain).padding(16)
        }
        group {
            toggle("Sounds", "Soft tones when you start a timer, finish a habit or keep the day. Silent when the phone is on silent.",
                   Binding(get: { store.settings.sounds }, set: { store.setSettings(["sounds": $0]) }))
        }
        .padding(.top, 8)
        label("Caffeine wean")
        group {
            toggle("Track caffeine wean", store.settings.cafOn ? "AM and PM doses count toward a kept day." : "Hidden from This week. Doses don’t count toward a kept day.",
                   Binding(get: { store.settings.cafOn }, set: { Haptic.tick(); store.setSettings(["cafOn": $0]) }))
        }
        label("Saturday questions")
        group {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Anchor · asked every week", color: Theme.mu, size: 12)
                TextField("Anchor question", text: $anchor).font(Theme.ui(16)).foregroundStyle(Theme.tx).focused($focus, equals: .anchor).submitLabel(.done)
                    .padding(13).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
            .padding(16)
            divider
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Question library", color: Theme.mu, size: 12)
                TextEditor(text: $library).font(Theme.serif(16)).lineSpacing(5).foregroundStyle(Theme.tx).scrollContentBackground(.hidden)
                    .focused($focus, equals: .library).frame(height: 230)
                    .padding(8).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
            .padding(16)
        }
        Text("When you plan a week you pick two from the library; the anchor is always included. One question per line; lines starting with # are group names.")
            .font(Theme.ui(14)).foregroundStyle(Theme.mu).padding(.top, 10).padding(.horizontal, 4)
        label("Notifications")
        group {
            toggle("Notifications on this phone", notifier.note, Binding(get: { notifier.on }, set: { want in Task { await notifier.set(want, store: store) } }))
        }
        label("Your data")
        group {
            HStack(spacing: 12) {
                titled("Export my data", "A copy of every week, habit, reflection, prayer and setting, as one file you can keep.")
                Spacer()
                Button("Export") { exportURL = export() }
                    .font(Theme.ui(16, .semibold)).foregroundStyle(Theme.tx).padding(.horizontal, 16).frame(height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1)).buttonStyle(.plain)
            }
            .padding(16)
        }
    }

    private func label(_ t: String) -> some View { Eyebrow(text: t, color: Theme.mu, size: 12).padding(.top, 30).padding(.bottom, 10) }
    private var divider: some View { Rectangle().fill(Theme.rule).frame(height: 1) }
    private func group<V: View>(@ViewBuilder _ c: () -> V) -> some View { VStack(alignment: .leading, spacing: 0) { c() }.fullWidth().card(18) }
    private func row<V: View>(@ViewBuilder _ c: () -> V) -> some View { c().fullWidth().padding(16).contentShape(Rectangle()) }
    private func titled(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(t).font(Theme.ui(16)).foregroundStyle(Theme.tx)
            Text(sub).font(Theme.ui(14)).foregroundStyle(Theme.mu).multilineTextAlignment(.leading)
        }
    }
    private func toggle(_ t: String, _ sub: String, _ on: Binding<Bool>) -> some View {
        Toggle(isOn: on) { titled(t, sub) }.tint(Theme.ac).padding(16)
    }

    /// the question fields save when you leave them (web: onchange)
    private func commit() {
        let a = anchor.trimmingCharacters(in: .whitespacesAndNewlines)
        if !a.isEmpty, a != store.settings.anchorQ { store.setSettings(["anchorQ": a]) }
        let l = library.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        if l != store.settings.qLib { store.setSettings(["qLib": l]) }
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
