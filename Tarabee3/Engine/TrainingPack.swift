import Foundation

/// حزمة أسئلة التدريب (R-45): تُشحن مع التطبيق، ويجدّدها من الخادم عند الاتصال إن تغيّر رقم نسختها،
/// وتُحفظ على الجهاز فيعمل التدريب بلا إنترنت. والمشحونة الآن مؤقتة حتى يرفع المالك قسم التدريب.
enum TrainingPack {
    /// أقل ما يكفي أطول مباراة (training.ts: questionsNeeded للخماسية). يحرسه اختبار يقارنه بالمحرّك نفسه.
    static let minimumQuestions = 65

    private static var savedURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("training-pack.json")
    }

    /// المحفوظة من الخادم إن وُجدت وكفت، وإلا المشحونة مع التطبيق.
    static func current() -> (version: String, questionsJSON: String)? {
        for data in [savedURL.flatMap { try? Data(contentsOf: $0) }, bundled()] {
            if let data, let pack = parse(data) { return pack }
        }
        return nil
    }

    private static func bundled() -> Data? {
        Bundle.main.url(forResource: "training-pack", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }

    /// كل سؤال يُفحص بشكله: المعطوب يُستبعد، فلا يجمّد التدريب (مراجعة M-04، المشكلة ٥).
    static func isValid(_ q: [String: Any]) -> Bool {
        guard let id = q["id"] as? String, !id.isEmpty,
              let text = q["text"] as? String, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch q["type"] as? String {
        case "truefalse":
            return q["correct"] is Bool
        case "mcq":
            guard let options = q["options"] as? [String], options.count == 4, Set(options).count == 4,
                  !options.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }),
                  let number = q["correct"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                  (1...4).contains(number.intValue), Double(number.intValue) == number.doubleValue else { return false }
            return true
        default:
            return false
        }
    }

    static func parse(_ data: Data) -> (version: String, questionsJSON: String)? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["version"] as? String,
              let raw = object["questions"] as? [[String: Any]] else { return nil }
        let questions = raw.filter(isValid)
        guard questions.count >= minimumQuestions,
              let json = try? JSONSerialization.data(withJSONObject: questions),
              let text = String(data: json, encoding: .utf8) else { return nil }
        return (version, text)
    }

    /// يطلب الحزمة من الخادم بنسخته الحالية؛ ويحفظها إن تغيّرت وكفت. الفشل صامت: التدريب يعمل بما عنده.
    static func refresh(api: ServerAPI, token: String) async {
        let known = current()?.version ?? ""
        var request = URLRequest(url: api.baseURL.appending(path: "training-pack").appending(queryItems: [URLQueryItem(name: "version", value: known)]))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await api.session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              parse(data) != nil, let url = savedURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
