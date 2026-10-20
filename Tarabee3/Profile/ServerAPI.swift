import Foundation

/// أخطاء الحفظ والحذف كما يعرضها التطبيق.
enum ProfileError: Error, Equatable {
    case nameLength
    case nameUnavailable
    case offline
    case server
    case notConfigured
}

/// خادم ترابيع (Cloudflare): PUT /me يحفظ الاسم والشخصية، وDELETE /me يحذف الحساب. كل طلب برمز هوية فايربيس.
struct ServerAPI: Sendable {
    let baseURL: URL
    var session: URLSession = .shared

    /// عنوان الخادم من Info.plist (ServerBaseURL).
    static func fromBundle() -> ServerAPI? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ServerBaseURL") as? String,
              let url = URL(string: raw) else { return nil }
        return ServerAPI(baseURL: url)
    }

    func save(name: String, persona: Persona, token: String) async throws(ProfileError) -> Player {
        let body: [String: String] = [
            "name": name,
            "expression": persona.expression.rawValue,
            "accessoryHead": persona.head.rawValue,
            "accessoryEye": persona.eye.rawValue,
            "accessoryNeck": persona.neck.rawValue,
        ]
        let (data, status) = try await send("PUT", token: token, body: try? JSONSerialization.data(withJSONObject: body))
        switch status {
        case 200, 201:
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = object["id"] as? String else { throw .server }
            return Player(id: id, fields: object)
        case 400 where errorCode(data) == "name_length":
            throw .nameLength
        case 422:
            throw .nameUnavailable
        case 503:
            throw .notConfigured
        default:
            throw .server
        }
    }

    func delete(token: String) async throws(ProfileError) {
        let (_, status) = try await send("DELETE", token: token, body: nil)
        guard status == 204 else { throw status == 503 ? .notConfigured : .server }
    }

    private func send(_ method: String, token: String, body: Data?) async throws(ProfileError) -> (Data, Int) {
        var request = URLRequest(url: baseURL.appending(path: "me"))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        do {
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(error.code) {
            throw .offline
        } catch {
            throw .server
        }
    }

    private func errorCode(_ data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
    }
}
