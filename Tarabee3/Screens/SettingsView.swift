import SwiftUI

/// S-03 · الملف والإعدادات — «قائمة صفوف تتمرّر» (05-ui §١٣) بما يخصّ M-02: صفّ الملف يفتح تعديل الاسم والشخصية،
/// وصفّ المظهر، وحذف الحساب بتأكيد مرتين (R-63). الربط بحساب آبل ينتظر حساب المطوّر، واستعادة المشتريات مع M-08.
struct SettingsView: View {
    let store: ProfileStore
    let player: Player

    @State private var confirmStep = 0
    @State private var deleteFailed: ProfileError?
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let palette = Palette.of(scheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s(3)) {
                    if let deleteFailed {
                        StatusBanner(kind: .error, text: deleteFailed == .offline ? Copy.Status.noInternet : Copy.Status.deleteFailed)
                    }

                    NavigationLink {
                        ProfileEditView(store: store, player: player).appEnvironment(appearance)
                    } label: {
                        SettingsRow(title: Copy.Settings.profile, palette: palette) {
                            HStack(spacing: Space.s(2)) {
                                AvatarView(team: .team1, persona: player.persona, side: TokenValue.px(Tokens.Persona.Size.lobbySlot))
                                Text(verbatim: "\u{2068}\(player.name)\u{2069}").font(.app(.body, .medium))
                                    .foregroundStyle(palette.text)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: Space.s(1)) {
                        Text(Copy.Settings.appearance).font(.app(.small, .medium)).foregroundStyle(palette.textMuted)
                        SplitPicker(options: Appearance.allCases.map { ($0, $0.title) }, selection: $appearance)
                    }
                    .padding(Space.s(3))
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.card))

                    Button(Copy.Settings.deleteAccount) { deleteFailed = nil; confirmStep = 1 }
                        .appButton(.danger, loading: store.deleting)
                        .padding(.top, Space.s(3))

                    Text(verbatim: BuildInfo.text).font(.app(.caption)).foregroundStyle(palette.textMuted)
                        .frame(maxWidth: .infinity)
                }
                .padding(Space.s(3))
            }
            .appBackground()
            .navigationTitle(Copy.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image("icon-x").resizable().frame(width: IconSize.medium, height: IconSize.medium)
                            .foregroundStyle(palette.text)
                    }
                    .accessibilityLabel(Copy.Settings.close)
                }
            }
            .sheet(isPresented: Binding(get: { confirmStep > 0 }, set: { if !$0 { confirmStep = 0 } })) {
                deleteSheet(palette)
                    .appEnvironment(appearance)
                    .presentationDetents([.medium])
                    .presentationCornerRadius(Radius.sheet)
            }
        }
    }

    /// اللوحة السفلية للتأكيد: مرة تذكر الأثر، ومرة أخيرة. «إلغاء» زرّ شفّاف.
    private func deleteSheet(_ palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: Space.s(4)) {
            Text(confirmStep == 1 ? Copy.Settings.deleteAccount : Copy.Settings.deleteFinalTitle)
                .font(.app(.h2, .bold)).foregroundStyle(palette.text)
            Text(Copy.Settings.deleteConfirm).font(.app(.body)).foregroundStyle(palette.text)
            Spacer(minLength: 0)
            if confirmStep == 1 {
                Button(Copy.Settings.deleteContinue) { confirmStep = 2 }.appButton(.danger)
            } else {
                Button(Copy.Settings.deleteFinal) { Task { await delete() } }.appButton(.danger, loading: store.deleting)
            }
            Button(Copy.Settings.cancel) { confirmStep = 0 }.appButton(.plain).frame(maxWidth: .infinity)
        }
        .padding(Space.s(4))
        .appBackground()
    }

    private func delete() async {
        do {
            try await store.deleteAccount()
            confirmStep = 0
            dismiss()
        } catch {
            deleteFailed = error
            confirmStep = 0
        }
    }
}

/// تعديل الاسم والشخصية، يُفتح من صفّ الملف.
struct ProfileEditView: View {
    let store: ProfileStore
    let player: Player

    @State private var name: String
    @State private var persona: Persona
    @State private var error: ProfileError?
    @State private var saved = false
    @Environment(\.colorScheme) private var scheme

    init(store: ProfileStore, player: Player) {
        self.store = store
        self.player = player
        _name = State(initialValue: player.name)
        _persona = State(initialValue: player.persona)
    }

    private var changed: Bool { NameRule.normalized(name) != player.name || persona != player.persona }

    var body: some View {
        let palette = Palette.of(scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s(5)) {
                if let message = statusMessage {
                    StatusBanner(kind: saved ? .info : .error, text: message)
                }
                AppTextField(
                    label: Copy.FirstOpen.nameLabel, placeholder: Copy.FirstOpen.namePlaceholder, text: $name,
                    error: error == .nameUnavailable ? Copy.Status.nameUnavailable : nil,
                    hint: NameRule.isValidLength(name) ? nil : Copy.FirstOpen.nameLengthHint
                )
                .onChange(of: name) { error = nil; saved = false }
                AvatarPicker(persona: $persona)
                    .onChange(of: persona) { saved = false }
            }
            .padding(Space.s(3))
        }
        .safeAreaInset(edge: .bottom) {
            Button(Copy.Settings.save) { Task { await save() } }
                .appButton(.primary, loading: store.saving)
                .disabled(!changed || !NameRule.isValidLength(name))
                .padding(.horizontal, Space.s(3))
                .padding(.vertical, Space.s(2))
                .background(palette.ground)
        }
        .appBackground()
        .navigationTitle(Copy.Settings.profile)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusMessage: String? {
        switch error {
        case .offline: Copy.Status.noInternet
        case .server, .nameLength: Copy.Status.serverError
        case .notConfigured: Copy.Status.notConfigured
        case .nameUnavailable: nil
        case nil: saved ? Copy.Settings.saved : nil
        }
    }

    private func save() async {
        error = nil
        do {
            try await store.save(name: name, persona: persona)
            saved = true
        } catch {
            self.error = error
        }
    }
}
