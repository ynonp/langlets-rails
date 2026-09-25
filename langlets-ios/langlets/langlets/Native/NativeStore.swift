import Foundation
import SwiftUI
import Network

@MainActor
final class NativeStore: ObservableObject {
    static let shared = NativeStore()
    static let api = "/api/v1/native/"
    @Published private(set) var session = NativeKeychain.read()
    @Published private(set) var state = NativeSnapshot()
    @Published var error: String?
    @Published var online = true
    @Published var syncing = false
    @Published var ready = false
    @Published var needsSignIn = false
    @Published var selectedTab = 0
    @Published var courseRoute: String?
    @Published var onboardingIntent: NativeOnboardingIntent? = UserDefaults.standard.data(forKey: "native.onboarding").flatMap { try? JSONDecoder().decode(NativeOnboardingIntent.self, from: $0) } {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(onboardingIntent), forKey: "native.onboarding") }
    }
    @Published var importDraft = UserDefaults.standard.string(forKey: "native.importDraft") ?? "" {
        didSet { UserDefaults.standard.set(importDraft, forKey: "native.importDraft") }
    }
    @Published var challengeRoute = false
    @Published var invitationRoute = false
    @Published var resetPasswordToken: String?
    @Published var confirmationToken: String?
    @Published var reviewRoute: String?
    @Published var downloadProgress: [String: String] = [:]
    let disk = NativeDisk()
    private let monitor = NWPathMonitor()
    private var generation = UUID()
    private var refreshTask: Task<NativeSession, Error>?
    var account: NativeAccount? { cached("bootstrap", as: NativeBootstrap.self)?.user }
    var languages: [NativeLanguage] { cached("bootstrap", as: NativeBootstrap.self)?.languages ?? [] }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.online = path.status == .satisfied
                if path.status == .satisfied { await self?.sync() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "langlets.connectivity"))
    }
    func start() async {
        guard !ready else { return }
        if let session {
            do { state = try await disk.read(session.userId) }
            catch { self.error = error.localizedDescription }
        }
        ready = true
        await refresh()
    }
    func cached<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = state.responses[key] else { return nil }
        return try? JSONDecoder.native.decode(type, from: data)
    }
    func fetch<T: Decodable>(_ key: String, as type: T.Type) async throws -> T {
        let owner = generation
        let data = try await request(Self.api + key)
        let value = try JSONDecoder.native.decode(type, from: data)
        guard owner == generation else { throw CancellationError() }
        state.responses[key] = data
        try await persist()
        return value
    }
    func load<T: Decodable>(_ key: String, as type: T.Type) async {
        guard online else { return }
        do { _ = try await fetch(key, as: type) }
        catch is CancellationError { }
        catch {
            if let failure = error as? NativeFailure, failure.status == 404 {
                state.responses.removeValue(forKey: key)
                if key.hasPrefix("courses/") { state.downloads.removeValue(forKey: String(key.dropFirst("courses/".count))) }
                if key.hasPrefix("lessons/"), let id = Int(key.dropFirst("lessons/".count)) {
                    for (slug, bundle) in state.downloads where bundle.lessons.contains(where: { $0.id == id }) { state.downloads.removeValue(forKey: slug) }
                }
                try? await persist()
            }
            self.error = error.localizedDescription
        }
    }
    func refresh() async {
        guard ready, session != nil, online else { return }
        await sync()
        let previousLanguage = account?.nativeLanguage
        await load("bootstrap", as: NativeBootstrap.self)
        if let previousLanguage, previousLanguage != account?.nativeLanguage {
            let bootstrap = state.responses["bootstrap"]
            state.responses = [:]
            state.responses["bootstrap"] = bootstrap
            try? await persist()
        }
        await load("courses?enrolled=true", as: NativePage<NativeCourse>.self)
        PushNotifications.shared.register(ask: false) { token in
            Task { _ = try? await self.request(Self.api + "device", method: "POST", body: ["token": token, "environment": PushNotifications.shared.environment, "app_version": PushNotifications.shared.appVersion]) }
        }
        for slug in Array(state.downloads.keys) { await load("courses/\(slug)", as: NativeCourse.self) }
        if let locale = account?.nativeLanguage { UserDefaults(suiteName: "group.com.ynonp.langlets")?.set(locale, forKey: "interfaceLocale") }
        do {
            let data = try await request(Self.api + "extension_token", method: "POST", body: [:])
            if let token = (try JSONSerialization.jsonObject(with: data) as? [String: String])?["access_token"] {
                NativeShareStore.storeToken(token)
            }
        } catch { /* A previously issued extension credential can still be valid. */ }
    }
    func signIn(_ body: [String: Any]) async throws {
        let data = try await request(Self.api + "session", method: "POST", body: body, authenticated: false)
        let next = try JSONDecoder.native.decode(NativeSession.self, from: data)
        NativeShareStore.clearToken()
        if let previous = session, previous.userId != next.userId {
            try await disk.clear(previous.userId)
            state = NativeSnapshot(); courseRoute = nil; reviewRoute = nil; challengeRoute = false
        }
        try NativeKeychain.write(next)
        generation = UUID()
        session = next
        state = try await disk.read(next.userId)
        needsSignIn = false
        if let intent = onboardingIntent {
            _ = try await request(Self.api + "challenge", method: "PATCH", body: ["language_ids": intent.languageIds, "reminder_time": intent.reminderTime, "reminder_timezone": intent.timezone, "notification_delivery": intent.push ? ["push"] : []])
            onboardingIntent = nil
        }
        if !importDraft.isEmpty { selectedTab = 3 }
        await refresh()
    }
    func signOut() async throws {
        guard session != nil else { return }
        // Revoke before discarding credentials; a failed request remains retryable.
        _ = try await request(Self.api + "session", method: "DELETE", body: ["device_token": PushNotifications.shared.deviceToken ?? ""])
        try await clearLocalAccount()
    }
    func clearLocalAccount() async throws {
        guard let session else { return }
        generation = UUID()
        refreshTask?.cancel()
        try await disk.clear(session.userId)
        NativeKeychain.clear(); NativeShareStore.clearToken()
        self.session = nil; state = NativeSnapshot(); courseRoute = nil; reviewRoute = nil; invitationRoute = false; challengeRoute = false; importDraft = ""; onboardingIntent = nil; needsSignIn = false
    }
    func recordPosition(lesson: Int, index: Int) async throws {
        state.lessonPositions[lesson] = index
        try await persist()
    }
    func persist() async throws {
        guard let session else { return }
        try await disk.save(state, account: session.userId)
    }
    func enqueue(_ payload: [String: NativeValue]) async throws {
        let previous = state
        let owner = generation
        var payload = payload
        payload["occurred_at"] = .string(ISO8601DateFormatter().string(from: Date()))
        state.outbox.append(NativeMutation(id: UUID(), payload: payload))
        if case .integer(let id)? = payload["lesson_id"], payload["kind"] == .string("lesson_complete") { state.completedLessons.insert(id) }
        if case .integer(let id)? = payload["activity_id"], payload["kind"] == .string("activity_complete") { state.completedActivities.insert(id) }
        do { try await persist() }
        catch { if owner == generation { state = previous }; throw error }
        guard owner == generation else { throw CancellationError() }
        Task { await sync() }
    }
    func sync() async {
        guard ready, session != nil, online, !syncing else { return }
        syncing = true
        defer { syncing = false }
        let owner = generation
        while let mutation = state.outbox.first(where: { $0.failure == nil }) {
            guard generation == owner else { return }
            do {
                let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(mutation.payload))
                _ = try await request(Self.api + "mutations", method: "POST", body: ["operation_id": mutation.id.uuidString, "payload": payload])
                guard generation == owner else { return }
                if case .string(let kind)? = mutation.payload["kind"], kind.hasPrefix("word_") {
                    let keys = Set(state.responses.keys.filter { $0.hasPrefix("vocabulary?") } + ["vocabulary?page=1&filter=&language="])
                    for key in keys { _ = try await fetch(key, as: NativePage<NativeVocabulary>.self) }
                }
                state.outbox.removeAll { $0.id == mutation.id }
                try await persist()
            } catch let error as NativeFailure {
                guard generation == owner else { return }
                if [403, 404, 409, 422].contains(error.status), let index = state.outbox.firstIndex(where: { $0.id == mutation.id }) {
                    state.outbox[index].failure = error.message
                    try? await persist()
                } else { return }
            } catch { return }
        }
    }
    func request(_ path: String, method: String = "GET", body: [String: Any]? = nil, authenticated: Bool = true, retry: Bool = true) async throws -> Data {
        let owner = generation
        guard let url = URL(string: path, relativeTo: rootURL)?.absoluteURL, url.host == rootURL.host else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if authenticated {
            guard let session else { throw NativeFailure(status: 401, message: "Sign in to continue") }
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard owner == generation else { throw CancellationError() }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 && authenticated && retry {
            try await refreshCredential()
            return try await self.request(path, method: method, body: body, authenticated: true, retry: false)
        }
        guard (200..<300).contains(status) else {
            if status == 401 && authenticated { needsSignIn = true }
            let info = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw NativeFailure(status: status, message: (info?["error_description"] as? String) ?? (info?["error"] as? String) ?? "Request failed (\(status)). Please try again.")
        }
        return data
    }
    private func refreshCredential() async throws {
        if let refreshTask { _ = try await refreshTask.value; return }
        guard let previous = session else { throw NativeFailure(status: 401, message: "Sign in to continue") }
        let owner = generation
        let task = Task<NativeSession, Error> {
            let data = try await request("/oauth/token", method: "POST", body: ["grant_type": "refresh_token", "refresh_token": previous.refreshToken, "client_id": previous.clientId], authenticated: false)
            struct Refreshed: Decodable { let accessToken: String; let refreshToken: String; let expiresIn: Int }
            let refreshed = try JSONDecoder.native.decode(Refreshed.self, from: data)
            let next = NativeSession(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken, clientId: previous.clientId, expiresIn: refreshed.expiresIn, userId: previous.userId)
            guard owner == generation else { throw CancellationError() }
            try NativeKeychain.write(next)
            session = next
            return next
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            _ = try await task.value
        } catch {
            if let failure = error as? NativeFailure, [400, 401].contains(failure.status) { needsSignIn = true }
            throw error
        }
    }
    func removeDownload(_ slug: String) async throws {
        if let removed = state.downloads.removeValue(forKey: slug) {
            for lesson in removed.lessons { state.responses.removeValue(forKey: "lessons/\(lesson.id)") }
        }
        try await persist()
        var used = Set(state.downloads.values.flatMap { $0.phrases.flatMap { $0.tokens.compactMap { $0.audio?.id } } })
        for key in state.responses.keys where key.hasPrefix("vocabulary?") {
            let entries = cached(key, as: NativePage<NativeVocabulary>.self)?.items ?? []
            used.formUnion(entries.compactMap { $0.token.audio?.id })
        }
        for key in state.responses.keys where key.hasPrefix("review/") {
            let lesson = cached(key, as: NativeLesson.self)
            used.formUnion(lesson?.phrases.flatMap { $0.tokens.compactMap { $0.audio?.id } } ?? [])
        }
        if let id = session?.userId { try await disk.pruneAudio(keeping: used, account: id) }
    }
    func resetLocalProgress(_ course: NativeCourse) async throws {
        let lessonIds = Set(course.lessons.map(\.id))
        let activities = Set(state.downloads[course.slug]?.lessons.flatMap { $0.activities.map(\.id) } ?? [])
        state.completedLessons.subtract(lessonIds); state.completedActivities.subtract(activities)
        state.outbox.removeAll { operation in
            if case .integer(let id)? = operation.payload["lesson_id"], lessonIds.contains(id) { return true }
            if case .integer(let id)? = operation.payload["activity_id"], activities.contains(id) { return true }
            return false
        }
        try await persist()
    }
    func discardMutation(_ id: UUID) async throws {
        if let item = state.outbox.first(where: { $0.id == id }) {
            if case .integer(let id)? = item.payload["lesson_id"] { state.completedLessons.remove(id) }
            if case .integer(let id)? = item.payload["activity_id"] { state.completedActivities.remove(id) }
        }
        state.outbox.removeAll { $0.id == id }
        try await persist()
    }
    func download(_ slug: String) async throws {
        guard let accountId = session?.userId else { return }
        let owner = generation
        downloadProgress[slug] = "Downloading lesson text…"
        defer { downloadProgress.removeValue(forKey: slug) }
        let data = try await request(Self.api + "courses/\(slug)/download")
        let bundle = try JSONDecoder.native.decode(NativeDownload.self, from: data)
        // Commit the text first, then audio one file at a time. Interrupted downloads can resume.
        state.downloads[slug] = bundle
        try await persist()
        let assets = Set(bundle.phrases.flatMap { [$0.audio].compactMap { $0 } + $0.tokens.compactMap(\.audio) })
        for (index, audio) in Array(assets).enumerated() {
            downloadProgress[slug] = "Audio \(index + 1) of \(assets.count)"
            guard owner == generation else { throw CancellationError() }
            try await disk.downloadAudio(audio, account: accountId)
        }
    }
    func lesson(_ id: Int) -> NativeLesson? {
        let downloaded = state.downloads.values.flatMap(\.lessons).first { $0.id == id }
        let cached = cached("lessons/\(id)", as: NativeLesson.self)
        return [cached, downloaded].compactMap { $0 }.first { $0.availableOffline }
    }
    func route(_ url: URL) {
        if url.scheme == "langlets", let host = url.host, ["youtube.com", "youtu.be", "tiktok.com"].contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
            var parts = URLComponents(url: url, resolvingAgainstBaseURL: false); parts?.scheme = "https"
            importDraft = parts?.url?.absoluteString ?? ""; selectedTab = 3
        } else if [rootURL.host, "he.langlets.app", "es.langlets.app", nil].contains(url.host) {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems ?? []
            if url.path == "/users/password/edit" { resetPasswordToken = query.first { $0.name == "reset_password_token" }?.value }
            if url.path == "/users/confirmation" { confirmationToken = query.first { $0.name == "confirmation_token" }?.value }
            if url.path.hasPrefix("/channel_invitations/") { invitationRoute = true }
            let parts = url.path.split(separator: "/")
            if parts.first == "courses", parts.count >= 2 { courseRoute = String(parts[1]); selectedTab = 0 }
            if parts.first == "daily_challenge" { challengeRoute = true }
            if parts.first == "daily_practice" || parts.first == "review_lessons" {
                reviewRoute = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems?.first { ["language_code", "language"].contains($0.name) }?.value
                if reviewRoute == nil { challengeRoute = true }
            }
        }
    }
}
