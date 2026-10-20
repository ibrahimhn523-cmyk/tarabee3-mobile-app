import Foundation

/// حزمة أسئلة التدريب (R-45): تُشحن مع التطبيق، ويجدّدها من الخادم عند الاتصال إن تغيّر رقم نسختها،
/// وتُحفظ على الجهاز فيعمل التدريب بلا إنترنت. والمشحونة الآن مؤقتة حتى يرفع المالك قسم التدريب.
enum TrainingPack {
    /// أقل ما يكفي أطول مباراة (training.ts: questionsNeeded للخماسية).
    static let minimumQuestions = 55

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

    private static func parse(_ data: Data) -> (version: String, questionsJSON: String)? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["version"] as? String,
              let questions = object["questions"] as? [Any], questions.count >= minimumQuestions,
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
