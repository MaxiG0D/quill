import Foundation
import Security

/// Keeps the token in the keychain, readable after the device's first unlock so mail can refresh in the background.
struct KeychainTokenStore: TokenStore {
    var service = "com.maxig0d.quill.google"
    var account = "default"

    func load() async throws -> OAuthToken? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError(status: status)
        }
        return try JSONDecoder().decode(OAuthToken.self, from: data)
    }

    func save(_ token: OAuthToken) async throws {
        let data = try JSONEncoder().encode(token)
        SecItemDelete(item as CFDictionary)
        var attributes = item
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    func clear() async throws {
        let status = SecItemDelete(item as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private var item: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
