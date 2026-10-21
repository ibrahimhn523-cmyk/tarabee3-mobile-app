import SwiftUI

/// S-14 · النتيجة (05-ui §١٣): الفائز أعلاها بأفاتار ٦٤، ثم الترتيب والمتعادلون في مرتبة واحدة برقمها، ثم اللوح المصغّر،
/// والزرّان ثابتان أسفلها. وفي التدريب بلا إعلان ولا احتساب.
struct ResultScreen: View {
    let view: MatchView
    var onPlayAgain: () -> Void
    var onHome: () -> Void
    /// رسالة أعلى النتيجة: أُلغيت، أو انتهت قبل عودته.
    var notice: String? = nil
    /// أون لاين: طلب مباراة جديدة بنفس اللاعبين (R-35) بدل «مباراة جديدة».
    var rematch: RematchPrompt? = nil
    var now: Double = 0
    var onRematch: (Bool) -> Void = { _ in }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        let rows = view.ranking ?? []
        let winners = rows.filter { $0.rank == 1 }.compactMap { view.seat($0.seatNo) }
        ScrollView {
            VStack(spacing: Space.s(4)) {
                if let notice { StatusBanner(kind: .info, text: notice).padding(.top, Space.s(2)) }
                VStack(spacing: Space.s(2)) {
                    HStack(spacing: Space.s(3)) {
                        ForEach(winners) { seat in
                            AvatarView(team: seat.team, persona: seat.persona.persona,
                                       side: TokenValue.px(Tokens.Persona.Size.resultFirst), hop: true)
                        }
                    }
                    Text(winners.count > 1 ? Copy.Match.tie : Copy.Match.winner(winners.first.map { "\u{2068}\($0.displayName)\u{2069}" } ?? ""))
                        .font(.app(.h1, .bold)).foregroundStyle(palette.text).multilineTextAlignment(.center)
                }
                .padding(.top, Space.s(4))

                VStack(spacing: Space.s(1)) {
                    ForEach(rows, id: \.seatNo) { row in
                        if let seat = view.seat(row.seatNo) {
                            HStack(spacing: Space.s(2)) {
                                Text(verbatim: String(row.rank)).font(.app(.h2, .bold)).monospacedDigit()
                                    .frame(width: 28)
                                AvatarView(team: seat.team, persona: seat.persona.persona, side: TokenValue.px(Tokens.Persona.Size.badge))
                                Text(verbatim: "\u{2068}\(seat.displayName)\u{2069}").font(.app(.body, .medium))
                                if seat.isBot { BotTag() }
                                Spacer()
                                Text(verbatim: String(row.squares)).font(.app(.body, .bold)).monospacedDigit()
                            }
                            .foregroundStyle(palette.text)
                            .padding(Space.s(2))
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.control))
                            .overlay(alignment: .leading) {
                                Capsule().fill(seat.team.flat).frame(width: 4).padding(.vertical, Space.s(1))
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                BoardView(view: view, small: true).frame(maxWidth: 260)
            }
            .padding(.horizontal, Space.s(3))
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.s(1)) {
                if let rematch {
                    rematchBox(rematch, palette)
                } else if view.phase.reason != "cancelled" {
                    Button(Copy.Match.playAgain, action: onPlayAgain).appButton(.primary)
                }
                Button(Copy.Match.home, action: onHome).appButton(.secondary)
            }
            .padding(.horizontal, Space.s(3))
            .padding(.vertical, Space.s(2))
            .background(palette.ground)
        }
    }

    /// «مباراة جديدة بنفس اللاعبين؟» عشرين ثانية: نعم أو لا، ثم انتظار الباقين، أو لم تُجمع.
    @ViewBuilder
    private func rematchBox(_ r: RematchPrompt, _ palette: Palette) -> some View {
        if r.closed || (r.mine == nil && now >= r.until) {
            Text(Copy.Online.rematchClosed).font(.app(.small)).foregroundStyle(palette.textMuted)
        } else if r.mine == true {
            Text(Copy.Online.rematchWaiting).font(.app(.body, .medium)).foregroundStyle(palette.text)
        } else if r.mine == nil {
            Text(Copy.Online.rematchQuestion).font(.app(.body, .bold)).foregroundStyle(palette.text)
            TimerView(deadline: r.until, total: 20_000, now: now)
            HStack(spacing: Space.s(2)) {
                Button(Copy.Online.rematchNo) { onRematch(false) }.appButton(.secondary)
                Button(Copy.Online.rematchYes) { onRematch(true) }.appButton(.primary)
            }
        }
    }
}
