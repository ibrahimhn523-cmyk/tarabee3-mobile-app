import SwiftUI
import UIKit
import XCTest
@testable import Tarabee3

/// ساعة يتحكّم فيها الاختبار.
@MainActor
final class TestClock {
    var now: Double = 1_000_000
}

/// اللعب الآلي لمقعدي في الاختبارات: الخيار الأول، وأول مربع فارغ، والحرق متروك.
@MainActor
enum AutoPlay {
    static func firstChoice(_ q: QuestionView) -> AnswerChoice { q.isTrueFalse ? .truth(true) : .option(1) }

    /// يعاين المربعات الفارغة غير المحصّنة بقدر ما يلزم (اثنان بـ «صليبين»).
    static func selectSquares(_ s: TrainingSession) {
        guard let view = s.view else { return }
        let need = view.round?.boardCard == .doubleCross ? 2 : 1
        let free = (0..<view.board.count).map { Square(row: $0 / view.boardSize, col: $0 % view.boardSize) }
            .filter { view.owner($0) == 0 && !view.fortified.contains($0) && !s.preview.contains($0) }
        for square in free.prefix(need - s.preview.count) { s.select(square) }
    }

    static func step(_ s: TrainingSession, group: Bool = true, choose: Bool = true) {
        guard let round = s.view?.round else { return }
        if s.myBurnWindow != nil { s.decideBurn(false); return }
        if group && s.canAnswerGroup { s.answer(firstChoice(round.question)); return }
        if s.phase == "answering", s.isMyTurn, s.sentAnswer == nil { s.answer(firstChoice(round.question)); return }
        if choose && s.isChooser { selectSquares(s); s.commit() }
    }
}

/// «المحرّك نفسه يعمل في الاختبارات الآلية وعلى الجوال، بنسخة واحدة» (معيار M-04): هنا يعمل engine.js المشحون مع
/// التطبيق في JavaScriptCore على محاكي آيفون، ويلعب تدريباً كاملاً.
@MainActor
final class TrainingTests: XCTestCase {
    private let player = Player(id: "p", name: "أبو خليل", persona: Persona(expression: .confident, head: .shemagh, eye: .none, neck: .none))

    private func session(size: Int = 3, boardSize: Int = 9, seed: Int) -> (TrainingSession, TestClock) {
        let clock = TestClock()
        let s = TrainingSession(setup: .init(size: size, boardSize: boardSize), player: player, clock: { clock.now })
        s.start(seed: seed, runLoop: false)
        return (s, clock)
    }

    /// يقدّم ربع ثانية في كل خطوة حتى يتحقّق الشرط أو تنتهي المباراة، ويلعب مقعدي بما يسمح به.
    private func run(_ s: TrainingSession, _ clock: TestClock, group: Bool = true, choose: Bool = true,
                     until done: (TrainingSession) -> Bool) {
        for _ in 0..<8000 where !done(s) && s.phase != "ended" && !s.failed {
            clock.now += 250
            s.advance(to: clock.now)
            if done(s) { return }
            AutoPlay.step(s, group: group, choose: choose)
        }
    }

    func testBundledEngineAndPackLoad() throws {
        XCTAssertNoThrow(try EngineBridge())
        let pack = try XCTUnwrap(TrainingPack.current())
        XCTAssertFalse(pack.version.isEmpty)
    }

    func testFullTrainingMatchForEverySize() throws {
        for (size, board) in [(3, 9), (4, 10), (5, 11)] {
            let (s, clock) = session(size: size, boardSize: board, seed: 7 + size)
            XCTAssertFalse(s.failed)
            run(s, clock) { _ in false }
            let view = try XCTUnwrap(s.view)
            XCTAssertEqual(view.phase.kind, "ended", "حجم \(size)")
            XCTAssertEqual(view.ranking?.count, size)
            XCTAssertEqual(view.seats.filter(\.isBot).count, size - 1)
            XCTAssertEqual(view.seats.first { !$0.isBot }?.displayName, "أبو خليل")
            XCTAssertFalse(s.failed)
        }
    }

    /// قواعد العرض من المحرّك لا مكرّرة في سويفت (مراجعة M-04، المشكلة ٤).
    func testRulesComeFromTheEngine() throws {
        let bridge = try EngineBridge()
        XCTAssertEqual(bridge.crossCells(boardSize: 9, center: Square(row: 0, col: 0)).count, 3)
        XCTAssertEqual(bridge.crossCells(boardSize: 9, center: Square(row: 4, col: 4)).count, 5)
        XCTAssertEqual([3, 4, 5].map { bridge.suggestedBoard(size: $0) }, [9, 10, 11])
        // حدّ الحزمة على الجهاز هو حساب المحرّك نفسه (مراجعة M-05، المشكلة ٢)
        XCTAssertEqual(TrainingPack.minimumQuestions, bridge.questionsNeeded(size: 5))
    }

