import Foundation
import Observation

/// Observable, persisted settings for the AI command bar.
///
/// Endpoint config (non-secret) persists to `UserDefaults`; the API key persists
/// to the injected `SecretStoring` (Keychain in the app, in-memory in tests).
/// Call `save()` after editing to write both.
@Observable
final class SettingsStore {

    /// Shared instance used by the panel and the Settings window so both see the
    /// same configuration.
    static let shared = SettingsStore()

    var endpoint: AIEndpoint
    var apiKey: String

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let secrets: SecretStoring

    private static let endpointKey = "ai.endpoint"

    init(defaults: UserDefaults = .standard, secrets: SecretStoring = KeychainSecretStore()) {
        self.defaults = defaults
        self.secrets = secrets

        if let data = defaults.data(forKey: SettingsStore.endpointKey),
           let decoded = try? JSONDecoder().decode(AIEndpoint.self, from: data) {
            self.endpoint = decoded
        } else {
            self.endpoint = .empty
        }
        self.apiKey = secrets.apiKey
    }

    /// Persist the current endpoint config and API key.
    func save() {
        if let data = try? JSONEncoder().encode(endpoint) {
            defaults.set(data, forKey: SettingsStore.endpointKey)
        }
        secrets.apiKey = apiKey
    }

    /// Whether the command bar can dispatch remote queries.
    var canDispatchRemotely: Bool {
        endpoint.isConfigured
    }
}
