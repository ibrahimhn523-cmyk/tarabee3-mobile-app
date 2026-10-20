import Observation
import SwiftUI
import UIKit

/// مباراة تدريب على الجهاز (R-45): المحرّك عبر الجسر يحكمها، واللاعب في المقعد الأول، والآليون يلعبهم المحرّك.
/// لا تُحسب في الملف، ولا إعلان فيها، ولا شبكة.
@MainActor
@Observable
final class TrainingSession {
    struct Setup: Equatable {
        var size: Int
        var boardSize: Int
    }

    static let mySeat = 1

    private(set) var view: MatchView?
    private(set) var failed = false
    /// المربع المعاين قبل الاعتماد، على هذا الجهاز وحده (R-23).
    var preview: Square?
    /// ما أرسله اللاعب في الدور الجاري، يثبت حتى يردّ المحرّك.
    private(set) var sentAnswer: AnswerChoice?

    let setup: Setup
    private let player: Player
    private let bridge: EngineBridge?
    private var state: String?
    private var loop: Task<Void, Never>?
    private var warnedLastFive = false
    private let clock: () -> Double

    init(setup: Setup, player: Player, bridge: EngineBridge? = try? EngineBridge(), clock: @escaping () -> Double = { Date().timeIntervalSince1970 * 1000 }) {
        self.setup = setup
        self.player = player
        self.bridge = bridge
        self.clock = clock
    }

    var now: Double { clock() }

    /// ينشئ المباراة ويبدأ «استعدّ ٣-٢-١». seed للاختبار؛ وإلا عشوائية.
    func start(seed: Int = Int.random(in: 1...Int(Int32.max)), runLoop: Bool = true) {
        guard let bridge, let pack = TrainingPack.current() else { failed = true; return }
        let setupJSON = """
        {"size":\(setup.size),"boardSize":\(setup.boardSize),"seed":\(seed),\
        "player":{"displayName":\(jsonString(player.name)),"persona":\(personaJSON(player.persona))},\
        "questions":\(pack.questionsJSON)}
        """
        do {
            apply(try bridge.createTraining(setupJSON: setupJSON, now: now))
        } catch {
            failed = true
            return
        }
        if runLoop { startLoop() }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    private func startLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                self.advance(to: self.now)
                if self.view?.phase.kind == "ended" { return }
            }
        }
    }

    /// يقدّم المحرّك إلى لحظة بعينها (النبض، أو الاختبار).
    func advance(to time: Double) {
        guard let bridge, let state else { return }
        if let out = try? bridge.tick(state: state, now: time) { apply(out) }
    }

    // MARK: - أفعال اللاعب

    var isMyTurn: Bool { view?.round?.seatNo == Self.mySeat }

    func answer(_ choice: AnswerChoice) {
        guard let bridge, let state, isMyTurn, view?.phase.kind == "answering", sentAnswer == nil else { return }
        sentAnswer = choice
        Haptics.play(Tokens.Haptics.send)
        if let out = try? bridge.answer(state: state, seatNo: Self.mySeat, choice: choice, now: now) { apply(out) }
    }

    /// الضغطة الأولى تعاين، والاعتماد زرّ مستقل (05-ui §١٦).
    func select(_ square: Square) {
        guard isMyTurn, view?.phase.kind == "choosing", let view, view.owner(square.row, square.col) == 0 else { return }
        preview = square
    }

    func commit() {
        guard let bridge, let state, let preview, isMyTurn, view?.phase.kind == "choosing" else { return }
        Haptics.play(Tokens.Haptics.commit)
        if let out = try? bridge.choose(state: state, seatNo: Self.mySeat, square: preview, now: now) { apply(out) }
    }

    // MARK: - داخلي

    private func apply(_ out: EngineBridge.Output) {
        let previousRound = view?.round?.id
        state = out.state
        view = out.view
        if out.view.round?.id != previousRound {
            sentAnswer = nil
            preview = nil
            warnedLastFive = false
        }
        if out.view.phase.kind != "choosing" { preview = nil }
        for event in out.events where event.type == "turnStarted" && event.seatNo == Self.mySeat {
            Haptics.play(Tokens.Haptics.yourTurn)
        }
        // آخر خمس ثوانٍ: اهتزاز خفيف مرة (05-ui §٦ المؤقّت)
        if isMyTurn, let deadline = out.view.phase.deadline, deadline - now <= 5000, !warnedLastFive {
            warnedLastFive = true
            Haptics.play(Tokens.Haptics.lastFive)
        }
    }

    private func jsonString(_ s: String) -> String {
        (try? String(data: JSONEncoder().encode(s), encoding: .utf8)) ?? "\"\""
    }

    private func personaJSON(_ p: Persona) -> String {
        (try? String(data: JSONEncoder().encode(PersonaWire(p)), encoding: .utf8)) ?? "{}"
    }
}

/// الاهتزاز (05-ui §٦ «الاهتزاز» وhaptics في ملف القيم). يسكت إن أطفأه المستخدم في آيفون.
@MainActor
enum Haptics {
    static func play(_ token: String) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = switch token {
        case "heavy": .heavy
        case "medium": .medium
        default: .light
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
