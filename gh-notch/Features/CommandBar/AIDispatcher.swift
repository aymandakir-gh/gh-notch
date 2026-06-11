import Foundation

/// Sends a free-form prompt to a configured AI backend and returns the reply.
protocol AIDispatching {
    func complete(prompt: String) async throws -> String
}

/// Errors surfaced to the user when remote dispatch fails.
enum AIDispatchError: LocalizedError, Equatable {
    case notConfigured
    case invalidURL
    case http(Int)
    case emptyResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "No AI endpoint configured. Open Settings to add one."
        case .invalidURL: return "The endpoint URL is invalid."
        case .http(let code): return "The server returned HTTP \(code)."
        case .emptyResponse: return "The model returned an empty response."
        case .decoding: return "Could not read the model's response."
        }
    }
}

/// Dispatcher for any OpenAI-compatible `/chat/completions` endpoint.
///
/// Works with OpenAI, Ollama's OpenAI-compatible API, and most proxies. The
/// `URLSession` is injectable so the request/response handling is unit-tested
/// with a stub `URLProtocol` (no network).
struct OpenAICompatibleDispatcher: AIDispatching {
    let endpoint: AIEndpoint
    let apiKey: String
    let session: URLSession

    init(endpoint: AIEndpoint, apiKey: String, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.session = session
    }

    func complete(prompt: String) async throws -> String {
        guard endpoint.isConfigured else { throw AIDispatchError.notConfigured }
        guard let url = endpoint.chatCompletionsURL else { throw AIDispatchError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let body = RequestBody(model: endpoint.model, messages: [.init(role: "user", content: prompt)])
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw AIDispatchError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIDispatchError.http(http.statusCode) }

        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            throw AIDispatchError.decoding
        }
        let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let content, !content.isEmpty else { throw AIDispatchError.emptyResponse }
        return content
    }

    // MARK: - Wire format (OpenAI chat-completions subset)

    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
    }

    private struct Message: Codable {
        let role: String
        let content: String
    }

    private struct ResponseBody: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let message: ResponseMessage
        }
        struct ResponseMessage: Decodable {
            let content: String?
        }
    }
}
