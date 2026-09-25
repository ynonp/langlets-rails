import Foundation

struct NativeSession: Codable {
    var accessToken: String
    var refreshToken: String
    var clientId: String
    var expiresIn: Int
    var userId: Int
}
struct NativePage<T: Codable>: Codable {
    var items: [T]
    var nextPage: Int?
}
struct NativeLanguage: Codable, Identifiable {
    let id: Int
    let code: String
    let name: String
    let nativeName: String?
    let rtl: Bool
}
struct NativeAccount: Codable {
    let id: Int
    let email: String
    let nativeLanguage: String
    let theme: String
    let notificationDelivery: [String]
    let pro: Bool
    let beta: Bool
    let credits: Int
    let streak: Int
    let totalXp: Int
}
struct NativeBootstrap: Codable {
    let schemaVersion: Int
    let user: NativeAccount
    let languages: [NativeLanguage]
    let reviewLanguages: [String]
}
struct NativeCourse: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String
    let name: String
    let language: String?
    let thumbnailUrl: String?
    let provider: String
    let videoId: String?
    let mediaUrl: String?
    let lessonCount: Int
    var completedLessonIds: [Int]
    let enrolled: Bool
    let shared: Bool
    let owned: Bool
    let translationReady: Bool
    let lessons: [NativeLessonSummary]
}
struct NativeLessonSummary: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let slug: String?
    let courseSlug: String?
    let language: String?
    let start: Double?
    let end: Double?
}
struct NativeLesson: Codable, Identifiable {
    let id: Int
    let name: String?
    let courseSlug: String?
    let language: String?
    let start: Double?
    let end: Double?
    let schemaVersion: Int
    let downloadedAt: String
    let offlineUntil: String
    let activities: [NativeActivity]
    let phrases: [NativePhrase]
    let completedActivityIds: [Int]
    var availableOffline: Bool { (ISO8601DateFormatter().date(from: offlineUntil) ?? .distantPast) > Date() }
}
struct NativeActivity: Codable, Identifiable {
    let id: Int
    let kind: String
    let title: String?
    let phraseIds: [Int]
    let tokenIds: [Int]
}
struct NativePhrase: Codable, Identifiable {
    let id: Int
    let text: String
    let translation: String
    let language: String
    let rtl: Bool
    let start: Double?
    let provider: String?
    let videoId: String?
    let audio: NativeAudio?
    let tokens: [NativeToken]
}
struct NativeToken: Codable, Identifiable {
    let id: Int
    let text: String
    let translation: String
    let startIndex: Int?
    let endIndex: Int?
    let start: Double?
    let end: Double?
    let questions: [String]
    let similarSounds: [String]
    let audio: NativeAudio?
}
struct NativeAudio: Codable, Hashable {
    let id: Int
    let url: String
    let byteSize: Int
    let checksum: String
}
struct NativeVocabulary: Codable, Identifiable {
    let id: Int
    let tokenId: Int
    let language: String
    var translation: String
    var practicing: Bool
    let custom: Bool
    let phrase: NativePhrase
    let token: NativeToken
}
struct NativePlaylist: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let owned: Bool
    var courses: NativePage<NativeCourse>?
}
struct NativeNotice: Codable, Identifiable {
    let id: Int
    let title: String
    let body: String
    let url: String?
    let read: Bool
    let createdAt: String
}
struct NativeImport: Codable, Identifiable {
    let id: Int
    let title: String?
    let status: String
    let progressPercent: Int?
    let course: ImportedCourse?
    struct ImportedCourse: Codable { let slug: String; let name: String? }
}
struct NativeImports: Codable { let importRequests: [NativeImport] }
struct NativeChallenge: Codable {
    let enrolled: Bool
    let languageIds: [Int]
    let reminderTime: String
    let reminderTimezone: String
    let firstChallengeOn: String?
    let practiceStarted: Bool
    let quest: Quest?
    struct Quest: Codable { let day: Int; let kind: String; let completed: Bool }
}
struct NativeDownload: Codable { let course: NativeCourse; let phrases: [NativePhrase]; let lessons: [NativeLesson] }

// A bounded JSON value type for immutable outbox payloads, never Any in persistence.
enum NativeValue: Codable, Equatable {
    case string(String), integer(Int), bool(Bool)
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? value.decode(Int.self) { self = .integer(number) }
        else { self = .string(try value.decode(String.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let v): try value.encode(v)
        case .integer(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        }
    }
}
struct NativeMutation: Codable, Identifiable {
    let id: UUID
    let payload: [String: NativeValue]
    var failure: String?
}
struct NativeSnapshot: Codable {
    var version = 1
    var responses: [String: Data] = [:]
    var outbox: [NativeMutation] = []
    var lessonPositions: [Int: Int] = [:]
    var completedLessons: Set<Int> = []
    var completedActivities: Set<Int> = []
    var downloads: [String: NativeDownload] = [:]
}
extension JSONDecoder {
    static var native: JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }
}
extension JSONEncoder {
    static var native: JSONEncoder { let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e }
}

extension NativePhrase {
    func cloze(_ token: NativeToken) -> String {
        guard let first = token.startIndex, let last = token.endIndex else { return text }
        let scalars = Array(text.unicodeScalars)
        guard first >= 0, last >= first, last < scalars.count else { return text }
        let prefix = String(String.UnicodeScalarView(scalars.prefix(first)))
        let suffix = String(String.UnicodeScalarView(scalars.dropFirst(last + 1)))
        return prefix + " _____ " + suffix
    }
}
