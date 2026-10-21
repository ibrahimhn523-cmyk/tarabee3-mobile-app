import SwiftUI
import XCTest
@testable import Tarabee3

/// المباراة السريعة على الجوال (M-06): رسائل الخادم كما تصل، بلا شبكة. العرض من المحرّك المشحون نفسه،
/// كما يرسله كائن المباراة (view لمقعد بعينه).
@MainActor
final class OnlineTests: XCTestCase {
    private let player = Player(id: "p", name: "أبو خليل", persona: Persona(expression: .confident, head: .shemagh, eye: .none, neck: .none))

    /// عرض حقيقي من المحرّك بعد «استعدّ»: أول دور.
    private func engineView(after ms: Double = 3500) throws -> MatchView {
        let bridge = try EngineBridge()
        let pack = try XCTUnwrap(TrainingPack.current())
        let setup = """
        {"size":3,"boardSize":9,"seed":5,"player":{"displayName":"أبو خليل","persona":{"expression":"واثق","head":"شماغ","eye":"بلا","neck":"بلا"}},"questions":\(pack.questionsJSON)}
        """
        let created = try bridge.createTraining(setupJSON: setup, now: 1_000_000, viewer: 1)
        return try bridge.tick(state: created.state, now: 1_000_000 + ms, viewer: 1).view
    }

    private func message(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private func stateMessage(_ view: MatchView, now: Double, seat: Int = 1) throws -> Data {
        let viewObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(view))
        return message(["t": "state", "now": now, "seat": seat, "view": viewObject])
    }

    /// جلسة لا تتصل: الخلفية لا تردّ، فيبقى البحث قائماً.
    private func session() -> OnlineSession {
        OnlineSession(endpoint: { try await Task.sleep(for: .seconds(3600)); throw URLError(.cancelled) })
    }

    func testServerClockDrivesTheTimer() throws {
        let s = session()
        let local = Date().timeIntervalSince1970 * 1000
        try s.receive(stateMessage(engineView(), now: local + 60_000))
        // «استعدّ» والمؤقّت بساعة الخادم: الفرق محسوب من الرسالة (R-68)
        // ربع ثانية حدّاً (04-tech §٢)
        XCTAssertEqual(s.now, local + 60_000, accuracy: 250)
        // رسالة متأخّرة في الشبكة (ساعتها أقدم) لا تُرجع العدّاد
        let before = s.now
        s.receive(message(["t": "rejected", "now": Date().timeIntervalSince1970 * 1000 + 60_000 - 3000, "reason": "x"]))
        XCTAssertGreaterThanOrEqual(s.now, before)
        XCTAssertEqual(s.stage, .playing)
        XCTAssertEqual(s.mySeat, 1)
        XCTAssertTrue(s.filledWithBots, "مقعدان آليان")
    }

    func testRequestsAreTheServerProtocol() throws {
        let s = session()
        try s.receive(stateMessage(engineView(), now: Date().timeIntervalSince1970 * 1000))
        var sent: [String] = []
        s.onSend = { sent.append($0) }
        s.send(.answer(.option(2)))
        s.send(.answer(.truth(false)))
        s.send(.choose([Square(row: 1, col: 2)]))
        s.send(.openBox)
        s.send(.card(id: 3, cells: [], center: Square(row: 4, col: 4)))
        s.send(.burn(true))
        XCTAssertEqual(sent, [
            #"{"choice":2,"t":"answer"}"#,
            #"{"choice":false,"t":"answer"}"#,
            #"{"pick":{"centers":[{"col":2,"row":1}],"kind":"square"},"t":"choose"}"#,
            #"{"pick":{"kind":"box"},"t":"choose"}"#,
            #"{"id":3,"t":"card","target":{"cells":[],"center":{"col":4,"row":4}}}"#,
            #"{"burn":true,"t":"burn"}"#,
        ])
    }

    func testRepliesShowAndLockForThreeSeconds() throws {
        let s = session()
        let now = Date().timeIntervalSince1970 * 1000
        try s.receive(stateMessage(engineView(), now: now))
        var sent: [String] = []
        s.onSend = { sent.append($0) }
        XCTAssertTrue(s.canReply)
        s.sendReply(2)
        XCTAssertFalse(s.canReply, "مقفلة ثلاث ثوانٍ")
        s.sendReply(3)
        XCTAssertEqual(sent, [#"{"id":2,"t":"reply"}"#])
        s.receive(message(["t": "reply", "now": now, "seat": 2, "id": 4]))
        XCTAssertEqual(s.replies.last?.seat, 2)
        XCTAssertEqual(s.replies.last?.reply, 4)
        XCTAssertEqual(Copy.Online.reply(4), Copy.Online.replies[4])
    }

    func testSecondAnswerRejectionIsShown() throws {
        let s = session()
        try s.receive(stateMessage(engineView(), now: Date().timeIntervalSince1970 * 1000))
        s.receive(message(["t": "rejected", "now": 1, "reason": "already_answered"]))
        XCTAssertEqual(s.lastRejection, "already_answered")
    }

    /// «matched» يترك اتصال المطابقة فوراً: إغلاقه بعدها ليس انقطاعاً (مراجعة M-06، المشكلة ٣).
    func testMatchedIsNotADisconnect() throws {
        let s = session()
        s.search(.three)
        s.receive(message(["t": "matched", "now": Date().timeIntervalSince1970 * 1000, "matchId": String(repeating: "a", count: 64)]))
        XCTAssertNil(s.failureText)
        if case .searching = s.stage {} else { XCTFail("ما زال ينتظر عرض المباراة") }
    }

    func testFailureMessagesAndSearchState() throws {
        let s = session()
        s.search(.four)
        guard case .searching(let until) = s.stage else { return XCTFail("يبحث") }
        XCTAssertEqual(until, s.now + 30_000, accuracy: 1000)
        s.receive(message(["t": "failed", "now": 1, "reason": "no_questions"]))
        XCTAssertEqual(s.failureText, Copy.Online.noQuestions)
    }

    /// الانتهاء والإعادة (M-07): عرض منتهٍ مصنوع من عرض المحرّك.
    private func endedView() throws -> MatchView {
        var view = try engineView()
        view.phase = PhaseView(kind: "ended", until: nil, deadline: nil, reason: "turnsDone", windows: nil)
        view.ranking = view.seats.enumerated().map { RankRow(seatNo: $1.seatNo, squares: 10 - $0, rank: $0 + 1) }
        return view
    }

    private func defaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "tarabee3-tests-\(UUID().uuidString)")!
        return d
    }

