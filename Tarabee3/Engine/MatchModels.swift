import Foundation

// عرض المباراة كما يرسله المحرّك (server/engine/view.ts)، أون لاين أو في التدريب (القرار 0019).
// الإجابة الصحيحة لا تكون فيه قبل انتهاء السؤال (R-30).

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

struct SeatView: Codable, Equatable, Sendable, Identifiable {
    var seatNo: Int
    var isBot: Bool
    var displayName: String
    var persona: PersonaWire
    var squares: Int

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

struct RoundView: Codable, Equatable, Sendable {
    var id: Int
    var seatNo: Int
    var question: QuestionView
    var deadline: Double
    var answer: AnswerChoice?
    var result: String? // correct | wrong | timeout
    var choice: Square?
    var choiceDropped: Bool?
}

struct PhaseView: Codable, Equatable, Sendable {
    var kind: String // countdown | answering | choosing | display | ended
    var until: Double?
    var deadline: Double?
    var reason: String?
}

struct RankRow: Codable, Equatable, Sendable {
    var seatNo: Int
    var squares: Int
    var rank: Int
}

struct MatchView: Codable, Equatable, Sendable {
    var size: Int
    var boardSize: Int
    var cycle: Int
    var cyclesTotal: Int
    var board: [Int]
    var seats: [SeatView]
    var order: [Int]
    var phase: PhaseView
    var round: RoundView?
    var ranking: [RankRow]?

    func seat(_ no: Int) -> SeatView? { seats.first { $0.seatNo == no } }
    func owner(_ row: Int, _ col: Int) -> Int { board[row * boardSize + col] }
}

/** المربعات التي يلوّنها صليب مركزه، كما في المحرّك (board.ts: crossCells). للمعاينة على جهاز صاحبه وحده (R-23). */
func crossCells(boardSize: Int, center: Square) -> [Square] {
    [center, Square(row: center.row - 1, col: center.col), Square(row: center.row + 1, col: center.col),
     Square(row: center.row, col: center.col - 1), Square(row: center.row, col: center.col + 1)]
        .filter { $0.row >= 0 && $0.row < boardSize && $0.col >= 0 && $0.col < boardSize }
}
