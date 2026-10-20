import Foundation

/// ملف اللاعب كما يقرؤه الجهاز (03-schema، Player). الجهاز لا يكتبه: الكتابة عبر الخادم (القرار 0018).
struct Player: Equatable, Sendable {
    var id: String
    var name: String
    var persona: Persona
    var appleLinked: Bool
    var matchesPlayed: Int
    var wins: Int

    /// من حقول مستند Firestore أو ردّ الخادم. القيمة المجهولة تأخذ الافتراضي ولا تُسقط الملف.
    init(id: String, fields: [String: Any]) {
        self.id = id
        name = fields["name"] as? String ?? ""
        persona = Persona(
            expression: (fields["expression"] as? String).flatMap(FaceExpression.init(rawValue:)) ?? .smile,
            head: (fields["accessoryHead"] as? String).flatMap(HeadOutfit.init(rawValue:)) ?? .none,
            eye: (fields["accessoryEye"] as? String).flatMap(EyeOutfit.init(rawValue:)) ?? .none,
            neck: (fields["accessoryNeck"] as? String).flatMap(NeckOutfit.init(rawValue:)) ?? .none
        )
        appleLinked = fields["appleLinked"] as? Bool ?? false
        matchesPlayed = (fields["matchesPlayed"] as? NSNumber)?.intValue ?? 0
        wins = (fields["wins"] as? NSNumber)?.intValue ?? 0
    }

    init(id: String, name: String, persona: Persona, appleLinked: Bool = false, matchesPlayed: Int = 0, wins: Int = 0) {
        self.id = id
        self.name = name
        self.persona = persona
        self.appleLinked = appleLinked
        self.matchesPlayed = matchesPlayed
        self.wins = wins
    }
}

/// قاعدة طول الاسم في الجهاز، لتعطيل «ابدأ» قبل الإرسال (S-01). الفحص الحاكم في الخادم (R-02).
enum NameRule {
    static let min = 2
    static let max = 12

    /// يقصّ الطرفين ويوحّد المسافات، كما يفعل الخادم.
    static func normalized(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// يعدّ الحروف كما تُرى (Character في سويفت عنقود حرفي).
    static func isValidLength(_ raw: String) -> Bool {
        (min...max).contains(normalized(raw).count)
    }
}
