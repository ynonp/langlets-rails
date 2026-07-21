import Foundation
import Security

enum NativeShareStore {
    static let appGroup = "group.com.ynonp.langlets"
    static let keychainGroup = "U39ZVCW9HE.com.ynonp.langlets.shared"
    static let tokenAccount = "share-import-access-token"

    static func storeToken(_ token: String) {
        clearToken()
        let data = Data(token.utf8)
        SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ynonp.langlets",
            kSecAttrAccount as String: tokenAccount,
            kSecAttrAccessGroup as String: keychainGroup,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ] as CFDictionary, nil)
    }

    static func clearToken() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ynonp.langlets",
            kSecAttrAccount as String: tokenAccount,
            kSecAttrAccessGroup as String: keychainGroup
        ] as CFDictionary)
    }
}
