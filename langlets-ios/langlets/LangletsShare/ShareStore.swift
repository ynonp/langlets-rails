import Foundation
import Security

enum ShareStore {
    static let appGroup = "group.com.ynonp.langlets"
    private static let keychainGroup = "U39ZVCW9HE.com.ynonp.langlets.shared"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static var accessToken: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ynonp.langlets",
            kSecAttrAccount as String: "share-import-access-token",
            kSecAttrAccessGroup as String: keychainGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var languages: [Language] {
        guard let data = defaults?.data(forKey: "supportedLanguages"),
              let decoded = try? JSONDecoder().decode([Language].self, from: data),
              !decoded.isEmpty else {
            return [
                Language(isoName: "ar", englishName: "Arabic"),
                Language(isoName: "en", englishName: "English"),
                Language(isoName: "fr", englishName: "French"),
                Language(isoName: "de", englishName: "German"),
                Language(isoName: "he", englishName: "Hebrew"),
                Language(isoName: "es", englishName: "Spanish")
            ]
        }
        return decoded
    }

    struct Language: Codable, Equatable {
        let isoName: String
        let englishName: String

        enum CodingKeys: String, CodingKey {
            case isoName = "iso_name"
            case englishName = "english_name"
        }
    }
}
