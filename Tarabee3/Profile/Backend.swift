import Foundation

/// ما يحتاجه الملف من الخارج: الهوية الصامتة، وقراءة الملف، والخادم. منفصل ليُختبر التطبيق ويُصوَّر بلا شبكة.
@MainActor
protocol ProfileBackend: AnyObject {
    /// يدخل صامتاً إن لم يكن داخلاً (R-01)، ويرجع معرّف اللاعب.
    func signIn() async throws -> String
    /// يتابع ملف اللاعب؛ nil إن لم يُنشأ بعد. يُستدعى أول مرة فور القراءة.
    func observePlayer(id: String, onChange: @escaping @MainActor (Player?) -> Void)
    func stopObserving()
    func save(name: String, persona: Persona) async throws(ProfileError) -> Player
    func deleteAccount() async throws(ProfileError)
}
