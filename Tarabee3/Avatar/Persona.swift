import Foundation

// الشخصية «المربع الحيّ» (R-03، القرار 0016): تعبير وثلاث خانات تلبيس. القيم الخام هي ما يحفظه الخادم (03-schema).
// التعابير مرتّبة كترتيب المنتقي، ومنقولة من مشروع الويب بقرار المالك — تقرير M-02.

enum Expression: String, CaseIterable, Sendable, Codable {
    case smile = "مبتسم"
    case wink = "غامز"
    case angry = "غاضب"
    case surprised = "مندهش"
    case sleepy = "نعسان"
    case tongue = "مُخرج لسانه"
    case starEyes = "عيون نجوم"
    case confident = "واثق"
    case laughing = "ضاحك"
    case excited = "متحمّس"
    case shy = "خجول"
    case thinking = "مفكّر"
}

enum HeadOutfit: String, CaseIterable, Sendable, Codable {
    case none = "بلا"
    case shemagh = "شماغ"
    case taqiyah = "طاقية"
    case cap = "كاب"
}

enum EyeOutfit: String, CaseIterable, Sendable, Codable {
    case none = "بلا"
    case glasses = "نظارة"
    case eyepatch = "عين القرصان"
}

enum NeckOutfit: String, CaseIterable, Sendable, Codable {
    case none = "بلا"
    case shawl = "شال"
}

struct Persona: Equatable, Hashable, Sendable {
    var expression: Expression
    var head: HeadOutfit
    var eye: EyeOutfit
    var neck: NeckOutfit

    static let `default` = Persona(expression: .smile, head: .none, eye: .none, neck: .none)

    /// الوصف المقروء (05-ui §١١): «مربع {اللون} {التعبير}» ثم التلبيسات: «بشماغ ونظارة وشال».
    func spokenLabel(team: Team) -> String {
        let base = "مربع \(team.spokenName) \(expression.rawValue)"
        let worn = [head.rawValue, eye.rawValue, neck.rawValue].filter { $0 != HeadOutfit.none.rawValue }
        guard !worn.isEmpty else { return base }
        return base + " ب" + worn.joined(separator: " و")
    }
}
