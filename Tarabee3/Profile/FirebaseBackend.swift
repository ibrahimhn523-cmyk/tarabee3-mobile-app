import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseFirestore

/// الهوية الصامتة من فايربيس، وقراءة الملف من Firestore بقواعد الأمان (الجهاز يقرأ ملفه وحده ولا يكتب)،
/// والكتابة عبر الخادم برمز الهوية (القرار 0018).
@MainActor
final class FirebaseBackend: ProfileBackend {
    private let api: ServerAPI
    private var listener: ListenerRegistration?

    /// nil إن غاب ملف إعداد فايربيس أو عنوان الخادم: يُدخَل الملف وقت البناء من خزنة قِت هب، لا من المستودع العام.
    static func configured() -> FirebaseBackend? {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
              let api = ServerAPI.fromBundle() else { return nil }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        return FirebaseBackend(api: api)
    }

    private init(api: ServerAPI) { self.api = api }

    func signIn() async throws -> String {
        if let user = Auth.auth().currentUser { return user.uid }
        return try await Auth.auth().signInAnonymously().user.uid
    }

    func observePlayer(id: String, onChange: @escaping @MainActor (Player?) -> Void) {
        stopObserving()
        listener = Firestore.firestore().collection("players").document(id).addSnapshotListener { snapshot, _ in
            let player = snapshot.flatMap { $0.exists ? Player(id: id, fields: $0.data() ?? [:]) : nil }
            let missing = snapshot.map { !$0.exists } ?? false
            Task { @MainActor in
                // خطأ القراءة لا يمحو ملفاً معروضاً؛ الغياب المؤكَّد وحده يعيد لأول فتح.
                if player != nil || missing { onChange(player) }
            }
        }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    func save(name: String, persona: Persona) async throws(ProfileError) -> Player {
        try await api.save(name: name, persona: persona, token: try await token())
    }

    func deleteAccount() async throws(ProfileError) {
        try await api.delete(token: try await token())
        stopObserving()
        // الخادم حذف حساب الهوية؛ والخروج المحلي يجعل الفتح التالي معرّفاً جديداً.
        try? Auth.auth().signOut()
    }

    private func token() async throws(ProfileError) -> String {
        guard let user = Auth.auth().currentUser else { throw .server }
        do { return try await user.getIDToken() } catch { throw .offline }
    }
}
