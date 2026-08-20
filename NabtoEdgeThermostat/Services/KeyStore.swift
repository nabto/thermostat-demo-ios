import Foundation
import Security

/// Keychain-backed storage for the client's Nabto Edge private key.
///
/// The key is this client's identity: devices grant access based on its fingerprint, so losing it
/// means losing ownership of every device paired with it.
enum KeyStore {
    private static let service = "com.nabto.edge.thermostat"
    private static let account = "privateKey"

    enum KeyStoreError: Error {
        case keychainFailure(OSStatus)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func privateKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ privateKey: String) throws {
        clear()

        var query = baseQuery
        query[kSecValueData as String] = Data(privateKey.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyStoreError.keychainFailure(status)
        }
    }

    static func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
