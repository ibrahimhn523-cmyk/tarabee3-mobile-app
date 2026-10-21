import Foundation

/// استهداف كرت يحتاج مربعات قبل لعبه (RULES-cards): التفريغ بعدده، أو مركز التحصين.
enum CardTargeting: Equatable {
    case clear(cardId: Int, count: Int, selected: [Square])
    case fortify(cardId: Int, center: Square?)
}

/// طلب من اللاعب إلى الحَكَم: المحرّك على الجهاز في التدريب، أو كائن المباراة أون لاين.
enum MatchAction: Equatable {
    case answer(AnswerChoice)
    case choose([Square])
    case openBox
    case card(id: Int, cells: [Square], center: Square?)
    case burn(Bool)
}

/// ردّ جاهز ظاهر فوق شارة مرسله ثانيتين (05-ui §٦).
struct ReplyBubble: Equatable, Identifiable {
    let id: Int
    let seat: Int
    let reply: Int
    let until: Double
}

/// جلسة مباراة تعرضها شاشات المباراة نفسها، تدريباً أو أون لاين (القرار 0019): الحكم كله في العرض الذي يرسله
/// الحَكَم، والجلسة تحفظ ما على هذا الجهاز وحده (المعاينة والاستهداف) وترسل الطلبات. لا قاعدة لعب هنا (القاعدة ٥).
@MainActor
protocol MatchSession: AnyObject {
    var view: MatchView? { get }
    /// تعذّر اللعب: رسالة بدل شاشة متجمّدة.
    var failureText: String? { get }
    var mySeat: Int { get }
    /// ساعة الحَكَم بالمللي ثانية: ساعة الجهاز في التدريب، وساعة الخادم بفرقها أون لاين (R-68).
    var now: Double { get }
    var preview: [Square] { get set }
    var previewCells: Set<Square> { get set }
    var sentAnswer: AnswerChoice? { get set }
    var targeting: CardTargeting? { get set }
    var lastRejection: String? { get }
    /// الردود الجاهزة: أون لاين وحده (R-34).
    var replies: [ReplyBubble] { get }
    var repliesEnabled: Bool { get }
    var canReply: Bool { get }
    func sendReply(_ reply: Int)
    func send(_ action: MatchAction)
    /// مربعات صليب حول مركز، من المحرّك نفسه للمعاينة.
    func crossCells(_ center: Square) -> [Square]
}

extension MatchSession {
    var failed: Bool { failureText != nil }
    var me: SeatView? { view?.seat(mySeat) }
    var phase: String { view?.phase.kind ?? "" }
    var isMyTurn: Bool { view?.round?.type == "turn" && view?.round?.seatNo == mySeat }
    /// أنا من يختار الآن: صاحب الدور المصيب، أو فائز الجماعية.
    var isChooser: Bool { phase == "choosing" && view?.round?.chooser == mySeat }
    var myBurnWindow: BurnWindowView? {
        view?.phase.windows?.first { $0.seatNo == mySeat && $0.decided == nil }
    }
    var canAnswerGroup: Bool { phase == "group" && view?.round?.myAnswer == nil }

    /// هل يُلعب هذا الكرت الآن؟ ومع الرفض سببه (05-ui §٦ «الكرت»: ليس وقته: خافت مع السبب).
    /// الحكم من الحَكَم في العرض (blocked)، والتطبيق يترجمه نصّاً فقط (القاعدة ٥).
    func playability(_ card: CardView) -> (ok: Bool, reason: String?) {
        guard let blocked = card.blocked else { return (targeting == nil, nil) }
        return (false, Copy.Cards.blocked(blocked))
    }

    func answer(_ choice: AnswerChoice) {
        let group = canAnswerGroup
        guard group || (phase == "answering" && isMyTurn && sentAnswer == nil && targeting == nil) else { return }
        if !group { sentAnswer = choice }
        Haptics.play(Tokens.Haptics.send)
        send(.answer(choice))
    }

