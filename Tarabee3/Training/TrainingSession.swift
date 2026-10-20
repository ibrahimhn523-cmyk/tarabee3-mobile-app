import Observation
import SwiftUI
import UIKit

/// مباراة تدريب على الجهاز (R-45): المحرّك عبر الجسر يحكمها بالقواعد كلها، واللاعب في المقعد الأول،
/// والآليون يلعبهم المحرّك. لا تُحسب في الملف، ولا إعلان فيها، ولا شبكة.
@MainActor
@Observable
final class TrainingSession {
    struct Setup: Equatable {
        var size: Int
        var boardSize: Int
    }

    /// استهداف كرت يحتاج مربعات قبل لعبه (RULES-cards): التفريغ بعدده، أو مركز التحصين.
    enum Targeting: Equatable {
        case clear(cardId: Int, count: Int, selected: [Square])
        case fortify(cardId: Int, center: Square?)
    }

    static let mySeat = 1

    private(set) var view: MatchView?
    /// المحرّك رمى خطأً أو لم يُحمَّل: تظهر رسالة بدل شاشة متجمّدة.
    private(set) var failed = false
    /// المراكز المعاينة قبل الاعتماد، على هذا الجهاز وحده (R-23): واحد، أو اثنان بـ «صليبان».
    private(set) var preview: [Square] = []
    /// مربعات المعاينة من المحرّك نفسه.
    private(set) var previewCells: Set<Square> = []
    /// ما أرسله اللاعب في دوره، يثبت حتى يردّ المحرّك.
    private(set) var sentAnswer: AnswerChoice?
    private(set) var targeting: Targeting?
    /// آخر رفض من المحرّك.
    private(set) var lastRejection: String?

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
        guard let bridge, let pack = TrainingPack.current() else { failed = true; return }
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

    // MARK: - ما يعرفه العرض

    var me: SeatView? { view?.seat(Self.mySeat) }
    var phase: String { view?.phase.kind ?? "" }
    var isMyTurn: Bool { view?.round?.type == "turn" && view?.round?.seatNo == Self.mySeat }
    /// أنا من يختار الآن: صاحب الدور المصيب، أو فائز الجماعية.
    var isChooser: Bool { phase == "choosing" && view?.round?.chooser == Self.mySeat }
    var myBurnWindow: BurnWindowView? {
        view?.phase.windows?.first { $0.seatNo == Self.mySeat && $0.decided == nil }
    }
    var canAnswerGroup: Bool { phase == "group" && view?.round?.myAnswer == nil }

    /// هل يُلعب هذا الكرت الآن؟ ومع الرفض سببه (05-ui §٦ «الكرت»: ليس وقته: خافت مع السبب).
    func playability(_ card: CardView) -> (ok: Bool, reason: String?) {
        guard let round = view?.round else { return (false, Copy.Cards.notNow) }
        switch card.type.window {
        case .reaction:
            return (false, Copy.Cards.reactionOnly)
        case .question:
            guard phase == "answering", isMyTurn, sentAnswer == nil, round.answer == nil else {
                return (false, round.isGroup ? Copy.Cards.notInGroup : Copy.Cards.questionWindow)
            }
            if card.type == .swapQuestion && round.anyAnswer == true { return (false, Copy.Cards.swapLocked) }
            return (true, nil)
        case .board:
            guard isChooser else { return (false, Copy.Cards.boardWindow) }
            if round.boardCard != nil { return (false, Copy.Cards.oneBoardCard) }
            return (true, nil)
        }
    }

    // MARK: - أفعال اللاعب

    func answer(_ choice: AnswerChoice) {
        guard let bridge, let state else { return }
        let group = canAnswerGroup
        guard group || (phase == "answering" && isMyTurn && sentAnswer == nil && targeting == nil) else { return }
        if !group { sentAnswer = choice }
        Haptics.play(Tokens.Haptics.send)
        run { try bridge.answer(state: state, seatNo: Self.mySeat, choice: choice, now: now) }
    }

    /// الضغطة تعاين، والاعتماد زرّ مستقل (05-ui §١٦). بـ «صليبان» مركزان، وبـ «ضع في أي مربع» يجوز المملوك.
    func select(_ square: Square) {
        guard let view, let bridge else { return }
        if let targeting { return target(square, targeting) }
        guard isChooser, !view.fortified.contains(square) else { return }
        let anywhere = view.round?.boardCard == .placeAnywhere
        guard anywhere || view.owner(square) == 0 else { return }
        if view.round?.boardCard == .doubleCross {
            if let i = preview.firstIndex(of: square) { preview.remove(at: i) } else { preview = Array((preview + [square]).suffix(2)) }
        } else {
            preview = [square]
        }
        previewCells = Set(preview.flatMap { bridge.crossCells(boardSize: view.boardSize, center: $0) })
    }

