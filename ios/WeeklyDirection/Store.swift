import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Live copy of the same Firestore data the web app uses, and the same writes the web app's store makes
/// (index.html: firestoreStore). Every week write is field-level (`setData(merge: true)`); `putWeek` is only for a
/// brand-new week. Nothing here writes a field the web app doesn't write.
final class DeleteMarker {}

@MainActor
final class Store: ObservableObject {
    @Published var user: User?
    @Published var email: String?
    @Published var settings = Settings()
    @Published var weeks: [Week] = []
    @Published var prayers: [Prayer] = []
    /// prayers spoken out loud, newest first
    @Published var prayerLog: [PrayerEntry] = []
    /// the AI summary of a week's prayers, by week id (see PrayerWeeks.swift)
    @Published var prayerSummaries: [String: String] = [:]
    @Published var library: [Chip] = []
    /// the in-progress plan (nil when there is none)
    @Published var draft: [String: Any]?
    @Published var ready = false
    @Published var error: String?

    /// sample data, no Firebase: simulator screenshots (see Mock.swift) and practice mode. While it is true every write
    /// below stays in memory.
    private(set) var isMock: Bool
    /// Practice mode (Eddie, Nov 10 2026): the app runs on sample data so the weekly review, planning and anything else
    /// can be tried freely. The account's listeners are detached and nothing is written to it; leaving reloads the real data.
    @Published private(set) var practice = false
    /// the voice and AI functions can be called: the real account, or practice mode (they only return text)
    var online: Bool { !isMock || practice }
    /// when practice mode was last entered: recordings made after this belong to practice, never to the real journal
    private(set) var practiceSince: Date?

    func enterPractice() {
        guard !isMock, user != nil else { return }
        listeners.forEach { $0.remove() }
        listeners = []
        isMock = true
        draft = nil
        practiceSince = Date()
        // the sample week and journal, but his own settings (theme, questions, close time)
        let own = settings
        Mock.load(into: self)
        settings = own
        // a Saturday evening in the sample week: the review is due, the clock keeps running
        Now.fixed = nil
        Now.offset = Rules.localDate("2026-11-14", "18:30")!.timeIntervalSince(Date())
        practice = true
    }

    func exitPractice() {
        guard practice else { return }
        Now.offset = nil
        isMock = false
        practice = false
        attach(Auth.auth().currentUser)
    }

    private var listeners: [ListenerRegistration] = []
    private var seen = Set<String>()
    private var authHandle: AuthStateDidChangeListenerHandle?
    private lazy var db = Firestore.firestore()
    private var base: CollectionReference?

    /// marks a field for deletion in a merge write (the web's F.deleteField())
    static let del: Any = DeleteMarker()

