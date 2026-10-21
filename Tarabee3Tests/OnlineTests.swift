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
        XCTAssertEqual(s.now, local + 60_000, accuracy: 1000)
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

    func testFailureMessagesAndSearchState() throws {
        let s = session()
        s.search(.four)
        guard case .searching(let until) = s.stage else { return XCTFail("يبحث") }
        XCTAssertEqual(until, s.now + 30_000, accuracy: 1000)
        s.receive(message(["t": "failed", "now": 1, "reason": "no_questions"]))
        XCTAssertEqual(s.failureText, Copy.Online.noQuestions)
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