    func testRematchAskThenGo() throws {
        let d = defaults()
        let s = OnlineSession(endpoint: { try await Task.sleep(for: .seconds(3600)); throw URLError(.cancelled) }, defaults: d)
        let now = Date().timeIntervalSince1970 * 1000
        try s.receive(stateMessage(endedView(), now: now))
        s.receive(message(["t": "rematch", "now": now, "until": now + 20_000, "responses": [String: String]()]))
        XCTAssertEqual(s.rematch?.until ?? 0, now + 20_000, accuracy: 1)
        var sent: [String] = []
        s.onSend = { sent.append($0) }
        s.respondRematch(true)
        s.respondRematch(false)
        XCTAssertEqual(sent, [#"{"accept":true,"t":"rematch"}"#], "ردّ واحد")
        XCTAssertEqual(s.rematch?.mine, true)
        // حُسم: يذهب للمطابقة بحجمها، ومكان من لم يوافق يُبحث له
        s.receive(message(["t": "rematch", "now": now, "until": now + 20_000, "responses": ["1": "accepted", "2": "declined"],
                           "go": true, "size": 3, "previousMatchId": String(repeating: "c", count: 64)]))
        guard case .searching(let until) = s.stage else { return XCTFail("يبحث عن بدلاء") }
        XCTAssertEqual(until, s.now + 20_000, accuracy: 1000)
        XCTAssertEqual(s.replacing.count, 0, "الآخران آليان في عرض المحرّك")
    }

    func testRematchClosedForDeclined() throws {
        let s = session()
        let now = Date().timeIntervalSince1970 * 1000
        try s.receive(stateMessage(endedView(), now: now))
        s.receive(message(["t": "rematch", "now": now, "until": now + 20_000, "responses": ["1": "declined"], "go": false]))
        XCTAssertEqual(s.rematch?.closed, true)
        XCTAssertEqual(s.rematch?.mine, false)
    }

    func testWithdrawSendsAndForgetsTheMatch() throws {
        let d = defaults()
        let s = OnlineSession(endpoint: { try await Task.sleep(for: .seconds(3600)); throw URLError(.cancelled) }, defaults: d)
        s.search(.three)
        s.receive(message(["t": "matched", "now": Date().timeIntervalSince1970 * 1000, "matchId": String(repeating: "a", count: 64)]))
        XCTAssertEqual(d.string(forKey: OnlineSession.currentMatchKey), String(repeating: "a", count: 64), "يُحفظ ليعود إليه")
        try s.receive(stateMessage(engineView(), now: Date().timeIntervalSince1970 * 1000))
        var sent: [String] = []
        s.onSend = { sent.append($0) }
        s.withdraw()
        XCTAssertEqual(sent, [#"{"t":"withdraw"}"#])
        XCTAssertEqual(s.stage, .idle)
        XCTAssertNil(d.string(forKey: OnlineSession.currentMatchKey))
    }

    func testReturnAfterTheEndSaysItWasCounted() throws {
        let d = defaults()
        d.set("x", forKey: OnlineSession.currentMatchKey)
        let s = OnlineSession(endpoint: { try await Task.sleep(for: .seconds(3600)); throw URLError(.cancelled) }, defaults: d)
        s.rejoin("x")
        XCTAssertTrue(s.reconnecting)
        try s.receive(stateMessage(endedView(), now: Date().timeIntervalSince1970 * 1000))
        XCTAssertFalse(s.reconnecting)
        XCTAssertTrue(s.endedWhileAway)
        XCTAssertGreaterThan(s.reconnectedUntil, s.now)
        XCTAssertNil(d.string(forKey: OnlineSession.currentMatchKey), "انتهت: لا عودة إليها")
    }

    func testChooserSelectsOnlyWhatTheServerAllows() throws {
        // عرض اختيار مصنوع من عرض المحرّك: المربع ٠ مسموح وحده
        var view = try engineView()
        view.phase = PhaseView(kind: "choosing", until: nil, deadline: (view.round?.deadline ?? 0) + 20_000, reason: nil, windows: nil)
        view.round?.chooser = 1
        view.round?.result = "correct"
        view.round?.centersNeeded = 1
        view.targets = TargetsView(centers: [0], clear: nil)
        let s = session()
        try s.receive(stateMessage(view, now: Date().timeIntervalSince1970 * 1000))
        XCTAssertTrue(s.isChooser)
        s.select(Square(row: 0, col: 1))
        XCTAssertTrue(s.preview.isEmpty, "غير مسموح من الخادم")
        s.select(Square(row: 0, col: 0))
        XCTAssertEqual(s.preview, [Square(row: 0, col: 0)])
        XCTAssertTrue(s.canCommit)
    }
}
