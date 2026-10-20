import Foundation

// عرض المباراة كما يرسله المحرّك لمقعد بعينه (server/engine/view.ts)، أون لاين أو في التدريب (القرار 0019).
// الإجابة الصحيحة لا تكون فيه قبل انتهاء السؤال (R-30)، وفي الجماعية لا يُعرف من أصاب حتى تنتهي (R-26).

/** الإجابة: رقم الخيار ١–٤، أو صحّ وخطأ. */
enum AnswerChoice: Codable, Equatable, Sendable {
    case option(Int)
    case truth(Bool)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .truth(b) } else { self = .option(try c.decode(Int.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .option(let n): try c.encode(n)
        case .truth(let b): try c.encode(b)
        }
    }

    var json: String {
        switch self {
        case .option(let n): String(n)
        case .truth(let b): b ? "true" : "false"
        }
    }
}

struct PersonaWire: Codable, Equatable, Sendable {
    var expression: String
    var head: String
    var eye: String
    var neck: String

    var persona: Persona {
        Persona(
            expression: FaceExpression(rawValue: expression) ?? .smile,
            head: HeadOutfit(rawValue: head) ?? .none,
            eye: EyeOutfit(rawValue: eye) ?? .none,
            neck: NeckOutfit(rawValue: neck) ?? .none
        )
    }

    init(_ p: Persona) {
        expression = p.expression.rawValue
        head = p.head.rawValue
        eye = p.eye.rawValue
        neck = p.neck.rawValue
    }
}

/// الكروت السبعة (RULES-cards.md، 03-schema: Card.type).
enum CardType: String, Codable, Sendable, CaseIterable {
    case burn
    case swapQuestion = "swap_question"
    case anyAnswer = "any_answer"
    case clearSquares = "clear_squares"
    case fortify
    case doubleCross = "double_cross"
    case placeAnywhere = "place_anywhere"
    // نافذة كل كرت يحكمها المحرّك (engine.ts: cardBlock)، ويصل حكمها في CardView.blocked
}

struct CardView: Codable, Equatable, Sendable, Identifiable {
    var id: Int
    var type: CardType
    var clearCount: Int?
    /// لصاحب الكرت وحده: لماذا لا يُلعب الآن، من حكم المحرّك نفسه (engine.ts: cardBlock). بلا قيمة: يُلعب.
    var blocked: String?
}

struct SeatView: Codable, Equatable, Sendable, Identifiable {
    var seatNo: Int
    var isBot: Bool
    var displayName: String
    var persona: PersonaWire
    var squares: Int
    var boxesLeft: Int
    var cards: [CardView]

    var id: Int { seatNo }
    /** لون المقعد من رقمه (05-ui §١). */
    var team: Team { Team(rawValue: seatNo) ?? .team1 }
}

struct QuestionView: Codable, Equatable, Sendable {
    var id: String
    var type: String // mcq | truefalse
    var text: String
    var options: [String]?
    var correct: AnswerChoice?

    var isTrueFalse: Bool { type == "truefalse" }
}

struct Square: Codable, Equatable, Hashable, Sendable {
    var row: Int
    var col: Int
}

struct GroupAnswerView: Codable, Equatable, Sendable {
    var seatNo: Int
    var choice: AnswerChoice
    var correct: Bool
}

struct BoxCardView: Codable, Equatable, Sendable {
    var type: CardType
    var clearCount: Int?
}

struct RoundView: Codable, Equatable, Sendable {
    var id: Int
    var type: String // turn | group
    var seatNo: Int?
    var question: QuestionView
    var deadline: Double
    var answer: AnswerChoice?
    var result: String? // correct | wrong | timeout | noWinner
    var chooser: Int?
    var choice: String? // square | box
    var centers: [Square]?
    var choiceDropped: Bool?
    var boxCard: BoxCardView?
    var played: [CardType]?
    var anyAnswer: Bool?
    var boardCard: CardType?
    var answeredSeats: [Int]?
    var myAnswer: AnswerChoice?
    var groupAnswers: [GroupAnswerView]?
    var winnerSeat: Int?
    /// في الاختيار، من المحرّك: عدد المراكز، وهل يجوز الصندوق.
    var centersNeeded: Int?
    var boxAllowed: Bool?

    var isGroup: Bool { type == "group" }
}

struct BurnWindowView: Codable, Equatable, Sendable {
    var seatNo: Int
    var cells: [Square]
    var decided: String?
}

struct PhaseView: Codable, Equatable, Sendable {
    var kind: String // countdown | answering | group | choosing | burn | display | ended
    var until: Double?
    var deadline: Double?
    var reason: String?
    var windows: [BurnWindowView]?
}

struct FortificationView: Codable, Equatable, Sendable, Identifiable {
    var id: Int
    var ownerSeat: Int
    var center: Square
    var cells: [Square]
    var turnsLeft: Int
}

struct RankRow: Codable, Equatable, Sendable {
    var seatNo: Int
    var squares: Int
    var rank: Int
}

/** المهل كما يحكم بها المحرّك (بالمللي ثانية). */
struct MatchTimes: Codable, Equatable, Sendable {
    var answer: Double
    var choose: Double
    var display: Double
    var countdown: Double
    var burn: Double
}

struct MatchView: Codable, Equatable, Sendable {
    var size: Int
    var boardSize: Int
    var cycle: Int
    var cyclesTotal: Int
    var groupEnabled: Bool
    var times: MatchTimes
    var board: [Int]
    var seats: [SeatView]
    var order: [Int]
    var fortifications: [FortificationView]
    var phase: PhaseView
    var round: RoundView?
    var ranking: [RankRow]?

    func seat(_ no: Int) -> SeatView? { seats.first { $0.seatNo == no } }
    func owner(_ row: Int, _ col: Int) -> Int { board[row * boardSize + col] }
    func owner(_ square: Square) -> Int { owner(square.row, square.col) }

    /// المربعات المحصّنة الآن (RULES-cards §٥).
    var fortified: Set<Square> { Set(fortifications.flatMap(\.cells)) }
}
