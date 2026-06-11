import XCTest
@testable import gh_notch

final class AISettingsTests: XCTestCase {

    // MARK: - AIEndpoint

    func testChatCompletionsURLAppendsPath() {
        let endpoint = AIEndpoint(baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini")
        XCTAssertEqual(endpoint.chatCompletionsURL?.absoluteString, "https://api.openai.com/v1/chat/completions")
    }

    func testChatCompletionsURLToleratesTrailingSlash() {
        let endpoint = AIEndpoint(baseURL: "http://localhost:11434/v1/", model: "llama3")
        XCTAssertEqual(endpoint.chatCompletionsURL?.absoluteString, "http://localhost:11434/v1/chat/completions")
    }

    func testIsConfigured() {
        XCTAssertFalse(AIEndpoint.empty.isConfigured)
        XCTAssertFalse(AIEndpoint(baseURL: "https://x.com/v1", model: "").isConfigured)
        XCTAssertFalse(AIEndpoint(baseURL: "", model: "m").isConfigured)
        XCTAssertTrue(AIEndpoint(baseURL: "https://x.com/v1", model: "m").isConfigured)
    }

    // MARK: - SettingsStore persistence

    func testSaveAndReloadRoundTrips() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let secrets = InMemorySecretStore()

        let store = SettingsStore(defaults: defaults, secrets: secrets)
        store.endpoint = AIEndpoint(baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini")
        store.apiKey = "sk-test-123"
        store.save()

        let reloaded = SettingsStore(defaults: defaults, secrets: secrets)
        XCTAssertEqual(reloaded.endpoint.model, "gpt-4o-mini")
        XCTAssertEqual(reloaded.endpoint.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(reloaded.apiKey, "sk-test-123")
        XCTAssertTrue(reloaded.canDispatchRemotely)

        defaults.removePersistentDomain(forName: suite)
    }

    func testDefaultsToEmptyEndpoint() {
        let defaults = UserDefaults(suiteName: UUID().uuidString) ?? .standard
        let store = SettingsStore(defaults: defaults, secrets: InMemorySecretStore())
        XCTAssertEqual(store.endpoint, .empty)
        XCTAssertFalse(store.canDispatchRemotely)
    }
}