    /// المربعات التي يجيزها الحَكَم الآن لهذا المقعد (view.targets).
    private func allowed(_ indices: [Int]?, _ square: Square) -> Bool {
        guard let view, let indices else { return false }
        return indices.contains(square.row * view.boardSize + square.col)
    }

    /// الضغطة تعاين، والاعتماد زرّ مستقل (05-ui §١٦). الحَكَم يقول أيّ مربع يجوز، وكم مركزاً (اثنان بـ «صليبان»).
    func select(_ square: Square) {
        if let targeting { return target(square, targeting) }
        guard isChooser, allowed(view?.targets?.centers, square) else { return }
        if let i = preview.firstIndex(of: square) {
            if centersNeeded > 1 { preview.remove(at: i) }
        } else {
            preview = Array((preview + [square]).suffix(centersNeeded))
        }
        previewCells = Set(preview.flatMap { crossCells($0) })
    }

    private var centersNeeded: Int { view?.round?.centersNeeded ?? 1 }
    var canCommit: Bool { isChooser && preview.count == centersNeeded }
    var canOpenBox: Bool { isChooser && view?.round?.boxAllowed == true }

    func commit() {
        guard canCommit else { return }
        Haptics.play(Tokens.Haptics.commit)
        send(.choose(preview))
    }

    func openBox() {
        guard canOpenBox else { return }
        Haptics.play(Tokens.Haptics.commit)
        send(.openBox)
    }

    /// يلعب الكرت؛ وما يحتاج مربعات يدخل وضع الاستهداف أولاً.
    func play(_ card: CardView) {
        guard playability(card).ok else { return }
        switch card.type {
        case .clearSquares: targeting = .clear(cardId: card.id, count: card.clearCount ?? 1, selected: [])
        case .fortify: targeting = .fortify(cardId: card.id, center: nil)
        default: send(.card(id: card.id, cells: [], center: nil))
        }
    }

    private func target(_ square: Square, _ mode: CardTargeting) {
        switch mode {
        case .clear(let id, let count, var selected):
            // مملوك وخارج التحصين (RULES-cards §٤) — بحكم الحَكَم
            guard allowed(view?.targets?.clear, square) else { return }
            if let i = selected.firstIndex(of: square) { selected.remove(at: i) } else { selected = Array((selected + [square]).suffix(count)) }
            targeting = .clear(cardId: id, count: count, selected: selected)
        case .fortify(let id, _):
            targeting = .fortify(cardId: id, center: square)
        }
    }

    var targetReady: Bool {
        switch targeting {
        case .clear(_, let count, let selected): selected.count == count
        case .fortify(_, let center): center != nil
        case nil: false
        }
    }

    /// مربعات الاستهداف المعروضة على اللوح.
    var targetCells: Set<Square> {
        switch targeting {
        case .clear(_, _, let selected): Set(selected)
        case .fortify(_, let center?): Set(crossCells(center))
        default: []
        }
    }

    func confirmTarget() {
        guard targetReady, let mode = targeting else { return }
        targeting = nil
        switch mode {
        case .clear(let id, _, let selected): send(.card(id: id, cells: selected, center: nil))
        case .fortify(let id, let center): send(.card(id: id, cells: [], center: center))
        }
    }

    func cancelTarget() { targeting = nil }

    /// قرار نافذة الحرق (R-40): الصمت لا يحرق.
    func decideBurn(_ burn: Bool) {
        guard myBurnWindow != nil else { return }
        send(.burn(burn))
    }

    /// ما يتغيّر على هذا الجهاز حين يصل عرض جديد: المعاينة والاستهداف والإجابة المرسلة تخصّ دوراً بعينه.
    func resetLocal(for next: MatchView, previous: MatchView?) {
        if next.round?.id != previous?.round?.id {
            sentAnswer = nil
            targeting = nil
        }
        if next.round?.id != previous?.round?.id || next.phase.kind != "choosing" || next.round?.chooser != mySeat {
            preview = []
            previewCells = []
        }
        if next.phase.kind != "answering" { targeting = nil }
    }
}
