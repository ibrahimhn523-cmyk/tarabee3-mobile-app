import SwiftUI

/// S-06 · انتظار المباراة السريعة (R-06، R-07): الحجم، ثم العدّاد أعلاها، والمقاعد عموداً، و«إلغاء» ثابت أسفلها
/// (05-ui §١٣). وعند البدء تنتقل لشاشات المباراة نفسها التي في التدريب (القرار 0019).
struct QuickMatchView: View {
    let player: Player
    let session: OnlineSession
    var onClose: () -> Void

    @State private var size: SizePref = .any
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        Group {
            switch session.stage {
            case .idle:
                choose(palette)
            case .searching(let until):
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in searching(until: until, palette) }
            case .failed(let text):
                VStack(spacing: Space.s(4)) {
                    Spacer()
                    StatusBanner(kind: .error, text: text)
                    Spacer()
                    Button(Copy.Match.home, action: close).appButton(.secondary)
                }
                .padding(Space.s(3))
            case .playing:
                MatchScreen(session: session, onPlayAgain: { session.search(size) }, onExit: close)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }

    private func close() {
        session.cancel()
        onClose()
    }

    private func choose(_ palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: Space.s(4)) {
            HStack {
                Text(Copy.Online.title).font(.app(.h1, .bold)).foregroundStyle(palette.text)
                Spacer()
                Button(action: close) {
                    Image("icon-x").resizable().frame(width: IconSize.small, height: IconSize.small)
                        .foregroundStyle(palette.textMuted).frame(width: Touch.min, height: Touch.min)
                }
                .accessibilityLabel(Copy.Settings.close)
            }
            Text(Copy.Online.line).font(.app(.body)).foregroundStyle(palette.textMuted)
            Text(Copy.Training.size).font(.app(.small, .bold)).foregroundStyle(palette.text)
            SplitPicker(options: [(SizePref.any, Copy.Online.anySize), (.three, Copy.Training.three), (.four, Copy.Training.four), (.five, Copy.Training.five)], selection: $size)
            Spacer()
            Button(Copy.Online.search) { session.search(size) }.appButton(.primary)
        }
        .padding(Space.s(3))
    }

    private func searching(until: Double, _ palette: Palette) -> some View {
        let seats = size == .any ? 3 : Int(size.rawValue) ?? 3
        return VStack(spacing: Space.s(3)) {
            Text(Copy.Online.searching).font(.app(.h2, .bold)).foregroundStyle(palette.text)
            TimerView(deadline: until, total: 30_000, now: session.now)
            VStack(spacing: Space.s(2)) {
                WaitingSlot(name: player.name, persona: player.persona, team: .team1)
                ForEach(1..<seats, id: \.self) { _ in WaitingSlot(name: nil, persona: nil, team: .team1) }
            }
            // بعد الإعادة: نبحث عن بدلاء من رفض أو سكت (R-35)
            ForEach(session.replacing, id: \.self) { name in
                Text(Copy.Online.replacing("\u{2068}\(name)\u{2069}")).font(.app(.small)).foregroundStyle(palette.textMuted)
            }
            Text(Copy.Online.botsAfter).font(.app(.small)).foregroundStyle(palette.textMuted)
            Spacer()
            Button(Copy.Settings.cancel, action: close).appButton(.secondary)
        }
        .padding(Space.s(3))
    }
}

/// خانة المقعد في الانتظار (05-ui §٦): أفاتار ٤٠ والاسم وشريط اللون؛ الفارغة بحدّ منقّط و«نبحث…».
struct WaitingSlot: View {
    let name: String?
    let persona: Persona?
    let team: Team
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        HStack(spacing: Space.s(2)) {
            if let name, let persona {
                AvatarView(team: team, persona: persona, side: 40)
                Text(verbatim: "\u{2068}\(name)\u{2069}").font(.app(.body, .medium)).foregroundStyle(palette.text)
            } else {
                RoundedRectangle(cornerRadius: Radius.control).strokeBorder(palette.textMuted, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 40, height: 40)
                Text(Copy.Online.searchingSlot).font(.app(.body)).foregroundStyle(palette.textMuted)
            }
            Spacer()
        }
        .padding(Space.s(2))
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(alignment: .bottom) {
            if name != nil { Capsule().fill(team.flat).frame(height: 3).padding(.horizontal, Space.s(2)) }
        }
        .accessibilityElement(children: .combine)
    }
}
