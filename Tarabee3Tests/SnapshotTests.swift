import SwiftUI
import UIKit
import XCTest
@testable import Tarabee3

/// صور للشاشات والأفاتار تُرفع من قِت هب ليراها المالك والمراجع بلا ماك. لا تقارن بصورة مرجعية: تثبت أن الرسم
/// يجري بلا عطل، وتُنتج ما يُنظر إليه. المجلد من SNAPSHOT_DIR (TEST_RUNNER_SNAPSHOT_DIR في xcodebuild).
@MainActor
final class SnapshotTests: XCTestCase {
    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ image: UIImage, _ name: String) throws {
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: directory.appendingPathComponent("\(name).png"))
    }

    /// يعرض الشاشة في نافذة حقيقية ثم يلتقطها، فتظهر الحقول والتمرير كما على الجوال.
    private func screen<V: View>(
        _ view: V, _ name: String, scheme: ColorScheme, width: CGFloat = 393, height: CGFloat = 852
    ) throws {
        let appearance: Appearance = scheme == .dark ? .dark : .light
        let host = UIHostingController(rootView: view.appEnvironment(appearance))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try write(image, name)
        window.isHidden = true
    }

    func testFontIsRegistered() {
        XCTAssertNotNil(UIFont(name: "ReadexPro-Regular", size: 16), "خط ريديكس برو لم يُسجَّل في التطبيق")
    }

    func testFirstOpenScreen() async throws {
        let store = ProfileStore(backend: FakeBackend())
        await store.start()
        try screen(FirstOpenView(store: store), "S-01-first-open-dark", scheme: .dark)
        try screen(FirstOpenView(store: store), "S-01-first-open-light", scheme: .light)
        try screen(FirstOpenView(store: store), "S-01-first-open-375", scheme: .dark, width: 375, height: 667)
    }

    func testHomeScreen() async throws {
        let fresh = Player(id: "p", name: "أبو خليل",
                           persona: Persona(expression: .confident, head: .shemagh, eye: .none, neck: .none))
        let played = Player(id: "p", name: "Saad سعد", persona: .default, matchesPlayed: 14, wins: 5)
        let store = ProfileStore(backend: FakeBackend(player: fresh))
        await store.start()
        try screen(HomeView(store: store, player: fresh), "S-02-home-empty-dark", scheme: .dark)
        try screen(HomeView(store: store, player: played), "S-02-home-stats-light", scheme: .light)
    }

    func testSettingsScreen() async throws {
        let player = Player(id: "p", name: "أبو خليل",
                            persona: Persona(expression: .wink, head: .cap, eye: .glasses, neck: .shawl))
        let store = ProfileStore(backend: FakeBackend(player: player))
        await store.start()
        try screen(SettingsView(store: store, player: player), "S-03-settings-dark", scheme: .dark, height: 1400)
        try screen(SettingsView(store: store, player: player), "S-03-settings-light", scheme: .light, height: 1400)
    }

    /// كل التعابير، وكل التلبيسات، والمقاعد الخمسة، والمبسّط تحت ٢٤، والشماغ المبسّط تحت ٤٠.
    func testAvatarSheet() throws {
        func plain(_ expression: FaceExpression) -> Persona { Persona(expression: expression, head: .none, eye: .none, neck: .none) }
        let sheet = VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Array(FaceExpression.allCases.prefix(6)), id: \.self) { AvatarView(team: .team1, persona: plain($0), side: 80) }
            }
            HStack(spacing: 8) {
                ForEach(Array(FaceExpression.allCases.suffix(6)), id: \.self) { AvatarView(team: .team1, persona: plain($0), side: 80) }
            }
            HStack(spacing: 8) {
                ForEach(HeadOutfit.allCases, id: \.self) {
                    AvatarView(team: .team4, persona: Persona(expression: .smile, head: $0, eye: .none, neck: .none), side: 80)
                }
                AvatarView(team: .team5, persona: Persona(expression: .smile, head: .none, eye: .glasses, neck: .none), side: 80)
                AvatarView(team: .team5, persona: Persona(expression: .wink, head: .none, eye: .eyepatch, neck: .shawl), side: 80)
            }
            HStack(spacing: 8) {
                ForEach(Team.allCases, id: \.self) {
                    AvatarView(team: $0, persona: Persona(expression: .excited, head: .shemagh, eye: .none, neck: .none), side: 80)
                }
                AvatarView(team: .team2, persona: .default, side: 20)
                AvatarView(team: .team1, persona: Persona(expression: .smile, head: .shemagh, eye: .none, neck: .none), side: 36)
            }
        }
        .padding(16)
        .background(Palette.dark.ground)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        try write(try XCTUnwrap(renderer.uiImage), "avatar-sheet")
    }
}
