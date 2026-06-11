import Foundation

/// User-configured AI backend for the command bar's remote dispatch.
///
/// Targets any OpenAI-compatible `/chat/completions` endpoint — OpenAI itself,
/// a local Ollama server (`http://localhost:11434/v1`), or any compatible proxy.
/// The API key is stored separately (Keychain), never in this value.
struct AIEndpoint: Codable, Equatable {
    /// Base URL including the API version segment, e.g.
    /// `https://api.openai.com/v1` or `http://localhost:11434/v1`.
    var baseURL: String
    /// Model identifier, e.g. `gpt-4o-mini` or `llama3`.
    var model: String

    static let empty = AIEndpoint(baseURL: "", model: "")

    /// Common presets surfaced in Settings.
    static let openAI = AIEndpoint(baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini")
    static let ollama = AIEndpoint(baseURL: "http://localhost:11434/v1", model: "llama3")

    /// The chat-completions URL, or `nil` if `baseURL` is not a valid URL.
    var chatCompletionsURL: URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: normalized + "/chat/completions")
    }

    /// Whether this endpoint is complete enough to dispatch to.
    var isConfigured: Bool {
        !model.trimmingCharacters(in: .whitespaces).isEmpty && chatCompletionsURL != nil
    }
}
