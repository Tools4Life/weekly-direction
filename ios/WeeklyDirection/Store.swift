import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Live copy of the same Firestore data the web app uses. Read-only in this first build:
/// writes come in phase 2, once each one is checked against the web app's rules.
@MainActor
final class Store: ObservableObject {
    @Published var user: User?
    @Published var settings = Settings()
    @Published var weeks: [Week] = []
    @Published var ready = false
    @Published var error: String?

    private var listeners: [ListenerRegistration] = []
    private var seen = Set<String>()

    private func loaded(_ k: String) {
        seen.insert(k)
        if seen.count == 2 { ready = true }
    }
    private var authHandle: AuthStateDidChangeListenerHandle?
    private lazy var db = Firestore.firestore()

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.attach(user) }
        }
    }

    var activeWeek: Week? { weeks.first { $0.isActive } }

    func signIn(email: String, password: String) async {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() { try? Auth.auth().signOut() }

    private func attach(_ u: User?) {
        listeners.forEach { $0.remove() }
        listeners = []
        user = u
        ready = false
        weeks = []
        guard let u else { return }
        // users/{uid}/weeklyDirection/{settings}; data/weeks is a collection
        let base = db.collection("users").document(u.uid).collection("weeklyDirection")
        seen = []
        listeners.append(base.document("settings").addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                guard let self else { return }
                if let err { self.error = err.localizedDescription; return }
                self.settings = Settings(snap?.data() ?? [:])
                self.loaded("settings")
            }
        })
        listeners.append(base.document("data").collection("weeks").addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                guard let self else { return }
                if let err { self.error = err.localizedDescription; return }
                self.weeks = (snap?.documents ?? [])
                    .compactMap { Week(id: $0.documentID, $0.data()) }
                    .sorted { $0.sealedAt > $1.sealedAt }
                self.loaded("weeks")
            }
        })
    }
}