    init(mock: Bool = false) {
        isMock = mock
        if mock { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.attach(user) }
        }
    }

    var signedIn: Bool { isMock || user != nil }
    var activeWeek: Week? { weeks.first { $0.isActive } }
    func week(_ id: String?) -> Week? { weeks.first { $0.id == id } }

    func signIn(email: String, password: String) async {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() { if !isMock { try? Auth.auth().signOut() } }

    func token() async throws -> String {
        if !online { throw URLError(.userAuthenticationRequired) }
        guard let u = Auth.auth().currentUser else { throw URLError(.userAuthenticationRequired) }
        return try await u.getIDToken()
    }

    private func loaded(_ k: String) {
        seen.insert(k)
        if seen.count == 5 { ready = true }
    }

    private func attach(_ u: User?) {
        // an account event during practice must not bring the real data back under the in-memory writes
        if practice { return }
        listeners.forEach { $0.remove() }
        listeners = []
        user = u
        email = u?.email
        ready = false
        weeks = []; prayers = []; prayerLog = []; prayerSummaries = [:]; library = []; draft = nil
        base = nil
        guard let u else { return }
        // users/{uid}/weeklyDirection/{settings|draft}; data/{weeks|prayers|library} are collections
        let base = db.collection("users").document(u.uid).collection("weeklyDirection")
        self.base = base
        seen = []
        let fail: (Error) -> Void = { [weak self] e in self?.error = e.localizedDescription }
        listeners.append(base.document("settings").addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                guard let self else { return }
                if let err { fail(err); return }
                self.settings = Settings(snap?.data() ?? [:])
                self.loaded("settings")
            }
        })
        listeners.append(base.document("draft").addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                guard let self else { return }
                if let err { fail(err); return }
                self.draft = snap?.exists == true ? snap?.data() : nil
                self.loaded("draft")
            }
        })
        let data = base.document("data")
        listeners.append(data.collection("weeks").addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                guard let self else { return }
                if let err { fail(err); return }
                self.weeks = (snap?.documents ?? [])
                    .compactMap { Week(id: $0.documentID, $0.data()) }
                    .sorted { $0.sealedAtMs > $1.sealedAtMs }
                self.loaded("weeks")
            }
        })
        listeners.append(data.collection("prayers").addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                guard let self else { return }
                if let err { fail(err); return }
                self.prayers = (snap?.documents ?? []).map { Prayer(id: $0.documentID, $0.data()) }.sorted { $0.created > $1.created }
                self.loaded("prayers")
            }
        })
        // the spoken prayer log is not part of "ready": the app must open even if this collection cannot be read
        listeners.append(data.collection("prayerLog").addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self, let snap else { return }
                // the same collection holds the prayers ({at, text}) and one summary per week ({week, summary})
                self.prayerLog = snap.documents.compactMap { d in
                    guard let at = msOf(d.data()["at"]), let t = d.data()["text"] as? String else { return nil }
                    return PrayerEntry(id: d.documentID, at: at, text: t)
                }.sorted { $0.at > $1.at }
                var sums: [String: String] = [:]
                for d in snap.documents { if let w = d.data()["week"] as? String, let s = d.data()["summary"] as? String { sums[w] = s } }
                self.prayerSummaries = sums
            }
        })
        listeners.append(data.collection("library").addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                guard let self else { return }
                if let err { fail(err); return }
                self.library = (snap?.documents ?? []).map { Chip(id: $0.documentID, $0.data()) }.sorted { $0.order < $1.order }
                self.loaded("library")
            }
        })
    }

    // MARK: - writes (each mirrors one function of the web store)

    private var weeksCol: CollectionReference? { base?.document("data").collection("weeks") }

    /// swaps the deletion marker for Firestore's deleteField, at any depth
    private func wire(_ v: [String: Any]) -> [String: Any] {
        v.mapValues { x in
            if x is DeleteMarker { return FieldValue.delete() }
            if let m = x as? [String: Any] { return wire(m) }
            return x
        }
    }

    private func mergeWeek(_ id: String, _ fields: [String: Any]) {
        if isMock { mockMerge(id, fields); return }
        weeksCol?.document(id).setData(wire(fields), merge: true) { [weak self] e in
            if let e { Task { @MainActor in self?.error = e.localizedDescription } }
        }
    }

    /// store.setDay(w,k,items,mark): done.{k} merged with items; marks.{k} = mark, or deleted
    func setDay(_ w: Week, _ k: String, _ items: [String: Any], mark: String?) {
        mergeWeek(w.id, ["done": [k: items], "marks": [k: mark.map { $0 as Any } ?? Store.del]])
    }
    /// store.setRun(w,k,id,ts): runs.{k}.{id} = ts, or deleted
    func setRun(_ w: Week, _ k: String, _ id: String, _ ts: Double?) {
        mergeWeek(w.id, ["runs": [k: [id: ts.map { $0 as Any } ?? Store.del]]])
    }
    /// store.patchWeek(w,fields): merge only the named fields
    func patchWeek(_ w: Week, _ fields: [String: Any]) { mergeWeek(w.id, fields) }

    /// store.putWeek(w): full write, only for a brand-new week
    func putWeek(id: String, _ fields: [String: Any]) {
        if isMock { mockMerge(id, fields); return }
        weeksCol?.document(id).setData(fields)
    }

    func putPrayer(id: String, _ fields: [String: Any]) {
        if isMock {
            prayers = ([Prayer(id: id, fields)] + prayers.filter { $0.id != id }).sorted { $0.created > $1.created }
            return
        }
        base?.document("data").collection("prayers").document(id).setData(fields)
    }
    func delPrayer(_ id: String) {
        if isMock { prayers.removeAll { $0.id == id }; return }
        base?.document("data").collection("prayers").document(id).delete()
    }
    /// One spoken prayer. The id comes from the time it was spoken, so sending the same recording twice writes the same
    /// entry. Throws when the server has not taken it within 15 s: the recording then stays on the phone.
    func addPrayerLog(at: Double, text: String) async throws {
        let id = "l\(Int(at))"
        if isMock {
            prayerLog = ([PrayerEntry(id: id, at: at, text: text)] + prayerLog.filter { $0.id != id }).sorted { $0.at > $1.at }
            return
        }
        guard let ref = base?.document("data").collection("prayerLog").document(id) else { throw URLError(.userAuthenticationRequired) }
        try await withThrowingTaskGroup(of: Void.self) { g in
            g.addTask { try await ref.setData(["at": at, "text": text]) }
            g.addTask { try await Task.sleep(nanoseconds: 15_000_000_000); throw URLError(.timedOut) }
            try await g.next()
            g.cancelAll()
        }
    }
    /// the summary of one week's prayers: `data/prayerLog/s-<week>` = {week, summary, at}
    func putPrayerSummary(_ week: String, _ text: String) {
        if isMock { prayerSummaries[week] = text; return }
        base?.document("data").collection("prayerLog").document("s-" + week).setData(["week": week, "summary": text, "at": Now.ms])
    }
    func delPrayerLog(_ id: String) {
        if isMock { prayerLog.removeAll { $0.id == id }; return }
        base?.document("data").collection("prayerLog").document(id).delete()
    }
    func putChip(id: String, _ fields: [String: Any]) {
        if isMock {
            library = (library.filter { $0.id != id } + [Chip(id: id, fields)]).sorted { $0.order < $1.order }
            return
        }
        base?.document("data").collection("library").document(id).setData(fields)
    }
    func delChip(_ id: String) {
        if isMock { library.removeAll { $0.id == id }; return }
        base?.document("data").collection("library").document(id).delete()
    }
    func putDraft(_ v: [String: Any]) {
        if isMock { draft = v; return }
        base?.document("draft").setData(v)
    }
    func delDraft() {
        if isMock { draft = nil; return }
        base?.document("draft").delete()
    }
    func setSettings(_ v: [String: Any]) {
        if isMock { settings = Settings(settings.raw.merging(v) { $1 }); return }
        base?.document("settings").setData(v, merge: true)
    }

    // MARK: - mock (in-memory, like the web's memoryStore)

    func loadMock(settings: [String: Any], weeks: [[String: Any]], prayers: [[String: Any]], library: [[String: Any]], prayerLog: [PrayerEntry] = [],
                  prayerSummaries: [String: String] = [:]) {
        self.prayerLog = prayerLog.sorted { $0.at > $1.at }
        self.prayerSummaries = prayerSummaries
        self.settings = Settings(settings)
        self.weeks = weeks.compactMap { Week(id: $0["id"] as? String ?? "", $0) }.sorted { $0.sealedAtMs > $1.sealedAtMs }
        self.prayers = prayers.map { Prayer(id: $0["id"] as? String ?? "", $0) }.sorted { $0.created > $1.created }
        self.library = library.map { Chip(id: $0["id"] as? String ?? "", $0) }.sorted { $0.order < $1.order }
        email = "demo@example.com"
        ready = true
        if UserDefaults.standard.bool(forKey: "MockPractice") { practice = true }      // screenshots of the practice banner
    }

    private func deepMerge(_ a: [String: Any], _ b: [String: Any]) -> [String: Any] {
        var out = a
        for (k, v) in b {
            if v is DeleteMarker { out[k] = nil }
            else if let m = v as? [String: Any], let cur = out[k] as? [String: Any] { out[k] = deepMerge(cur, m) }
            else if let m = v as? [String: Any] { out[k] = deepMerge([:], m) }
            else { out[k] = v }
        }
        return out
    }
    private func mockMerge(_ id: String, _ fields: [String: Any]) {
        let cur = week(id)?.raw ?? [:]
        guard let nw = Week(id: id, deepMerge(cur, fields)) else { return }
        weeks = ([nw] + weeks.filter { $0.id != id }).sorted { $0.sealedAtMs > $1.sealedAtMs }
    }
}
