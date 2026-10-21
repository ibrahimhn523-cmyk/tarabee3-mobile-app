import SwiftUI

/// يد الكروت في لوحة سفلية (05-ui §٦ «الكرت»، §٩): أيقونة لوسيد واسمه وسطره؛ ليس وقته: خافت مع السبب.
struct CardsSheet: View {
    let session: any MatchSession
    var onClose: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        VStack(alignment: .leading, spacing: Space.s(3)) {
            Text(Copy.Cards.title).font(.app(.h2, .bold)).foregroundStyle(palette.text)
            let cards = session.me?.cards ?? []
            if cards.isEmpty {
                Text(Copy.Cards.none).font(.app(.body)).foregroundStyle(palette.textMuted)
            }
            ForEach(cards) { card in
                let state = session.playability(card)
                HStack(alignment: .top, spacing: Space.s(2)) {
                    Image(Copy.Cards.icon(card.type)).resizable().frame(width: IconSize.medium, height: IconSize.medium)
                    VStack(alignment: .leading, spacing: Space.s(0)) {
                        Text(Copy.Cards.name(card.type) + (card.clearCount.map { " · " + Copy.Cards.clearCount($0) } ?? ""))
                            .font(.app(.body, .bold))
                        Text(Copy.Cards.line(card.type)).font(.app(.small)).foregroundStyle(palette.textMuted)
                        if let reason = state.reason {
                            Text(reason).font(.app(.caption)).foregroundStyle(palette.textMuted)
                        }
                    }
                    Spacer(minLength: 0)
                    Button(Copy.Cards.play) { session.play(card); onClose() }
                        .appButton(.secondary)
                        .frame(width: 96)
                        .disabled(!state.ok)
                }
                .foregroundStyle(palette.text)
                .padding(Space.s(3))
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.card))
                .opacity(state.ok ? 1 : Alpha.disabled + 0.25)
                .accessibilityElement(children: .contain)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s(4))
        .appBackground()
    }
}

/// زرّ «الكروت» في شاشات المباراة: يظهر إن كان معه كرت، ويُعلَّم إن كان فيها ما يُلعب الآن.
struct CardsButton: View {
    let session: any MatchSession
    @Binding var showCards: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let cards = session.me?.cards ?? []
        if !cards.isEmpty {
            let playable = cards.contains { session.playability($0).ok }
            Button { showCards = true } label: {
                HStack(spacing: Space.s(1)) {
                    Image("icon-layers").resizable().frame(width: IconSize.small, height: IconSize.small)
                    Text("\(Copy.Cards.title) (\(cards.count))")
                }
            }
            .appButton(playable ? .secondary : .plain)
            .accessibilityHint(playable ? Copy.Cards.play : Copy.Cards.notNow)
        }
    }
}

/// S-13 · نافذة الحرق (05-ui §٦، §١٦): تملأ الشاشة عشر ثوانٍ — أفاتار المعتدي ٨٠ واسمه، وما سُحب ويعود بالحرق،
/// والعدّاد، وزرّا «احرق» و«تجاوز». والصمت لا يحرق (R-40).
struct BurnScreen: View {
    let session: any MatchSession
    let window: BurnWindowView
    let until: Double
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        let attacker = session.view?.round?.chooser.flatMap { session.view?.seat($0) }
            ?? session.view?.round?.seatNo.flatMap { session.view?.seat($0) }
        VStack(spacing: Space.s(4)) {
            Spacer()
            Text(Copy.Burn.title).font(.app(.h1, .bold)).foregroundStyle(palette.text)
            if let attacker {
                AvatarView(team: attacker.team, persona: attacker.persona.persona, side: TokenValue.px(Tokens.Persona.Size.burn))
                Text(Copy.Burn.line("\u{2068}\(attacker.displayName)\u{2069}", window.cells.count))
                    .font(.app(.body)).foregroundStyle(palette.text).multilineTextAlignment(.center)
            }
            if let view = session.view {
                BoardView(view: view, targetCells: Set(window.cells)).frame(maxWidth: 240)
            }
            TimerView(deadline: until, total: session.view?.times.burn ?? 10_000, now: session.now)
            Spacer()
            Button(Copy.Burn.burn) { session.decideBurn(true) }.appButton(.primary)
            Button(Copy.Burn.skip) { session.decideBurn(false) }.appButton(.plain).frame(maxWidth: .infinity)
        }
        .padding(Space.s(3))
    }
}
