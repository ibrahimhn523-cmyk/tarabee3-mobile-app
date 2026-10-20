import Observation
import SwiftUI

/// حالة اللاعب في التطبيق: يدخل صامتاً، ثم إما أول فتح (لا ملف) أو الرئيسية (ملف قائم).
@MainActor
@Observable
final class ProfileStore {
    enum Phase: Equatable {
        case loading
        case notConfigured
        case firstOpen
        case ready
        case failed
    }

    private(set) var phase: Phase = .loading
    private(set) var player: Player?
    private(set) var saving = false
    private(set) var deleting = false

    private let backend: ProfileBackend?

    init(backend: ProfileBackend?) {
        self.backend = backend
        if backend == nil { phase = .notConfigured }
    }

    /// يُستدعى عند ظهور التطبيق.
    func start() async {
        guard let backend else { phase = .notConfigured; return }
        phase = .loading
        do {
            let id = try await backend.signIn()
            backend.observePlayer(id: id) { [weak self] player in
                guard let self, !self.deleting else { return }
                self.player = player
                self.phase = player == nil ? .firstOpen : .ready
            }
        } catch {
            phase = .failed
        }
    }

    /// الحفظ عبر الخادم؛ والمتابعة تأتي بالملف أيضاً، فلا يضرّ وصوله مرتين.
    func save(name: String, persona: Persona) async throws(ProfileError) {
        guard let backend else { throw .notConfigured }
        let name = NameRule.normalized(name)
        guard NameRule.isValidLength(name) else { throw .nameLength }
        saving = true
        defer { saving = false }
        player = try await backend.save(name: name, persona: persona)
        phase = .ready
    }

    /// حذف الحساب بعد التأكيد مرتين (R-63): يمحو الملف في الخادم، ثم يعود لأول فتح بمعرّف جديد.
    func deleteAccount() async throws(ProfileError) {
        guard let backend else { throw .notConfigured }
        deleting = true
        defer { deleting = false }
        try await backend.deleteAccount()
        player = nil
        phase = .loading
        await start()
    }
}

/// المظهر (R-69): تلقائي يتبع آيفون، أو فاتح أو داكن ثابت. يُحفظ على الجهاز وحده.
enum Appearance: String, CaseIterable {
    case system, light, dark

    static let storageKey = "appearance"

    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: String {
        switch self {
        case .system: Copy.Settings.appearanceSystem
        case .light: Copy.Settings.appearanceLight
        case .dark: Copy.Settings.appearanceDark
        }
    }
}
