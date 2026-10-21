import Foundation
import Observation

/// أحجام المباراة السريعة، و«أي حجم متاح» (R-06).
enum SizePref: String, CaseIterable, Hashable, Sendable {
    case three = "3", four = "4", five = "5", any
}

/// طلب مباراة جديدة بعد النتيجة كما يراه هذا الجوال (R-35).
struct RematchPrompt: Equatable {
    var until: Double
    /// ردّي إن رددت.
    var mine: Bool?
    /// حُسم ولم أذهب لمباراة جديدة.
    var closed: Bool
}

/// المباراة السريعة أون لاين (M-06، M-07): اتصال دائم بكائن المطابقة ثم بكائن المباراة، برمز هوية فايربيس في رأس
/// الاتصال (قرار M-06 الثاني) لا في العنوان. الحَكَم في الخادم، والجوال يعرض ما يصله ويرسل طلبات.
/// وإن انقطع أثناء المباراة عاد وحده (R-44، 04-tech §٢: خلال خمس ثوانٍ من عودة الشبكة).
@MainActor
@Observable
final class OnlineSession: MatchSession, Identifiable {
    enum Stage: Equatable {
        case idle
        case searching(until: Double)
        case playing
        case failed(String)
    }

    /// العنوان ورمز الهوية: من الخلفية عند كل اتصال، فالرمز طازج.
    typealias Endpoint = () async throws -> (base: URL, token: String)

    /// المباراة الجارية محفوظة على الجهاز: فتح التطبيق ومباراته قائمة يعيده إليها (S-02).
    static let currentMatchKey = "tarabee3.currentMatch"

    private(set) var stage: Stage = .idle
    private(set) var size: SizePref = .any
    private(set) var view: MatchView?
    private(set) var mySeat = 0
    var preview: [Square] = []
    var previewCells: Set<Square> = []
    var sentAnswer: AnswerChoice?
    var targeting: CardTargeting?
    private(set) var lastRejection: String?
    private(set) var replies: [ReplyBubble] = []
    let repliesEnabled = true
    /// اكتمل العدد بآليين: يُقال مرة في أول المباراة (05-ui §١٠).
    private(set) var filledWithBots = false
    /// انقطع الاتصال ونحاول العودة: غطاء «إعادة الاتصال» (05-ui §٦).
    private(set) var reconnecting = false
    /// عاد الاتصال للتوّ: يُقال ثانيتين.
    private(set) var reconnectedUntil: Double = 0
    /// انتهت المباراة وهو منقطع (S-09).
    private(set) var endedWhileAway = false
    private(set) var rematch: RematchPrompt?
    /// أسماء من رفض أو سكت، يُبحث عن بدلائهم (05-ui §١٠ «بديل من الخارج»).
    private(set) var replacing: [String] = []
    private(set) var matchId: String?
    /// من بلّغتُ عنهم في هذه المباراة (R-60)، ومتى يُقال «وصل بلاغك.».
    private(set) var reportedSeats: Set<Int> = []
    private(set) var reportedUntil: Double = 0

    private let endpoint: Endpoint
    private let session: URLSession
    private let defaults: UserDefaults
    private let bridge = try? EngineBridge()
    private var socket: URLSessionWebSocketTask?
    /// فرق ساعة الخادم عن ساعة الجهاز (04-tech §٢: تزامن المؤقّت).
    private var offset: Double = 0
    private var hasOffset = false
    private var lastReplyAt: Double = -.infinity
    private var replyCounter = 0
    private var warnedLastFive = false
    private var withdrew = false
    private var reconnectAttempts = 0

    init(endpoint: @escaping Endpoint, session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.endpoint = endpoint
        self.session = session
        self.defaults = defaults
    }

    var now: Double { Date().timeIntervalSince1970 * 1000 + offset }

    var failureText: String? {
        if case .failed(let text) = stage { return text }
        return nil
    }

    // MARK: - البحث والعودة

    /// S-06: يبحث بحجم؛ وبعد ثلاثين ثانية يُكمل الخادم بآليين (R-07). ومن وافق على مباراة جديدة يأتي بمعرّف سابقتها.
    func search(_ size: SizePref, rematchOf previous: String? = nil) {
        self.size = size
        view = nil
        mySeat = 0
        reportedSeats = []
        filledWithBots = false
        endedWhileAway = false
        rematch = nil
        if previous == nil { replacing = [] }
        stage = .searching(until: now + (previous == nil ? 30_000 : 20_000))
        hasOffset = false
        var query = [URLQueryItem(name: "size", value: size.rawValue)]
        if let previous { query.append(URLQueryItem(name: "rematch", value: previous)) }
        Task { await connect(path: "play", query: query) }
    }