    var canCommit: Bool { isChooser && preview.count == (view?.round?.boardCard == .doubleCross ? 2 : 1) }

    func commit() {
        guard let bridge, let state, canCommit else { return }
        Haptics.play(Tokens.Haptics.commit)
        run { try bridge.choose(state: state, seatNo: Self.mySeat, centers: preview, now: now) }
    }

    func openBox() {
        guard let bridge, let state, isChooser, (me?.boxesLeft ?? 0) > 0 else { return }
        Haptics.play(Tokens.Haptics.commit)
        run { try bridge.openBox(state: state, seatNo: Self.mySeat, now: now) }
    }

    /// يلعب الكرت؛ وما يحتاج مربعات يدخل وضع الاستهداف أولاً.
    func play(_ card: CardView) {
        guard let bridge, let state, playability(card).ok else { return }
        switch card.type {
        case .clearSquares:
            targeting = .clear(cardId: card.id, count: card.clearCount ?? 1, selected: [])
        case .fortify:
            targeting = .fortify(cardId: card.id, center: nil)
        default:
            run { try bridge.playCard(state: state, seatNo: Self.mySeat, cardId: card.id, now: now) }
        }
    }

    private func target(_ square: Square, _ mode: Targeting) {
        guard let view else { return }
        switch mode {
        case .clear(let id, let count, var selected):
            // يلزم أن يكون مملوكاً وخارج التحصين (RULES-cards §٤)
            guard view.owner(square) != 0, !view.fortified.contains(square) else { return }
            if let i = selected.firstIndex(of: square) { selected.remove(at: i) } else { selected = Array((selected + [square]).suffix(count)) }
            targeting = .clear(cardId: id, count: count, selected: selected)
        case .fortify(let id, _):
            targeting = .fortify(cardId: id, center: square)
        }
    }

    var targetReady: Bool {
        switch targeting {
        case .clear(_, let count, let selected): selected.count == count
        case .fortify(_, let center): center != nil
        case nil: false
        }
    }

    /// مربعات الاستهداف المعروضة على اللوح.
    var targetCells: Set<Square> {
        guard let view, let bridge else { return [] }
        switch targeting {
        case .clear(_, _, let selected): return Set(selected)
        case .fortify(_, let center?): return Set(bridge.crossCells(boardSize: view.boardSize, center: center))
        default: return []
        }
    }

    func confirmTarget() {
        guard let bridge, let state, targetReady, let mode = targeting else { return }
        targeting = nil
        switch mode {
        case .clear(let id, _, let selected):
            run { try bridge.playCard(state: state, seatNo: Self.mySeat, cardId: id, cells: selected, now: now) }
        case .fortify(let id, let center):
            run { try bridge.playCard(state: state, seatNo: Self.mySeat, cardId: id, center: center, now: now) }
        }
    }

    func cancelTarget() { targeting = nil }

    /// قرار نافذة الحرق (R-40): الصمت لا يحرق.
    func decideBurn(_ burn: Bool) {
        guard let bridge, let state, myBurnWindow != nil else { return }
        run { try bridge.decideBurn(state: state, seatNo: Self.mySeat, burn: burn, now: now) }
    }

    // MARK: - داخلي

    /// كل استدعاء للمحرّك: الخطأ يوقف الجلسة برسالة، لا يُبتلع.
    private func run(_ body: () throws -> EngineBridge.Output) {
        do {
            apply(try body())
        } catch {
            failed = true
            stop()
        }
    }

    private func apply(_ out: EngineBridge.Output) {
        let previousRound = view?.round?.id
        let previousPhase = view?.phase.kind
        state = out.state
        view = out.view
        lastRejection = out.rejected
        if out.view.round?.id != previousRound {
            sentAnswer = nil
            warnedLastFive = false
            targeting = nil
        }
        if out.view.round?.id != previousRound || out.view.phase.kind != "choosing" || out.view.round?.chooser != Self.mySeat {
            preview = []
            previewCells = []
        }
        if out.view.phase.kind != "answering" { targeting = nil }
        for event in out.events where event.type == "turnStarted" && event.seatNo == Self.mySeat {
            Haptics.play(Tokens.Haptics.yourTurn)
        }
        // نافذة الحرق: اهتزاز قوي عند فتحها (05-ui §٦)
        if previousPhase != "burn", myBurnWindow != nil { Haptics.play(Tokens.Haptics.burnOpen) }
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
