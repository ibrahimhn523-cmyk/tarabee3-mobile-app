import Foundation
@testable import Tarabee3

/// خلفية في الذاكرة مكان فايربيس والخادم.
@MainActor
final class FakeBackend: ProfileBackend {
    var player: Player?
    var savedNames: [String] = []
    var deletions = 0
    var saveError: ProfileError?
    private var onChange: (@MainActor (Player?) -> Void)?
    private var uid = "player-1"

    init(player: Player? = nil) { self.player = player }

    func signIn() async throws -> String { uid }

    var failReads = false

    func observePlayer(id: String, onChange: @escaping @MainActor (Player?) -> Void, onError: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        if failReads { onError() } else { onChange(player) }
    }

    func stopObserving() { onChange = nil }

    func save(name: String, persona: Persona) async throws(ProfileError) -> Player {
        if let saveError { throw saveError }
        savedNames.append(name)
        let saved = Player(id: uid, name: name, persona: persona)
        player = saved
        onChange?(saved)
        return saved
    }

    func deleteAccount() async throws(ProfileError) {
        deletions += 1
        player = nil
        uid = "player-2"
        stopObserving()
    }
}
