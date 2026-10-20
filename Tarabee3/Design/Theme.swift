import SwiftUI

// قراءة قيم Tokens.swift (المولَّد من ملف القيم) بأنواع سويفت. لا رقم ولا لون مكتوب هنا.

enum TokenValue {
    /// "32px" → 32
    static func px(_ value: String) -> CGFloat {
        CGFloat(Double(value.replacingOccurrences(of: "px", with: "")) ?? 0)
    }
    /// "20%" → 0.2
    static func share(_ value: String) -> CGFloat {
        CGFloat((Double(value.replacingOccurrences(of: "%", with: "")) ?? 0) / 100)
    }
    /// "0.40" → 0.4
    static func number(_ value: String) -> Double { Double(value) ?? 0 }
    /// "4s" / "1500ms" → ثوانٍ
    static func seconds(_ value: String) -> Double {
        if value.hasSuffix("ms") { return (Double(value.dropLast(2)) ?? 0) / 1000 }
        if value.hasSuffix("s") { return Double(value.dropLast(1)) ?? 0 }
        return 0
    }
}

extension Color {
    /// "#RRGGBB"
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(digits, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// الطبقة المحايدة بوضعيها (05-ui §١): الداكن من color، والفاتح من mode.light.
struct Palette: Sendable {
    let ground: Color
    let surface: Color
    let surfaceRaised: Color
    let line: Color
    let text: Color
    let textMuted: Color
    let primary: Color
    let focus: Color

    static let dark = Palette(
        ground: Color(hex: Tokens.Color.ground), surface: Color(hex: Tokens.Color.surface),
        surfaceRaised: Color(hex: Tokens.Color.surfaceRaised), line: Color(hex: Tokens.Color.line),
        text: Color(hex: Tokens.Color.text), textMuted: Color(hex: Tokens.Color.textMuted),
        primary: Color(hex: Tokens.Color.primary), focus: Color(hex: Tokens.Color.focus)
    )
    static let light = Palette(
        ground: Color(hex: Tokens.Mode.Light.ground), surface: Color(hex: Tokens.Mode.Light.surface),
        surfaceRaised: Color(hex: Tokens.Mode.Light.surfaceRaised), line: Color(hex: Tokens.Mode.Light.line),
        text: Color(hex: Tokens.Mode.Light.text), textMuted: Color(hex: Tokens.Mode.Light.textMuted),
        primary: Color(hex: Tokens.Mode.Light.primary), focus: Color(hex: Tokens.Mode.Light.focus)
    )

    static func of(_ scheme: ColorScheme) -> Palette { scheme == .dark ? .dark : .light }
}

enum Alpha {
    static let disabled = TokenValue.number(Tokens.Color.disabledAlpha)
    static let preview = TokenValue.number(Tokens.Color.previewAlpha)
}

/// المسافات: مضاعفات ٤ من space.scale — Space.s(0) = ٤ … Space.s(7) = ٦٤.
enum Space {
    static func s(_ step: Int) -> CGFloat { CGFloat(Tokens.Space.scale[step]) }
}

enum Radius {
    static let control = TokenValue.px(Tokens.Radius.control)
    static let card = TokenValue.px(Tokens.Radius.card)
    static let sheet = TokenValue.px(Tokens.Radius.sheet)
    static let cell = TokenValue.share(Tokens.Radius.cell)
}

enum Touch {
    static let min = TokenValue.px(Tokens.Touch.minTarget)
}

enum IconSize {
    static let small = TokenValue.px(Tokens.Icon.sizeSm)
    static let medium = TokenValue.px(Tokens.Icon.sizeMd)
}

/// ألوان المقاعد (05-ui §١): المقعد ١ إلى ٥ = team-1 إلى team-5، بتدرّجاتها في cell.
enum Team: Int, CaseIterable, Sendable {
    case team1 = 1, team2, team3, team4, team5

    var flat: Color {
        switch self {
        case .team1: Color(hex: Tokens.Color.team1)
        case .team2: Color(hex: Tokens.Color.team2)
        case .team3: Color(hex: Tokens.Color.team3)
        case .team4: Color(hex: Tokens.Color.team4)
        case .team5: Color(hex: Tokens.Color.team5)
        }
    }

    /// التدرّج: الفاتح ثم الداكن.
    var cell: (light: Color, dark: Color) {
        let pair: [String] = switch self {
        case .team1: Tokens.Cell.team1
        case .team2: Tokens.Cell.team2
        case .team3: Tokens.Cell.team3
        case .team4: Tokens.Cell.team4
        case .team5: Tokens.Cell.team5
        }
        return (Color(hex: pair[0]), Color(hex: pair[1]))
    }

    /// اسمه في ملف القيم: "team-1".
    var tokenName: String { "team-\(rawValue)" }

    /// اسم اللون للوصف المقروء (05-ui §١، §١١).
    var spokenName: String {
        switch self {
        case .team1: "أحمر"
        case .team2: "أصفر"
        case .team3: "فيروزي"
        case .team4: "أزرق"
        case .team5: "أرجواني"
        }
    }
}

// MARK: - الخط

/// ريديكس برو بالمستويات (05-ui §٢)، يكبر مع إعداد آيفون. وسقف الكِبَر على جذر التطبيق.
enum TextLevel {
    case display, h1, h2, body, small, caption, timer

    var size: CGFloat {
        switch self {
        case .display: TokenValue.px(Tokens.Font.sizeDisplay)
        case .h1: TokenValue.px(Tokens.Font.sizeH1)
        case .h2: TokenValue.px(Tokens.Font.sizeH2)
        case .body: TokenValue.px(Tokens.Font.sizeBody)
        case .small: TokenValue.px(Tokens.Font.sizeSmall)
        case .caption: TokenValue.px(Tokens.Font.sizeCaption)
        case .timer: TokenValue.px(Tokens.Font.sizeTimer)
        }
    }

    var relativeTo: Font.TextStyle {
        switch self {
        case .display: .largeTitle
        case .h1: .title
        case .h2: .title2
        case .body: .body
        case .small: .subheadline
        case .caption: .caption
        case .timer: .title
        }
    }
}

enum TextWeight {
    case regular, medium, bold

    var font: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .bold: .bold
        }
    }
}

extension Font {
    static func app(_ level: TextLevel, _ weight: TextWeight = .regular) -> Font {
        .custom(Tokens.Font.familyAr, size: level.size, relativeTo: level.relativeTo).weight(weight.font)
    }
}

/// السقف: النصوص تكبر حتى ١٣٠٪ (type-scale.max). أقرب درجة لآيفون دونه xxLarge (نحو ١٢٤٪).
enum TypeScaleCap {
    static let max: DynamicTypeSize = .xxLarge
}
