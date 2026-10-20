import SwiftUI

// عناصر الواجهة المشتركة (05-ui §٥، §٦، §٧). الأحجام والألوان من ملف القيم.

// MARK: - الأزرار

enum ButtonKind { case primary, secondary, plain, danger }

struct AppButtonStyle: ButtonStyle {
    let kind: ButtonKind
    var loading = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let palette = Palette.of(scheme)
        let foreground = kind == .primary ? palette.ground : palette.text
        HStack(spacing: Space.s(1)) {
            if kind == .danger && !loading {
                Image("icon-triangle-alert").resizable().frame(width: IconSize.small, height: IconSize.small)
            }
            configuration.label.opacity(loading ? 0 : 1)
        }
        .font(.app(.body, .medium))
        .foregroundStyle(foreground)
        .overlay { if loading { ProgressView().tint(foreground) } }
        .frame(maxWidth: kind == .plain ? nil : .infinity, minHeight: Touch.min)
        .padding(.horizontal, Space.s(3))
        .background {
            switch kind {
            case .primary: RoundedRectangle(cornerRadius: Radius.control).fill(palette.primary)
            case .secondary, .danger: RoundedRectangle(cornerRadius: Radius.control).strokeBorder(palette.text, lineWidth: 1)
            case .plain: Color.clear
            }
        }
        .contentShape(Rectangle())
        .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : Alpha.disabled)
    }
}

extension View {
    func appButton(_ kind: ButtonKind, loading: Bool = false) -> some View {
        buttonStyle(AppButtonStyle(kind: kind, loading: loading)).disabled(loading)
    }
}

// MARK: - حقل النصّ

/// سطح بحدّ line، وحدّ text عند التركيز؛ والخطأ حدّ سميك وأيقونة تحذير ورسالة تحته.
/// الاسم يكتبه اللاعب فيُعزل اتجاهه (05-ui §١٢).
struct AppTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var error: String?
    var hint: String?

    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        VStack(alignment: .leading, spacing: Space.s(0)) {
            HStack(spacing: Space.s(1)) {
                TextField(placeholder, text: $text)
                    .font(.app(.body))
                    .foregroundStyle(palette.text)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .multilineTextAlignment(.leading)
                    .accessibilityLabel(label)
                if error != nil {
                    Image("icon-triangle-alert").resizable().frame(width: IconSize.small, height: IconSize.small)
                        .foregroundStyle(palette.text).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Space.s(3))
            .frame(minHeight: Touch.min)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control).strokeBorder(
                    error != nil || focused ? palette.text : palette.line,
                    lineWidth: error != nil ? 3 : 1
                )
            }
            if let message = error ?? hint {
                Text(message).font(.app(.small)).foregroundStyle(error != nil ? palette.text : palette.textMuted)
            }
        }
    }
}

// MARK: - شريط الحالة

enum StatusKind { case info, warning, error }

/// شريط أعلى الشاشة بأيقونة ونص (05-ui §٧). الخطأ يبقى حتى يُحلّ.
struct StatusBanner: View {
    let kind: StatusKind
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        HStack(spacing: Space.s(2)) {
            Image(icon).resizable().frame(width: IconSize.small, height: IconSize.small).accessibilityHidden(true)
            Text(text).font(.app(.small, .medium)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(palette.text)
        .padding(Space.s(3))
        .background(palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch kind {
        case .info: "icon-info"
        case .warning: "icon-triangle-alert"
        case .error: "icon-circle-x"
        }
    }
}

// MARK: - المحدّد المقسوم

/// خياران أو ثلاثة متجاورة؛ المختار بتعبئة primary ونصّ ground.
struct SplitPicker<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.of(scheme)
        HStack(spacing: Space.s(0)) {
            ForEach(options, id: \.0) { value, title in
                let selected = value == selection
                Button { selection = value } label: {
                    Text(title).font(.app(.small, .medium))
                        .foregroundStyle(selected ? palette.ground : palette.text)
                        .frame(maxWidth: .infinity, minHeight: Touch.min)
                        .background(selected ? palette.primary : .clear, in: RoundedRectangle(cornerRadius: Radius.control - 2))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(Space.s(0) / 2)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.control))
    }
}

// MARK: - صفّ الإعدادات

/// بند في S-03 (05-ui §٦): عنوان وقيمته وسهم. السهم يشير لليسار: «التقدّم» في واجهة من اليمين.
struct SettingsRow<Value: View>: View {
    let title: String
    let palette: Palette
    @ViewBuilder let value: () -> Value

    var body: some View {
        HStack(spacing: Space.s(2)) {
            VStack(alignment: .leading, spacing: Space.s(1)) {
                Text(title).font(.app(.small, .medium)).foregroundStyle(palette.textMuted)
                value()
            }
            Spacer()
            Image("icon-chevron-left").resizable().frame(width: IconSize.small, height: IconSize.small)
                .foregroundStyle(palette.textMuted).accessibilityHidden(true)
        }
        .padding(Space.s(3))
        .frame(minHeight: Touch.min)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.card))
        .contentShape(Rectangle())
    }
}

// MARK: - الخلفية

struct AppBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.background(Palette.of(scheme).ground.ignoresSafeArea())
    }
}

extension View {
    func appBackground() -> some View { modifier(AppBackground()) }
}