    /// المربع الصالح من المحرّك: لا معاينة على مربع مملوك ولا اعتماد بعدد غير ما يطلبه (مراجعة M-05، المشكلة ٤).
    func testChoosingFollowsTheEngine() throws {
        let (s, clock) = session(seed: 2)
        run(s, clock, choose: false) { $0.isChooser }
        let view = try XCTUnwrap(s.view)
        XCTAssertEqual(view.round?.centersNeeded, 1)
        XCTAssertEqual(view.round?.boxAllowed, true)
        XCTAssertTrue(s.canOpenBox)
        let squares = (0..<view.board.count).map { Square(row: $0 / view.boardSize, col: $0 % view.boardSize) }
        if let owned = squares.first(where: { view.owner($0) != 0 }) {
            s.select(owned)
            XCTAssertTrue(s.preview.isEmpty, "مربع مملوك لا يُعاين بلا «ضع في أي مربع»")
        }
        let free = try XCTUnwrap(squares.first { view.owner($0) == 0 && !view.fortified.contains($0) })
        s.select(free)
        XCTAssertEqual(s.preview, [free])
        XCTAssertTrue(s.canCommit)
    }

    /// السؤال المعطوب في الحزمة يُستبعد ولا يجمّد التدريب (مراجعة M-04، المشكلة ٥).
    func testPackRejectsBrokenQuestions() {
        let good: [String: Any] = ["id": "a", "type": "mcq", "text": "س", "options": ["1", "2", "3", "4"], "correct": 2]
        XCTAssertTrue(TrainingPack.isValid(good))
        XCTAssertTrue(TrainingPack.isValid(["id": "b", "type": "truefalse", "text": "س", "correct": true]))
        var broken = good; broken["correct"] = 5
        XCTAssertFalse(TrainingPack.isValid(broken))
        broken = good; broken["correct"] = 0
        XCTAssertFalse(TrainingPack.isValid(broken))
        broken = good; broken["correct"] = true
        XCTAssertFalse(TrainingPack.isValid(broken))
        broken = good; broken["options"] = ["1", "1", "3", "4"]
        XCTAssertFalse(TrainingPack.isValid(broken))
        broken = good; broken["text"] = "  "
        XCTAssertFalse(TrainingPack.isValid(broken))
        XCTAssertFalse(TrainingPack.isValid(["id": "c", "type": "truefalse", "text": "س", "correct": 1]))
        // حزمة بأسئلة معطوبة كثيرة لا تكفي فتُرفض كلها، فيبقى التدريب على ما عنده
        let pack: [String: Any] = ["version": "x", "questions": Array(repeating: broken, count: 100)]
        XCTAssertNil(TrainingPack.parse(try! JSONSerialization.data(withJSONObject: pack)))
    }

    func testPreviewOnlyWhenChoosing() throws {
        let (s, _) = session(seed: 1)
        s.select(Square(row: 0, col: 0))
        XCTAssertTrue(s.preview.isEmpty, "لا معاينة خارج الاختيار")
        XCTAssertFalse(s.canCommit)
    }

    func testCorrectAnswerHiddenUntilAnswered() throws {
        let (s, clock) = session(seed: 3)
        clock.now += 3000
        s.advance(to: clock.now)
        let round = try XCTUnwrap(s.view?.round)
        XCTAssertNil(round.question.correct)
    }

