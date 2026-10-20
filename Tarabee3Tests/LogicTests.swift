import SwiftUI
import XCTest
@testable import Tarabee3

final class NameRuleTests: XCTestCase {
    func testLengthBounds() {
        XCTAssertFalse(NameRule.isValidLength("ع"))
        XCTAssertTrue(NameRule.isValidLength("عز"))
        XCTAssertTrue(NameRule.isValidLength("ابجدهوزحطيكل")) // ١٢
        XCTAssertFalse(NameRule.isValidLength("ابجدهوزحطيكلم")) // ١٣
    }

    func testSpacesNormalizedLikeServer() {
        XCTAssertEqual(NameRule.normalized("   أبو    خليل  "), "أبو خليل")
        XCTAssertFalse(NameRule.isValidLength("      "))
    }

    func testGraphemeClusterCountsAsOne() {
        XCTAssertFalse(NameRule.isValidLength("👨‍👩‍👧"))
    }
}

final class PersonaTests: XCTestCase {
    /// القيم كما يقبلها الخادم (server/src/persona.ts) — تغيّرها في جانب وحده يكسر الحفظ.
    func testRawValuesMatchServer() {
        XCTAssertEqual(Expression.allCases.map(\.rawValue), [
            "مبتسم", "غامز", "غاضب", "مندهش", "نعسان", "مُخرج لسانه",
            "عيون نجوم", "واثق", "ضاحك", "متحمّس", "خجول", "مفكّر",
        ])
        XCTAssertEqual(HeadOutfit.allCases.map(\.rawValue), ["بلا", "شماغ", "طاقية", "كاب"])
        XCTAssertEqual(EyeOutfit.allCases.map(\.rawValue), ["بلا", "نظارة", "عين القرصان"])
        XCTAssertEqual(NeckOutfit.allCases.map(\.rawValue), ["بلا", "شال"])
    }

    func testSpokenLabel() {
        XCTAssertEqual(Persona.default.spokenLabel(team: .team1), "مربع أحمر مبتسم")
        let dressed = Persona(expression: .wink, head: .shemagh, eye: .glasses, neck: .shawl)
        XCTAssertEqual(dressed.spokenLabel(team: .team4), "مربع أزرق غامز بشماغ ونظارة وشال")
    }

    func testPlayerFromFieldsToleratesUnknownValues() {
        let player = Player(id: "p", fields: ["name": "سعد", "expression": "مجهول", "wins": NSNumber(value: 3)])
        XCTAssertEqual(player.persona.expression, .smile)
        XCTAssertEqual(player.wins, 3)
        XCTAssertEqual(player.matchesPlayed, 0)
    }
}

final class AvatarArtTests: XCTestCase {
    func testSvgPathParsesAbsoluteCommands() {
        let box = svgPath("M36 66Q50 78 64 66").boundingRect
        XCTAssertEqual(box.minX, 36, accuracy: 0.01)
        XCTAssertEqual(box.maxX, 64, accuracy: 0.01)
        XCTAssertEqual(svgPath("M-5 -1Q50 -12 105 -1").boundingRect.minX, -5, accuracy: 0.01)
        XCTAssertEqual(svgPath("M48 44Q50 41 52 44M18 44L0 40M82 44L100 40").boundingRect.width, 100, accuracy: 0.01)
    }

    func testEveryExpressionDrawsAFace() {
        for expression in Expression.allCases {
            let persona = Persona(expression: expression, head: .none, eye: .none, neck: .none)
            let drawing = drawAvatar(team: .team1, persona: persona, side: 120)
            XCTAssertEqual(drawing.shapes.first?.part, "body", "\(expression)")
            XCTAssertTrue(drawing.shapes.contains { $0.part.hasPrefix("eye") || $0.part == "pupil" }, "\(expression)")
        }
    }

    func testEyePatchHidesTheWinkingEye() {
        let persona = Persona(expression: .smile, head: .none, eye: .eyepatch, neck: .none)
        let drawing = drawAvatar(team: .team1, persona: persona, side: 120)
        XCTAssertEqual(drawing.shapes.filter { $0.part == "eye-white" }.count, 1)
        XCTAssertTrue(drawing.shapes.contains { $0.part == "eye-patch" })
    }

    func testSmallAvatarIsSimplified() {
        let persona = Persona(expression: .smile, head: .shemagh, eye: .glasses, neck: .shawl)
        let drawing = drawAvatar(team: .team1, persona: persona, side: 20)
        XCTAssertEqual(drawing.view, AvatarGeometry.simpleView)
        XCTAssertFalse(drawing.shapes.contains { $0.part.hasPrefix("head") || $0.part == "shine" })
    }

    func testEyeOutlineOnLightTeams() {
        XCTAssertFalse(eyeOutlined(.team1))
        XCTAssertTrue(eyeOutlined(.team2))
        XCTAssertTrue(eyeOutlined(.team3))
    }

    func testBlinkClosesOpenEyesOnly() {
        let open = drawAvatar(team: .team1, persona: .default, side: 120, blink: true)
        XCTAssertFalse(open.shapes.contains { $0.part == "eye-white" })
        let starsPersona = Persona(expression: .starEyes, head: .none, eye: .none, neck: .none)
        let stars = drawAvatar(team: .team1, persona: starsPersona, side: 120, blink: true)
        XCTAssertTrue(stars.shapes.contains { $0.part == "eye-star" })
    }
}

@MainActor
final class ProfileStoreTests: XCTestCase {
    func testFirstOpenThenSaveThenDelete() async throws {
        let backend = FakeBackend()
        let store = ProfileStore(backend: backend)
        await store.start()
        XCTAssertEqual(store.phase, .firstOpen)

        try await store.save(name: "  أبو   خليل ", persona: .default)
        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(backend.savedNames, ["أبو خليل"])

        try await store.deleteAccount()
        XCTAssertEqual(backend.deletions, 1)
        XCTAssertEqual(store.phase, .firstOpen)
        XCTAssertNil(store.player)
    }

    func testShortNameNeverReachesServer() async {
        let backend = FakeBackend()
        let store = ProfileStore(backend: backend)
        await store.start()
        do {
            try await store.save(name: "س", persona: .default)
            XCTFail("يجب أن يُرفض")
        } catch {
            XCTAssertEqual(error, .nameLength)
        }
        XCTAssertTrue(backend.savedNames.isEmpty)
    }

    func testUnavailableNameKeepsFirstOpen() async {
        let backend = FakeBackend()
        backend.saveError = .nameUnavailable
        let store = ProfileStore(backend: backend)
        await store.start()
        do {
            try await store.save(name: "كلب", persona: .default)
            XCTFail("يجب أن يُرفض")
        } catch {
            XCTAssertEqual(error, .nameUnavailable)
        }
        XCTAssertEqual(store.phase, .firstOpen)
    }

    func testNoBackendMeansNotConfigured() async {
        let store = ProfileStore(backend: nil)
        await store.start()
        XCTAssertEqual(store.phase, .notConfigured)
    }
}
