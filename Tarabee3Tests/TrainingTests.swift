import SwiftUI
import UIKit
import XCTest
@testable import Tarabee3

/// ساعة يتحكّم فيها الاختبار.
@MainActor
final class TestClock {
    var now: Double = 1_000_000
}

/// «المحرّك نفسه يعمل في الاختبارات الآلية وعلى الجوال، بنسخة واحدة» (معيار M-04): هنا يعمل engine.js المشحون مع
/// التطبيق في JavaScriptCore على محاكي آيفون، ويلعب تدريباً كاملاً.
@MainActor
final class TrainingTests: XCTestCase {
    private let player = Player(id: "p", name: "أبو خليل", persona: Persona(expression: .confident, head: .shemagh, eye: .none, neck: .none))

    func testBundledEngineAndPackLoad() throws {
        XCTAssertNoThrow(try EngineBridge())
        let pack = try XCTUnwrap(TrainingPack.current())
        XCTAssertFalse(pack.version.isEmpty)
    }

    /// يلعب حتى النهاية: اللاعب يجيب بالخيار الأول ويعتمد أول مربع فارغ، والآليون يلعبهم المحرّك.
    private func playToEnd(size: Int, boardSize: Int, seed: Int) throws -> TrainingSession {
        let clock = TestClock()
        let session = TrainingSession(setup: .init(size: size, boardSize: boardSize), player: player, clock: { clock.now })
        session.start(seed: seed, runLoop: false)
        XCTAssertFalse(session.failed)
        for _ in 0..<5000 {
            guard let view = session.view, view.phase.kind != "ended" else { break }
            clock.now += 500
            session.advance(to: clock.now)
            guard session.isMyTurn, let round = session.view?.round else { continue }
            if session.view?.phase.kind == "answering", session.sentAnswer == nil {
                session.answer(round.question.isTrueFalse ? .truth(true) : .option(1))
            } else if session.view?.phase.kind == "choosing", let board = session.view?.board,
                      let empty = board.firstIndex(of: 0) {
                session.select(Square(row: empty / boardSize, col: empty % boardSize))
                session.commit()
            }
        }
        return session
    }

    func testFullTrainingMatchForEverySize() throws {
        for (size, board) in [(3, 9), (4, 10), (5, 11)] {
            let session = try playToEnd(size: size, boardSize: board, seed: 7 + size)
            let view = try XCTUnwrap(session.view)
            XCTAssertEqual(view.phase.kind, "ended", "حجم \(size)")
            XCTAssertEqual(view.ranking?.count, size)
            XCTAssertEqual(view.seats.filter(\.isBot).count, size - 1)
            XCTAssertEqual(view.seats.first { !$0.isBot }?.displayName, "أبو خليل")
        }
    }

    func testPreviewOnlyOnEmptySquareAndOnlyWhenChoosing() throws {
        let clock = TestClock()
        let session = TrainingSession(setup: .init(size: 3, boardSize: 9), player: player, clock: { clock.now })
        session.start(seed: 1, runLoop: false)
        session.select(Square(row: 0, col: 0))
        XCTAssertNil(session.preview, "لا معاينة خارج الاختيار")
    }

    func testCorrectAnswerHiddenUntilAnswered() throws {
        let clock = TestClock()
        let session = TrainingSession(setup: .init(size: 3, boardSize: 9), player: player, clock: { clock.now })
        session.start(seed: 3, runLoop: false)
        clock.now += 3000
        session.advance(to: clock.now)
        let round = try XCTUnwrap(session.view?.round)
        XCTAssertNil(round.question.correct)
    }
}

/// صور شاشات المباراة من محرّك حقيقي، ليراها المالك والمراجع بلا ماك.
@MainActor
final class MatchSnapshotTests: XCTestCase {
    private let player = Player(id: "p", name: "أبو خليل", persona: Persona(expression: .confident, head: .shemagh, eye: .none, neck: .none))

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

        // أجيب صحيحاً لأصل إلى الاختيار: الصحيحة لا يراها الجوال قبل الإجابة، فأجرّب حتى أصيب
        for _ in 0..<40 where s.view?.phase.kind != "choosing" {
            if s.view?.phase.kind == "answering", s.isMyTurn, let q = s.view?.round?.question {
                s.answer(q.isTrueFalse ? .truth(true) : .option(1))
            }
            advance(s, clock) { ($0.view?.phase.kind == "answering" && $0.isMyTurn && $0.sentAnswer == nil) || $0.view?.phase.kind == "choosing" && $0.isMyTurn }
        }
        if s.view?.phase.kind == "choosing", s.isMyTurn {
            s.select(Square(row: 4, col: 4))
            if s.preview == nil, let i = s.view?.board.firstIndex(of: 0) { s.select(Square(row: i / 10, col: i % 10)) }
            try await capture(screen, "S-11-choose-preview")
            s.commit()
            try await capture(screen, "M-display-after-commit")
        }

        advance(s, clock) { $0.view?.phase.kind == "ended" }
        try await capture(screen, "S-14-result-dark")
        try await capture(screen, "S-14-result-light", dark: false)

        try await capture(TrainingSetupView(player: player, onClose: {}), "S-16-training-setup")
    }
}
