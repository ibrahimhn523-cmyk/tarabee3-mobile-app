import SwiftUI

/// S-16 · إعداد التدريب: الحجم واللوح، واللوح يُقترح بالحجم (R-08، القرار 0010)، ثم «ابدأ» ثابت أسفلها (05-ui §١٣).
/// بلا إنترنت ولا احتساب في الملف (R-45).
struct TrainingSetupView: View {
    let player: Player
    var onClose: () -> Void

    @State private var size = 3
    @State private var boardSize = 9
    @State private var boardTouched = false
    @State private var session: TrainingSession?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        Group {
            if let session {
                MatchScreen(session: session, onPlayAgain: { restart() }, onExit: { session.stop(); onClose() })
            } else {
                VStack(alignment: .leading, spacing: Space.s(5)) {
                    HStack {
                        Text(Copy.Training.title).font(.app(.h1, .bold)).foregroundStyle(palette.text)
                        Spacer()
                        Button(action: onClose) {
                            Image("icon-x").resizable().frame(width: IconSize.medium, height: IconSize.medium)
                                .foregroundStyle(palette.text).frame(width: Touch.min, height: Touch.min)
                        }
                        .accessibilityLabel(Copy.Settings.close)
                    }
                    Text(Copy.Training.line).font(.app(.body)).foregroundStyle(palette.textMuted)
                    Spacer()
                    picker(Copy.Training.size, [(3, Copy.Training.three), (4, Copy.Training.four), (5, Copy.Training.five)], $size)
                        .onChange(of: size) { if !boardTouched { boardSize = suggested(size) } }
                    picker(Copy.Training.board, [(9, "9×9"), (10, "10×10"), (11, "11×11")],
                           Binding(get: { boardSize }, set: { boardSize = $0; boardTouched = true }))
                    Spacer()
                    if TrainingPack.current() == nil {
                        StatusBanner(kind: .info, text: Copy.Match.packMissing)
                    }
                    Button(Copy.Training.start) { begin() }
                        .appButton(.primary)
                        .disabled(TrainingPack.current() == nil)
                }
                .padding(Space.s(3))
                .appBackground()
            }
        }
    }

    private func picker(_ title: String, _ options: [(Int, String)], _ selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: Space.s(1)) {
            Text(title).font(.app(.small, .medium)).foregroundStyle(Palette.of(scheme).textMuted)
            SplitPicker(options: options, selection: selection)
        }
    }

    /// اللوح المقترح بالحجم، من المحرّك.
    private func suggested(_ size: Int) -> Int { TrainingSession.suggestedBoard(size: size) }

    private func begin() {
        let s = TrainingSession(setup: .init(size: size, boardSize: boardSize), player: player)
        session = s
        s.start()
    }

    private func restart() {
        session?.stop()
        begin()
    }
}
