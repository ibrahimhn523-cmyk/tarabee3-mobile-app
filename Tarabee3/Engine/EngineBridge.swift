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

    func createTraining(setupJSON: String, now: Double) throws -> Output {
        try call("createTraining", [setupJSON, now])
    }

    func tick(state: String, now: Double) throws -> Output {
        try call("tick", [state, now])
    }

    func answer(state: String, seatNo: Int, choice: AnswerChoice, now: Double) throws -> Output {
        try call("answer", [state, seatNo, choice.json, now])
    }

    func choose(state: String, seatNo: Int, square: Square, now: Double) throws -> Output {
        try call("choose", [state, seatNo, square.row, square.col, now])
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