    /// الجماعية (R-26): بعد كل دورتين، الجميع يجيب، ومن أجاب يُعلَّم بلا صوابه، ولا تُكشف الصحيحة حتى تنتهي.
    func testGroupRoundHidesCorrectnessUntilItEnds() throws {
        let (s, clock) = session(seed: 5)
        run(s, clock, group: false) { $0.canAnswerGroup }
        XCTAssertTrue(s.canAnswerGroup, "جولة جماعية في التدريب")
        let round = try XCTUnwrap(s.view?.round)
        XCTAssertTrue(round.isGroup)
        XCTAssertGreaterThanOrEqual(s.view?.cycle ?? 0, 2, "بعد دورتين")
        XCTAssertNil(round.question.correct)
        XCTAssertNil(round.groupAnswers)
        XCTAssertNil(round.winnerSeat)

        let mine = AutoPlay.firstChoice(round.question)
        s.answer(mine)
        XCTAssertFalse(s.canAnswerGroup, "إجابة واحدة لكل لاعب")
        if s.phase == "group" {
            XCTAssertEqual(s.view?.round?.myAnswer, mine)
            XCTAssertEqual(s.view?.round?.answeredSeats?.contains(TrainingSession.mySeat), true)
            XCTAssertNil(s.view?.round?.question.correct)
            XCTAssertNil(s.view?.round?.groupAnswers)
        }
        for _ in 0..<200 where s.phase == "group" {
            clock.now += 250
            s.advance(to: clock.now)
        }
        let over = try XCTUnwrap(s.view?.round)
        XCTAssertEqual(over.id, round.id)
        XCTAssertNotNil(over.question.correct, "تُكشف بعد انتهائها")
        XCTAssertEqual(over.groupAnswers?.first { $0.seatNo == TrainingSession.mySeat }?.choice, mine)
        XCTAssertNil(over.answeredSeats)
    }

    /// الصندوق (R-37): صندوقان للاعب، والآليون بلا صناديق، والكرت معلن على شارته.
    func testBoxGivesAnAnnouncedCard() throws {
        let (s, clock) = session(seed: 2)
        XCTAssertEqual(s.me?.boxesLeft, 2)
        XCTAssertEqual(s.view?.seats.filter(\.isBot).map(\.boxesLeft), [0, 0])
        run(s, clock, choose: false) { $0.isChooser }
        XCTAssertTrue(s.isChooser, "أصاب مرة على الأقل")
        s.openBox()
        XCTAssertFalse(s.failed)
        XCTAssertEqual(s.me?.boxesLeft, 1)
        XCTAssertEqual(s.me?.cards.count, 1)
        XCTAssertEqual(s.view?.round?.choice, "box")
        let card = try XCTUnwrap(s.me?.cards.first)
        XCTAssertEqual(s.view?.round?.boxCard?.type, card.type)
        XCTAssertNotNil(card.blocked, "المحرّك يقول لماذا لا يُلعب الآن")
        XCTAssertFalse(s.playability(card).ok, "لا يُلعب بعد انتهاء الاختيار")
        // والآلي لا يرى سبب كرتي، ولا أرى سبب كرت غيري
        XCTAssertTrue(s.view?.seats.filter(\.isBot).allSatisfy(\.cards.isEmpty) == true)
    }
}

