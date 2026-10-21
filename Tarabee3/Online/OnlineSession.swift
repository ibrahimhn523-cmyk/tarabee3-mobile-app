import Foundation
import Observation

/// أحجام المباراة السريعة، و«أي حجم متاح» (R-06).
enum SizePref: String, CaseIterable, Hashable, Sendable {
    case three = "3", four = "4", five = "5", any
}

/// المباراة السريعة أون لاين (M-06): اتصال دائم بكائن المطابقة ثم بكائن المباراة، برمز هوية فايربيس في رأس
/// الاتصال (قرار M-06 الثاني) لا في العنوان. الحَكَم في الخادم، والجوال يعرض ما يصله ويرسل طلبات.
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

    private let endpoint: Endpoint
    private let session: URLSession
    private let bridge = try? EngineBridge()
    private var socket: URLSessionWebSocketTask?
    /// فرق ساعة الخادم عن ساعة الجهاز (04-tech §٢: تزامن المؤقّت).
    private var offset: Double = 0
    private var lastReplyAt: Double = -.infinity
    private var replyCounter = 0
    private var warnedLastFive = false

    init(endpoint: @escaping Endpoint, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    var now: Double { Date().timeIntervalSince1970 * 1000 + offset }

    var failureText: String? {
        if case .failed(let text) = stage { return text }
        return nil
    }

    // MARK: - البحث

    /// S-06: يبحث بحجم؛ وبعد ثلاثين ثانية يُكمل الخادم بآليين (R-07).
    func search(_ size: SizePref) {
        self.size = size
        view = nil
        mySeat = 0
        filledWithBots = false
        stage = .searching(until: now + 30_000)
        Task { await connect(path: "play", query: [URLQueryItem(name: "size", value: size.rawValue)]) }
    }

    func cancel() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        stage = .idle
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
            fail(Copy.Status.noInternet)
        }
    }

    private func receive(_ task: URLSessionWebSocketTask) async {
        while socket === task {
            guard let message = try? await task.receive() else {
                // أُغلق الاتصال: أثناء البحث يُلغى ويعود للرئيسية برسالة (S-06). والانقطاع أثناء المباراة في M-07
                if socket === task, stage != .idle, view?.phase.kind != "ended" { fail(Copy.Online.disconnected) }
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

    private func fail(_ text: String) {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
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
    }

    /// رسالة من الخادم كما وصلت (والاختبار يمرّرها مباشرة).
    func receive(_ data: Data) {
        if let decoded = try? JSONDecoder().decode(ServerMessage.self, from: data) { handle(decoded) }
    }

    /// ما يُرسل للخادم يمرّ هنا أيضاً إن وُجد (للاختبار).
    var onSend: ((String) -> Void)?

    private func handle(_ m: ServerMessage) {
        // ساعة الخادم في كل رسالة (R-68)
        offset = m.now - Date().timeIntervalSince1970 * 1000
        switch m.t {
        case "waiting":
            if let until = m.until { stage = .searching(until: until) }
        case "matched":
            guard let id = m.matchId else { return }
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
        default:
            break
        }
    }

    private func apply(_ next: MatchView, seat: Int) {
        let previous = view
        if previous == nil {
            stage = .playing
            filledWithBots = next.seats.contains { $0.isBot }
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
        if next.phase.kind == "ended" {
            socket?.cancel(with: .normalClosure, reason: nil)
            socket = nil
        }
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

    /// «بعد الإرسال: مقفلة ثلاث ثوانٍ» (05-ui §٦)؛ والخادم يفرضها كذلك.
    var canReply: Bool { stage == .playing && now - lastReplyAt >= 3000 && view?.phase.kind != "ended" }

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
