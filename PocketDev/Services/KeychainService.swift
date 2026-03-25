import Foundation
import Security

// MARK: - KeychainService
// Stores the GitHub personal access token in the system keychain.
// All operations are synchronous and silent on failure.

enum KeychainService {

    private static let service = "com.pocketdev.app"
    private static let account = "github.token"

    static func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        SecItemDelete(baseQuery as CFDictionary)
        var q = baseQuery
        q[kSecValueData as String] = data
        SecItemAdd(q as CFDictionary, nil)
    }

    static func loadToken() -> String? {
        var q = baseQuery
        q[kSecReturnData as String]  = true
        q[kSecMatchLimit as String]  = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    // MARK: - Private

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
