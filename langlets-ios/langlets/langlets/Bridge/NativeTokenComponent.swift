import HotwireNative
import Foundation

/// Stores the session-authorized import token and supported-language catalog
/// where the share extension can read them.
@MainActor
final class NativeTokenComponent: BridgeComponent {
    nonisolated override class var name: String { "native-token" }

    override func onReceive(message: Message) {
        guard message.event == "store", let data: TokenData = message.data() else { return }

        NativeShareStore.storeToken(data.accessToken)
        let defaults = UserDefaults(suiteName: NativeShareStore.appGroup)
        defaults?.set(data.expiresAt, forKey: "shareTokenExpiresAt")
        if let encoded = try? JSONEncoder().encode(data.languages) {
            defaults?.set(encoded, forKey: "supportedLanguages")
        }
    }
}

private extension NativeTokenComponent {
    struct TokenData: Decodable {
        let accessToken: String
        let expiresAt: String
        let languages: [Language]

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresAt = "expires_at"
            case languages
        }
    }

    struct Language: Codable {
        let isoName: String
        let englishName: String

        enum CodingKeys: String, CodingKey {
            case isoName = "iso_name"
            case englishName = "english_name"
        }
    }
}
