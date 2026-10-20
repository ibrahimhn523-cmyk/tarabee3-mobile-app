import SwiftUI

/// S-01 · أول فتح: يكتب اللاعب اسمه ويختار تعبيره وتلبيساته، ثم «ابدأ».
/// الشعار العمودي، ثم الحقل، ثم المعاينة والتعابير بشبكة أربعة أعمدة، والزرّ ثابت أسفلها (05-ui §١٣).
struct FirstOpenView: View {
    let store: ProfileStore

    @State private var name = ""
    @State private var persona = Persona.default
    @State private var error: ProfileError?
    @Environment(\.colorScheme) private var scheme

    private var canStart: Bool { NameRule.isValidLength(name) }

    var body: some View {
        let palette = Palette.of(scheme)
        ScrollView {
            VStack(spacing: Space.s(5)) {
                Image("Logo-vertical").resizable().scaledToFit().frame(height: 120)
                    .accessibilityLabel("ترابيع")
                    .padding(.top, Space.s(4))

                if let message = statusMessage {
                    StatusBanner(kind: .error, text: message)
                }

                AppTextField(
                    label: Copy.FirstOpen.nameLabel,
                    placeholder: Copy.FirstOpen.namePlaceholder,
                    text: $name,
                    error: error == .nameUnavailable ? Copy.Status.nameUnavailable : nil
                )
                .onChange(of: name) { if error == .nameUnavailable { error = nil } }

                VStack(alignment: .leading, spacing: Space.s(2)) {
                    Text(Copy.FirstOpen.pickerTitle).font(.app(.h2, .bold)).foregroundStyle(palette.text)
                    AvatarPicker(persona: $persona)
                }
            }
            .padding(.horizontal, Space.s(3))
            .padding(.bottom, Space.s(4))
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.s(0)) {
                Button(Copy.FirstOpen.start) { Task { await start() } }
                    .appButton(.primary, loading: store.saving)
                    .disabled(!canStart)
                if !canStart {
                    Text(Copy.FirstOpen.nameLengthHint).font(.app(.small)).foregroundStyle(palette.textMuted)
                }
            }
            .padding(.horizontal, Space.s(3))
            .padding(.vertical, Space.s(2))
            .background(palette.ground)
        }
        .appBackground()
    }

    private var statusMessage: String? {
        switch error {
        case .offline: Copy.Status.noInternet
        case .server, .nameLength: Copy.Status.serverError
        case .notConfigured: Copy.Status.notConfigured
        case .nameUnavailable, nil: nil
        }
    }

    private func start() async {
        error = nil
        do { try await store.save(name: name, persona: persona) } catch { self.error = error }
    }
}