    /// يعود لمباراة قائمة من الرئيسية (S-02 «عودة»).
    func rejoin(_ id: String) {
        matchId = id
        stage = .playing
        reconnecting = true
        Task { await connect(path: "match/\(id)") }
    }

    func cancel() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        stage = .idle
        reconnecting = false
    }

    /// الانسحاب نهائي، ويحلّ آلي مكانه (R-43).
    func withdraw() {
        withdrew = true
        write(["t": "withdraw"])
        forgetMatch()
        let task = socket
        socket = nil
        // يُغلق بعد أن تخرج الرسالة
        Task { try? await Task.sleep(for: .milliseconds(300)); task?.cancel(with: .normalClosure, reason: nil) }
        stage = .idle
    }

    private func forgetMatch() {
        defaults.removeObject(forKey: Self.currentMatchKey)
    }

    private func connect(path: String, query: [URLQueryItem] = []) async {
        do {
            let (base, token) = try await endpoint()
            guard var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.scheme = components.scheme == "http" ? "ws" : "wss"
            if !query.isEmpty { components.queryItems = query }
            guard let url = components.url else { throw URLError(.badURL) }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let task = session.webSocketTask(with: request)
            socket?.cancel(with: .goingAway, reason: nil)
            socket = task
            task.resume()
            await receive(task)
        } catch {
            lost(nil)
        }
    }

    private func receive(_ task: URLSessionWebSocketTask) async {
        while socket === task {
            guard let message = try? await task.receive() else {
                if socket === task { lost(task) }
                return
            }
            let data: Data? = switch message {
            case .string(let text): text.data(using: .utf8)
            case .data(let data): data
            @unknown default: nil
            }
            if let data { receive(data) }
        }
    }

    /// انقطع الاتصال: أثناء البحث يُلغى ويعود للرئيسية برسالة (S-06)، وأثناء المباراة يعود وحده (R-44).
    private func lost(_ task: URLSessionWebSocketTask?) {
        if task != nil { socket = nil }
        guard stage != .idle, !withdrew else { return }
        if case .searching = stage { return fail(Copy.Status.noInternet) }
        guard let id = matchId, view?.phase.kind != "ended" else { return }
        reconnecting = true
        reconnectAttempts += 1
        // دقيقتان من المحاولات: بعدها تكون المباراة قد أُلغيت أو انتهت (R-71)
        guard reconnectAttempts <= 60 else { return fail(Copy.Online.disconnected) }
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard self.stage == .playing, self.socket == nil, !self.withdrew else { return }
            await self.connect(path: "match/\(id)")
        }
    }

    private func fail(_ text: String) {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        reconnecting = false
        stage = .failed(text)
    }

    // MARK: - رسائل الخادم

    private struct ServerMessage: Decodable {
        var t: String
        var now: Double
        var seat: Int?
        var view: MatchView?
        var id: Int?
        var reason: String?
        var matchId: String?
        var until: Double?
        var responses: [String: String]?
        var go: Bool?
        var size: Int?
        var previousMatchId: String?
    }

    /// رسالة من الخادم كما وصلت (والاختبار يمرّرها مباشرة).
    func receive(_ data: Data) {
        if let decoded = try? JSONDecoder().decode(ServerMessage.self, from: data) { handle(decoded) }
    }

    /// ما يُرسل للخادم يمرّ هنا أيضاً إن وُجد (للاختبار).
    var onSend: ((String) -> Void)?

    private func handle(_ m: ServerMessage) {
        // ساعة الخادم في كل رسالة (R-68). كل عيّنة أصغر من الفرق الحقيقي بزمن وصولها، فأكبرها أقربها إليه،
        // ورسالة تأخّرت في الشبكة لا تُرجع العدّاد (مراجعة M-06، المشكلة ٥). وتُبدأ من جديد مع كل اتصال
        let sample = m.now - Date().timeIntervalSince1970 * 1000
        offset = hasOffset ? max(offset, sample) : sample
        hasOffset = true
        switch m.t {
        case "waiting":
            if let until = m.until { stage = .searching(until: until) }
        case "matched":
            guard let id = m.matchId else { return }
            // يُترك اتصال المطابقة قبل أي انتظار: إغلاقه من الخادم لم يعد انقطاعاً (مراجعة M-06، المشكلة ٣)
            socket = nil
            hasOffset = false
            matchId = id
            defaults.set(id, forKey: Self.currentMatchKey)
            Task { await connect(path: "match/\(id)") }
        case "failed":
            fail(m.reason == "no_questions" ? Copy.Online.noQuestions : Copy.Status.serverError)
        case "state":
            guard let next = m.view, let seat = m.seat else { return }
            apply(next, seat: seat)
        case "reply":
            guard let seat = m.seat, let reply = m.id else { return }
            replyCounter += 1
            replies = replies.filter { $0.until > now && $0.seat != seat } + [ReplyBubble(id: replyCounter, seat: seat, reply: reply, until: now + 2000)]
        case "rejected":
            lastRejection = m.reason
        case "rematch":
            handleRematch(m)
        case "reported":
            if let seat = m.seat { reportedSeats.insert(seat) }
            reportedUntil = now + 2000
        default:
            break
        }
    }

    private func handleRematch(_ m: ServerMessage) {
        guard let until = m.until else { return }
        let mine = (m.responses?[String(mySeat)]).map { $0 == "accepted" }
        if m.go == true, let n = m.size, let size = SizePref(rawValue: String(n)), let previous = m.previousMatchId {
            // من رفض أو سكت يُبحث عن بديله عشرين ثانية ثم آلي (R-35)
            replacing = (view?.seats ?? []).filter { !$0.isBot && $0.seatNo != mySeat && m.responses?[String($0.seatNo)] != "accepted" }.map(\.displayName)
            socket?.cancel(with: .normalClosure, reason: nil)
            socket = nil
            matchId = nil
            search(size, rematchOf: previous)
            return
        }
        rematch = RematchPrompt(until: until, mine: mine ?? rematch?.mine, closed: m.go == false)
    }

    private func apply(_ next: MatchView, seat: Int) {
        let previous = view
        if previous == nil {
            stage = .playing
            filledWithBots = next.seats.contains { $0.isBot }
        }
        if reconnecting {
            reconnecting = false
            reconnectAttempts = 0
            reconnectedUntil = now + 2000
            // عاد وقد انتهت: «انتهت المباراة. حُسبت في ملفك.» (S-09)
            if next.phase.kind == "ended", previous?.phase.kind != "ended" { endedWhileAway = true }
        }
        mySeat = seat
        view = next
        if next.round?.id != previous?.round?.id {
            warnedLastFive = false
            if next.round?.type == "turn" && next.round?.seatNo == seat { Haptics.play(Tokens.Haptics.yourTurn) }
        }
        resetLocal(for: next, previous: previous)
        if previous?.phase.kind != "burn", myBurnWindow != nil { Haptics.play(Tokens.Haptics.burnOpen) }
        if isMyTurn || canAnswerGroup, let deadline = next.phase.deadline, deadline - now <= 5000, !warnedLastFive {
            warnedLastFive = true
            Haptics.play(Tokens.Haptics.lastFive)
        }
        // انتهت: لا عودة إليها من الرئيسية. والاتصال يبقى لطلب المباراة الجديدة
        if next.phase.kind == "ended" { forgetMatch() }
    }

    // MARK: - الطلبات

    func send(_ action: MatchAction) {
        var message: [String: Any]
        switch action {
        case .answer(let choice): message = ["t": "answer", "choice": choice.jsonValue]
        case .choose(let centers): message = ["t": "choose", "pick": ["kind": "square", "centers": centers.map(\.jsonValue)]]
        case .openBox: message = ["t": "choose", "pick": ["kind": "box"]]
        case .card(let id, let cells, let center):
            var target: [String: Any] = ["cells": cells.map(\.jsonValue)]
            if let center { target["center"] = center.jsonValue }
            message = ["t": "card", "id": id, "target": target]
        case .burn(let burn): message = ["t": "burn", "burn": burn]
        }
        write(message)
    }

    /// بلاغ عن اسم مقعد (R-60): مرة لكل لاعب في المباراة.
    func report(seat: Int) {
        guard seat != mySeat, !reportedSeats.contains(seat) else { return }
        write(["t": "report", "seat": seat])
    }

    /// ردّي على طلب المباراة الجديدة (R-35).
    func respondRematch(_ accept: Bool) {
        guard var r = rematch, r.mine == nil, !r.closed, now < r.until else { return }
        r.mine = accept
        rematch = r
        write(["t": "rematch", "accept": accept])
    }

    /// «بعد الإرسال: مقفلة ثلاث ثوانٍ» (05-ui §٦)؛ والخادم يفرضها كذلك.
    var canReply: Bool { stage == .playing && !reconnecting && now - lastReplyAt >= 3000 && view?.phase.kind != "ended" }

    func sendReply(_ reply: Int) {
        guard canReply else { return }
        lastReplyAt = now
        write(["t": "reply", "id": reply])
    }

    private func write(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: .sortedKeys), let text = String(data: data, encoding: .utf8) else { return }
        onSend?(text)
        socket?.send(.string(text)) { _ in }
    }

    func crossCells(_ center: Square) -> [Square] {
        guard let view, let bridge else { return [center] }
        return bridge.crossCells(boardSize: view.boardSize, center: center)
    }
}

private extension AnswerChoice {
    var jsonValue: Any {
        switch self {
        case .option(let n): n
        case .truth(let b): b
        }
    }
}

private extension Square {
    var jsonValue: [String: Int] { ["row": row, "col": col] }
}
