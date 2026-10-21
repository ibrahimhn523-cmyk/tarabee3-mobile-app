import SwiftUI

/// S-02 · الرئيسية — ما يخصّ M-02 منها: الشعار الأفقي في الرأس، والأفاتار والاسم، والأرقام أو «لا مباريات بعد»،
/// وزرّ الإعدادات. أزرار المباراة والغرفة والتدريب والمشتريات والشريط الإعلاني تأتي مع شرائحها.
struct HomeView: View {
    let store: ProfileStore
    let player: Player

    @State private var showSettings = false
    @State private var showTraining = false
    @State private var quickMatch: OnlineSession?
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        ScrollView {
            VStack(spacing: Space.s(5)) {
                HStack {
                    Image("Logo-horizontal").resizable().scaledToFit().frame(height: 28)
                        .accessibilityLabel("ترابيع")
                    Spacer()
                    Button { showSettings = true } label: {
                        Image("icon-settings").resizable().frame(width: IconSize.medium, height: IconSize.medium)
                            .foregroundStyle(palette.text)
                            .frame(width: Touch.min, height: Touch.min)
                    }
                    .accessibilityLabel(Copy.Home.settings)
                }

                VStack(spacing: Space.s(2)) {
                    AvatarView(team: .team1, persona: player.persona, side: TokenValue.px(Tokens.Persona.Size.profile), hop: true)
                    // الاسم يكتبه اللاعب: يُعزل اتجاهه
                    Text(verbatim: "\u{2068}\(player.name)\u{2069}").font(.app(.h1, .bold)).foregroundStyle(palette.text)
                }

                if player.matchesPlayed == 0 {
                    emptyState(palette)
                } else {
                    HStack(spacing: Space.s(2)) {
                        stat(Copy.Home.matches, player.matchesPlayed, palette)
                        stat(Copy.Home.wins, player.wins, palette)
                    }
                }
            }
            .padding(.horizontal, Space.s(3))
            .padding(.vertical, Space.s(2))
        }
        // المباراة السريعة الزرّ الأساسي (M-06)، والتدريب بعدها
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.s(2)) {
                Button(Copy.Online.quickMatch) {
                    let s = store
                    quickMatch = OnlineSession(endpoint: { try await s.onlineEndpoint() })
                }
                .appButton(.primary)
                Button(Copy.Home.training) { showTraining = true }.appButton(.secondary)
            }
            .padding(.horizontal, Space.s(3))
            .padding(.vertical, Space.s(2))
            .background(palette.ground)
        }
        .appBackground()
        // فتح التطبيق ومباراته قائمة يعيده إليها مباشرة (S-02 «عودة»)
        .task {
            if quickMatch == nil, let id = UserDefaults.standard.string(forKey: OnlineSession.currentMatchKey) {
                let s = store
                let session = OnlineSession(endpoint: { try await s.onlineEndpoint() })
                session.rejoin(id)
                quickMatch = session
            }
        }
        .fullScreenCover(item: $quickMatch) { session in
            QuickMatchView(player: player, session: session) { quickMatch = nil }.appEnvironment(appearance)
        }
        .fullScreenCover(isPresented: $showTraining) {
            TrainingSetupView(player: player) { showTraining = false }.appEnvironment(appearance)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store, player: player).appEnvironment(appearance)
        }
    }

    private func stat(_ title: String, _ value: Int, _ palette: Palette) -> some View {
        VStack(spacing: Space.s(0)) {
            Text(verbatim: String(value)).font(.app(.h1, .bold)).monospacedDigit().foregroundStyle(palette.text)
            Text(title).font(.app(.small)).foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.s(3))
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }

    /// الحالة الفارغة (05-ui §٦): أيقونة ٢٤ وسطر بما ينقص.
    private func emptyState(_ palette: Palette) -> some View {
        VStack(spacing: Space.s(1)) {
            Image("icon-info").resizable().frame(width: IconSize.medium, height: IconSize.medium)
                .foregroundStyle(palette.textMuted).accessibilityHidden(true)
            Text(Copy.Home.noMatches).font(.app(.body)).foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.s(4))
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}
