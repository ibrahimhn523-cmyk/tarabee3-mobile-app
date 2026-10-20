import SwiftUI

/// منتقي الأفاتار (05-ui §٦) في S-01 وS-03: المعاينة أعلاه، ثم التعابير الاثنا عشر بشبكة أربعة أعمدة،
/// ثم صفوف الرأس والعين والرقبة. المختار بحدّ text سميك وعلامة صحّ. بلا اختيار لون: لون الملف المقعد الأول.
struct AvatarPicker: View {
    @Binding var persona: Persona
    @Environment(\.colorScheme) private var scheme

    private let team = Team.team1
    private let cell = TokenValue.px(Tokens.Persona.Size.pickerCell)
    private let preview = TokenValue.px(Tokens.Persona.Size.preview)

    var body: some View {
        let palette = Palette.of(scheme)
        VStack(spacing: Space.s(4)) {
            AvatarView(team: team, persona: persona, side: preview)
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s(1)), count: 4), spacing: Space.s(1)) {
                ForEach(FaceExpression.allCases, id: \.self) { expression in
                    choice(selected: persona.expression == expression, label: expression.rawValue, palette: palette) {
                        persona.expression = expression
                    } content: {
                        AvatarView(team: team, persona: Persona(expression: expression, head: .none, eye: .none, neck: .none), side: cell * 0.62)
                    }
                }
            }

            row(Copy.Picker.head, HeadOutfit.allCases, \.head, palette: palette)
            row(Copy.Picker.eye, EyeOutfit.allCases, \.eye, palette: palette)
            row(Copy.Picker.neck, NeckOutfit.allCases, \.neck, palette: palette)
        }
    }

    private func row<Value: RawRepresentable & Hashable>(
        _ title: String, _ values: [Value], _ key: WritableKeyPath<Persona, Value>, palette: Palette
    ) -> some View where Value.RawValue == String {
        VStack(alignment: .leading, spacing: Space.s(1)) {
            Text(title).font(.app(.small, .medium)).foregroundStyle(palette.textMuted)
            HStack(spacing: Space.s(1)) {
                ForEach(values, id: \.self) { value in
                    choice(selected: persona[keyPath: key] == value, label: value.rawValue, palette: palette) {
                        persona[keyPath: key] = value
                    } content: {
                        Text(value.rawValue).font(.app(.small)).foregroundStyle(palette.text)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }

    private func choice<Content: View>(
        selected: Bool, label: String, palette: Palette, action: @escaping () -> Void, @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, minHeight: max(cell, Touch.min))
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.control)
                        .strokeBorder(selected ? palette.text : palette.line, lineWidth: selected ? 3 : 1)
                }
                .overlay(alignment: .topLeading) {
                    if selected {
                        Image("icon-check").resizable().frame(width: IconSize.small * 0.7, height: IconSize.small * 0.7)
                            .foregroundStyle(palette.text).padding(Space.s(0))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
