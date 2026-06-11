import Foundation
import Security

/// Stores small secrets (the AI API key). Abstracted so the live app uses the
/// Keychain while tests use an in-memory implementation (the CI runner has no
/// usable login keychain).
protocol SecretStoring {
    func string(for key: String) -> String?
    func set(_ value: String?, for key: String)
}

extension SecretStoring {
    /// Convenience for the single secret this app stores today.
    var apiKey: String {
        get { string(for: SecretKey.apiKey) ?? "" }
        nonmutating set { set(newValue.isEmpty ? nil : newValue, for: SecretKey.apiKey) }
    }
}

enum SecretKey {
    static let apiKey = "ai.apiKey"
}

/// Keychain-backed secret store (generic password items, scoped to the app's
/// service identifier).
struct KeychainSecretStore: SecretStoring {
    private let service = "company.gh.notch"

    func string(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String?, for key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(base as CFDictionary)

        guard let value, let data = value.data(using: .utf8) else { return }
        var insert = base
        insert[kSecValueData as String] = data
        SecItemAdd(insert as CFDictionary, nil)
    }
}

/// In-memory secret store for tests and previews.
final class InMemorySecretStore: SecretStoring {
    private var storage: [String: String] = [:]

    func string(for key: String) -> String? { storage[key] }

    func set(_ value: String?, for key: String) {
        if let value { storage[key] = value } else { storage.removeValue(forKey: key) }
    }
}
