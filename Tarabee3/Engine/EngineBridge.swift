import Foundation
import JavaScriptCore

/// جسر المحرّك (القرار 0019): المحرّك نفسه بـ TypeScript، محزوماً في engine.js (tools/build-engine.mjs)،
/// يعمل في محرّك جافاسكربت المدمج في آيفون. التطبيق يكلّمه بنصوص JSON ولا يعرف قواعد اللعب.
@MainActor
final class EngineBridge {
    struct Output: Sendable {
        /// حالة المحرّك كاملة نصّاً، تُعاد إليه في الاستدعاء التالي ولا يقرؤها التطبيق.
        let state: String
        let view: MatchView
        let events: [Event]
        let rejected: String?
    }

    struct Event: Codable, Sendable, Equatable {
        var type: String
        var at: Double
        var seatNo: Int?
        var correct: Bool?
    }

    enum BridgeError: Error { case missingBundle, javascript(String), badOutput }

    private let context: JSContext
    private let bridge: JSValue

    init(source: String? = nil) throws {
        let code: String
        if let source {
            code = source
        } else {
            guard let url = Bundle.main.url(forResource: "engine", withExtension: "js"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { throw BridgeError.missingBundle }
            code = text
        }
        guard let context = JSContext() else { throw BridgeError.javascript("no context") }
        var failure: String?
        context.exceptionHandler = { _, value in failure = value?.toString() }
        context.evaluateScript(code)
        if let failure { throw BridgeError.javascript(failure) }
        guard let bridge = context.objectForKeyedSubscript("Tarabee3Engine")?.objectForKeyedSubscript("bridge"),
              !bridge.isUndefined else { throw BridgeError.javascript("Tarabee3Engine.bridge missing") }
        self.context = context
        self.bridge = bridge
    }

    /// viewer: المقعد الذي يُعرض له (منه «إجابتي» في الجماعية).
    func createTraining(setupJSON: String, now: Double, viewer: Int) throws -> Output {
        try call("createTraining", [setupJSON, now, viewer])
    }

    func tick(state: String, now: Double, viewer: Int) throws -> Output {
        try call("tick", [state, now, viewer])
    }

    func answer(state: String, seatNo: Int, choice: AnswerChoice, now: Double) throws -> Output {
        try call("answer", [state, seatNo, choice.json, now])
    }

    /// مربع بمركز أو مركزين، أو صندوق (R-21، R-36).
    func choose(state: String, seatNo: Int, centers: [Square], now: Double) throws -> Output {
        struct Pick: Encodable { var kind = "square"; var centers: [Square] }
        let pick = String(data: try JSONEncoder().encode(Pick(centers: centers)), encoding: .utf8) ?? "{}"
        return try call("choose", [state, seatNo, pick, now])
    }

    func openBox(state: String, seatNo: Int, now: Double) throws -> Output {
        try call("choose", [state, seatNo, "{\"kind\":\"box\"}", now])
    }

    /// كرت في نافذته، بحمولته: مربعات التفريغ أو مركز التحصين (RULES-cards).
    func playCard(state: String, seatNo: Int, cardId: Int, cells: [Square] = [], center: Square? = nil, now: Double) throws -> Output {
        struct Target: Encodable { var cells: [Square]; var center: Square? }
        let target = String(data: try JSONEncoder().encode(Target(cells: cells, center: center)), encoding: .utf8) ?? "{}"
        return try call("playCard", [state, seatNo, cardId, target, now])
    }

    /// قرار المتضرّر في نافذة الحرق (R-40).
    func decideBurn(state: String, seatNo: Int, burn: Bool, now: Double) throws -> Output {
        try call("decideBurn", [state, seatNo, burn, now])
    }

    /// مربعات الصليب من المحرّك نفسه، للمعاينة قبل الحكم (R-23)؛ لا قاعدة لعب في سويفت (القاعدة ٥).
    func crossCells(boardSize: Int, center: Square) -> [Square] {
        guard let text = bridge.invokeMethod("crossCells", withArguments: [boardSize, center.row, center.col])?.toString(),
              let data = text.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Square].self, from: data)) ?? []
    }

    /// اللوح المقترح بالحجم، من المحرّك (R-08).
    func suggestedBoard(size: Int) -> Int {
        Int(bridge.invokeMethod("suggestedBoard", withArguments: [size])?.toInt32() ?? 9)
    }

    /// أسئلة تكفي أطول مباراة بالحجم (training.ts: questionsNeeded).
    func questionsNeeded(size: Int) -> Int {
        Int(bridge.invokeMethod("questionsNeeded", withArguments: [size])?.toInt32() ?? 0)
    }

    private func call(_ name: String, _ args: [Any]) throws -> Output {
        var failure: String?
        context.exceptionHandler = { _, value in failure = value?.toString() }
        let result = bridge.invokeMethod(name, withArguments: args)
        if let failure { throw BridgeError.javascript(failure) }
        guard let text = result?.toString(), let data = text.data(using: .utf8) else { throw BridgeError.badOutput }
        struct Raw: Decodable { let state: String; let view: MatchView; let events: [Event]; let rejected: String? }
        do {
            let raw = try JSONDecoder().decode(Raw.self, from: data)
            return Output(state: raw.state, view: raw.view, events: raw.events, rejected: raw.rejected)
        } catch {
            throw BridgeError.badOutput
        }
    }
}