/// صور شاشات المباراة من محرّك حقيقي، ليراها المالك والمراجع بلا ماك.
@MainActor
final class MatchSnapshotTests: XCTestCase {
    private let player = Player(id: "p", name: "أبو خليل", persona: Persona(expression: .confident, head: .shemagh, eye: .none, neck: .none))
    private var shots = Set<String>()

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func capture<V: View>(_ view: V, _ name: String, dark: Bool = true) async throws {
        let host = UIHostingController(rootView: view.appEnvironment(dark ? .dark : .light))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.rootViewController = host
        window.isHidden = false
        try await Task.sleep(for: .milliseconds(700))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("\(name).png"))
        window.isHidden = true
    }

    /// صورة واحدة لكل اسم.
    private func shot<V: View>(_ view: V, _ name: String) async throws {
        guard shots.insert(name).inserted else { return }
        try await capture(view, name)
    }

    /// يقدّم المباراة حتى يتحقّق الشرط.
    private func advance(_ s: TrainingSession, _ clock: TestClock, until done: (TrainingSession) -> Bool) {
        for _ in 0..<4000 where !done(s) {
            clock.now += 250
            s.advance(to: clock.now)
        }
    }

    func testMatchScreens() async throws {
        let clock = TestClock()
        let s = TrainingSession(setup: .init(size: 4, boardSize: 10), player: player, clock: { clock.now })
        s.start(seed: 11, runLoop: false)
        let screen = MatchScreen(session: s, onPlayAgain: {}, onExit: {})

        clock.now += 1200
        s.advance(to: clock.now)
        try await capture(screen, "M-countdown")

        // دور غيري أولاً إن وُجد، ثم دوري
        advance(s, clock) { $0.view?.phase.kind == "answering" && !$0.isMyTurn }
        try await capture(screen, "S-10-others-turn")

        advance(s, clock) { $0.view?.phase.kind == "answering" && $0.isMyTurn }
        try await capture(screen, "S-09-your-turn")

        // أجيب لأصل إلى الاختيار: الصحيحة لا يراها الجوال قبل الإجابة، فأجرّب حتى أصيب
        for _ in 0..<40 where !s.isChooser {
            if s.view?.phase.kind == "answering", s.isMyTurn, s.sentAnswer == nil, let q = s.view?.round?.question {
                s.answer(AutoPlay.firstChoice(q))
            }
            if s.myBurnWindow != nil { s.decideBurn(false) }
            advance(s, clock) { ($0.view?.phase.kind == "answering" && $0.isMyTurn && $0.sentAnswer == nil) || $0.isChooser || $0.myBurnWindow != nil || $0.phase == "ended" }
        }
        if s.isChooser {
            AutoPlay.selectSquares(s)
            try await capture(screen, "S-11-choose-preview")
            s.commit()
            try await capture(screen, "M-display-after-commit")
        }

        for _ in 0..<4000 where s.phase != "ended" {
            clock.now += 250
            s.advance(to: clock.now)
            AutoPlay.step(s)
        }
        try await capture(screen, "S-14-result-dark")
        try await capture(screen, "S-14-result-light", dark: false)

        try await capture(TrainingSetupView(player: player, onClose: {}), "S-16-training-setup")
    }

    /// شاشات M-05: الجماعية، والصندوق، ويد الكروت، والاستهداف، وكرت اللوح، ونافذة الحرق.
    /// الكرت من الصندوق بالقرعة، فتُجرَّب بذور حتى تظهر كلها؛ والناقص يُسجَّل في السجلّ لا يُسكت.
    func testCardAndGroupScreens() async throws {
        // بذور كثيرة: الحدّ الأعلى في سير العمل دقيقتان
        executionTimeAllowance = 120
        // «فلان يقرّر الحرق» لا تظهر في التدريب: الآليون بلا كروت، فلا نافذة إلا لي
        let wanted: Set = ["S-12-group", "S-12-group-answered", "S-11-choice", "M-box-opened", "M-cards-sheet",
                           "S-09-cards", "M-targeting", "S-11-board-card", "S-13-burn"]
        for seed in 1...40 where !shots.isSuperset(of: wanted) {
            let clock = TestClock()
            let s = TrainingSession(setup: .init(size: 3, boardSize: 9), player: player, clock: { clock.now })
            s.start(seed: seed, runLoop: false)
            let screen = MatchScreen(session: s, onPlayAgain: {}, onExit: {})
            for _ in 0..<6000 where s.phase != "ended" && !s.failed {
                clock.now += 250
                s.advance(to: clock.now)
                guard let round = s.view?.round else { continue }
                if s.myBurnWindow != nil {
                    try await shot(screen, "S-13-burn")
                    s.decideBurn(true)
                } else if s.canAnswerGroup {
                    try await shot(screen, "S-12-group")
                    s.answer(AutoPlay.firstChoice(round.question))
                    if s.phase == "group" { try await shot(screen, "S-12-group-answered") }
                } else if s.phase == "answering", s.isMyTurn, s.sentAnswer == nil, s.targeting == nil {
                    if let card = s.me?.cards.first(where: { s.playability($0).ok }) {
                        try await shot(screen, "S-09-cards")
                        try await shot(CardsSheet(session: s, onClose: {}), "M-cards-sheet")
                        s.play(card)
                        if s.targeting != nil {
                            target(s)
                            try await shot(screen, "M-targeting")
                            if s.targetReady { s.confirmTarget() } else { s.cancelTarget() }
                        }
                    }
                    if s.phase == "answering", s.sentAnswer == nil, let q = s.view?.round?.question {
                        s.answer(AutoPlay.firstChoice(q))
                    }
                } else if s.isChooser {
                    if (s.me?.boxesLeft ?? 0) > 0 {
                        try await shot(screen, "S-11-choice")
                        s.openBox()
                        try await shot(screen, "M-box-opened")
                    } else {
                        if s.view?.round?.boardCard == nil, let card = s.me?.cards.first(where: { s.playability($0).ok }) {
                            s.play(card)
                        }
                        AutoPlay.selectSquares(s)
                        if s.view?.round?.boardCard != nil { try await shot(screen, "S-11-board-card") }
                        s.commit()
                    }
                }
            }
            XCTAssertFalse(s.failed, "بذرة \(seed)")
        }
        let missing = wanted.subtracting(shots)
        if !missing.isEmpty { print("SNAPSHOTS-MISSING: \(missing.sorted())") }
        // ما لا يتوقّف على قرعة الكروت يلزم ظهوره
        for name in ["S-12-group", "S-11-choice", "M-box-opened", "M-cards-sheet"] {
            XCTAssertTrue(shots.contains(name), name)
        }
    }

    /// S-06 والمباراة أون لاين بعرض من المحرّك نفسه، ورد جاهز فوق شارة مرسله (M-06). بلا شبكة.
    func testOnlineScreens() async throws {
        let s = OnlineSession(endpoint: { try await Task.sleep(for: .seconds(3600)); throw URLError(.cancelled) })
        let screen = QuickMatchView(player: player, session: s, onClose: {})
        try await capture(screen, "S-06-choose")
        s.search(.four)
        try await capture(screen, "S-06-searching")

        // دور غيري: يتقدّم المحرّك حتى يجيب مقعد آخر
        let bridge = try EngineBridge()
        let pack = try XCTUnwrap(TrainingPack.current())
        let setup = """
        {"size":3,"boardSize":9,"seed":5,"player":{"displayName":"أبو خليل","persona":{"expression":"واثق","head":"شماغ","eye":"بلا","neck":"بلا"}},"questions":\(pack.questionsJSON)}
        """
        var out = try bridge.createTraining(setupJSON: setup, now: 1_000_000, viewer: 1)
        var t = 1_000_000.0
        while !(out.view.phase.kind == "answering" && out.view.round?.seatNo != 1), t < 1_200_000 {
            t += 500
            out = try bridge.tick(state: out.state, now: t, viewer: 1)
        }
        // ساعة الخادم = لحظة العرض، فيظهر المؤقّت كاملاً تقريباً
        let viewObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(out.view))
        s.receive(try JSONSerialization.data(withJSONObject: ["t": "state", "now": t, "seat": 1, "view": viewObject]))
        s.receive(try JSONSerialization.data(withJSONObject: ["t": "reply", "now": t, "seat": out.view.round?.seatNo ?? 2, "id": 0]))
        try await capture(screen, "S-10-online-replies")

        // M-07: منقطع على الشارة، والتوقّف، والنتيجة بطلب مباراة جديدة، وغطاء إعادة الاتصال
        var paused = out.view
        if let i = paused.seats.firstIndex(where: { !$0.isBot }) { paused.seats[i].away = true }
        paused.phase = PhaseView(kind: "paused", until: t + 120_000, deadline: nil, reason: nil, windows: nil)
        let pausedObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(paused))
        s.receive(try JSONSerialization.data(withJSONObject: ["t": "state", "now": t, "seat": 1, "view": pausedObject]))
        try await capture(screen, "M-paused")

        var ended = out.view
        ended.phase = PhaseView(kind: "ended", until: nil, deadline: nil, reason: "turnsDone", windows: nil)
        ended.ranking = ended.seats.enumerated().map { RankRow(seatNo: $1.seatNo, squares: 12 - $0 * 3, rank: $0 + 1) }
        let endedObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ended))
        s.receive(try JSONSerialization.data(withJSONObject: ["t": "state", "now": t, "seat": 1, "view": endedObject]))
        s.receive(try JSONSerialization.data(withJSONObject: ["t": "rematch", "now": t, "until": t + 20_000, "responses": [String: String]()]))
        try await capture(screen, "S-14-online-rematch")

        let r = OnlineSession(endpoint: { try await Task.sleep(for: .seconds(3600)); throw URLError(.cancelled) },
                              defaults: UserDefaults(suiteName: "snap-\(UUID().uuidString)")!)
        r.rejoin("x")
        try await capture(QuickMatchView(player: player, session: r, onClose: {}), "M-reconnecting")
    }

    /// يختار هدف الكرت: مربعات مملوكة لغيري للتفريغ، ومركز اللوح للتحصين.
    private func target(_ s: TrainingSession) {
        guard let view = s.view else { return }
        let all = (0..<view.board.count).map { Square(row: $0 / view.boardSize, col: $0 % view.boardSize) }
        switch s.targeting {
        case .clear(_, let count, _):
            let owned = all.filter { view.owner($0) != 0 && !view.fortified.contains($0) }
            let others = owned.filter { view.owner($0) != TrainingSession.mySeat }
            let mine = owned.filter { view.owner($0) == TrainingSession.mySeat }
            for square in (others + mine).prefix(count) { s.select(square) }
        case .fortify:
            s.select(Square(row: view.boardSize / 2, col: view.boardSize / 2))
        case nil:
            break
        }
    }
}
