import Observation
import SwiftUI
import UIKit

/// مباراة تدريب على الجهاز (R-45): المحرّك عبر الجسر يحكمها بالقواعد كلها، واللاعب في المقعد الأول،
/// والآليون يلعبهم المحرّك. لا تُحسب في الملف، ولا إعلان فيها، ولا شبكة.
@MainActor
@Observable
final class TrainingSession: MatchSession {
    struct Setup: Equatable {
        var size: Int
        var boardSize: Int
    }

    static let mySeat = 1
    var mySeat: Int { Self.mySeat }

    private(set) var view: MatchView?
    /// المحرّك رمى خطأً أو لم يُحمَّل: تظهر رسالة بدل شاشة متجمّدة.
    private(set) var failureText: String?
    /// المراكز المعاينة قبل الاعتماد، على هذا الجهاز وحده (R-23): واحد، أو اثنان بـ «صليبان».
    var preview: [Square] = []
    /// مربعات المعاينة من المحرّك نفسه.
    var previewCells: Set<Square> = []
    /// ما أرسله اللاعب في دوره، يثبت حتى يردّ المحرّك.
    var sentAnswer: AnswerChoice?
    var targeting: CardTargeting?
    /// آخر رفض من المحرّك.
    private(set) var lastRejection: String?
    // لا ردود جاهزة في التدريب: لا أحد يقرؤها
    let replies: [ReplyBubble] = []
    let repliesEnabled = false
    let canReply = false
    func sendReply(_ reply: Int) {}

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

    /// اللوح المقترح بالحجم، من المحرّك (لشاشة الإعداد).
    static func suggestedBoard(size: Int) -> Int {
        (try? EngineBridge())?.suggestedBoard(size: size) ?? 9
    }

    /// ينشئ المباراة ويبدأ «استعدّ ٣-٢-١». seed للاختبار؛ وإلا عشوائية.
    func start(seed: Int = Int.random(in: 1...Int(Int32.max)), runLoop: Bool = true) {
        guard let bridge, let pack = TrainingPack.current() else { failureText = Copy.Match.packMissing; return }
        let setupJSON = """
        {"size":\(setup.size),"boardSize":\(setup.boardSize),"seed":\(seed),\
        "player":{"displayName":\(jsonString(player.name)),"persona":\(personaJSON(player.persona))},\
        "questions":\(pack.questionsJSON)}
        """
        run { try bridge.createTraining(setupJSON: setupJSON, now: now, viewer: Self.mySeat) }
        if runLoop && !failed { startLoop() }
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
        guard let bridge, let state, !failed else { return }
        run { try bridge.tick(state: state, now: time, viewer: Self.mySeat) }
    }

    func crossCells(_ center: Square) -> [Square] {
        guard let view, let bridge else { return [] }
        return bridge.crossCells(boardSize: view.boardSize, center: center)
    }

    /// الطلب إلى المحرّك على الجهاز، ويعود العرض فوراً.
    func send(_ action: MatchAction) {
        guard let bridge, let state else { return }
        let seat = Self.mySeat
        switch action {
        case .answer(let choice): run { try bridge.answer(state: state, seatNo: seat, choice: choice, now: now) }
        case .choose(let centers): run { try bridge.choose(state: state, seatNo: seat, centers: centers, now: now) }
        case .openBox: run { try bridge.openBox(state: state, seatNo: seat, now: now) }
        case .card(let id, let cells, let center): run { try bridge.playCard(state: state, seatNo: seat, cardId: id, cells: cells, center: center, now: now) }
        case .burn(let burn): run { try bridge.decideBurn(state: state, seatNo: seat, burn: burn, now: now) }
        }
    }

    // MARK: - داخلي

    /// كل استدعاء للمحرّك: الخطأ يوقف الجلسة برسالة، لا يُبتلع.
    private func run(_ body: () throws -> EngineBridge.Output) {
        do {
            apply(try body())
        } catch {
            failureText = Copy.Match.packMissing
            stop()
        }
    }

    private func apply(_ out: EngineBridge.Output) {
        let previous = view
        state = out.state
        view = out.view
        lastRejection = out.rejected
        if out.view.round?.id != previous?.round?.id { warnedLastFive = false }
        resetLocal(for: out.view, previous: previous)
        for event in out.events where event.type == "turnStarted" && event.seatNo == Self.mySeat {
            Haptics.play(Tokens.Haptics.yourTurn)
        }
        // نافذة الحرق: اهتزاز قوي عند فتحها (05-ui §٦)
        if previous?.phase.kind != "burn", myBurnWindow != nil { Haptics.play(Tokens.Haptics.burnOpen) }
        // آخر خمس ثوانٍ: اهتزاز خفيف مرة
        if isMyTurn || canAnswerGroup, let deadline = out.view.phase.deadline, deadline - now <= 5000, !warnedLastFive {
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
