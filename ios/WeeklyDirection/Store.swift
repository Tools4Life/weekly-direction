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
    @Published var library: [Chip] = []
    /// the in-progress plan (nil when there is none)
    @Published var draft: [String: Any]?
    @Published var ready = false
    @Published var error: String?

    /// sample data, no Firebase: only for simulator screenshots (see Mock.swift)
    let isMock: Bool

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
        if isMock { throw URLError(.userAuthenticationRequired) }
        guard let u = Auth.auth().currentUser else { throw URLError(.userAuthenticationRequired) }
        return try await u.getIDToken()
    }

    private func loaded(_ k: String) {
        seen.insert(k)
        if seen.count == 5 { ready = true }
    }

    private func attach(_ u: User?) {
        listeners.forEach { $0.remove() }
        listeners = []
        user = u
        email = u?.email
        ready = false
        weeks = []; prayers = []; library = []; draft = nil
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

    func loadMock(settings: [String: Any], weeks: [[String: Any]], prayers: [[String: Any]], library: [[String: Any]]) {
        self.settings = Settings(settings)
        self.weeks = weeks.compactMap { Week(id: $0["id"] as? String ?? "", $0) }.sorted { $0.sealedAtMs > $1.sealedAtMs }
        self.prayers = prayers.map { Prayer(id: $0["id"] as? String ?? "", $0) }.sorted { $0.created > $1.created }
        self.library = library.map { Chip(id: $0["id"] as? String ?? "", $0) }.sorted { $0.order < $1.order }
        email = "demo@example.com"
        ready = true
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
