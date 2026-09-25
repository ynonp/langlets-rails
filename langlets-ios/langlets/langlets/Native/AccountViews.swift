import SwiftUI
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import Security

@MainActor
final class NativeBrowserSignIn: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    private var webSession: ASWebAuthenticationSession?
    func start(provider: String, store: NativeStore) {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return }
        let verifier = Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        var components = URLComponents(url: rootURL.appendingPathComponent("users/auth/native_handoff_start"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "provider", value: provider), URLQueryItem(name: "challenge", value: challenge)]
        webSession = ASWebAuthenticationSession(url: components.url!, callbackURLScheme: "langlets") { url, error in
            Task { @MainActor in
                guard let url, url.host == "auth-success", let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "handoff" })?.value else {
                    if error != nil { store.error = "Sign-in was cancelled or could not finish." }; return
                }
                do { try await store.signIn(["handoff": token, "verifier": verifier]) }
                catch { store.error = error.localizedDescription }
            }
        }
        webSession?.presentationContextProvider = self
        webSession?.start()
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }
}

struct NativeSignIn: View {
    @EnvironmentObject var store: NativeStore
    @StateObject private var browser = NativeBrowserSignIn()
    @State private var email = ""
    @State private var password = ""
    @State private var register = false
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill").font(.system(size: 48)).foregroundStyle(.mint).accessibilityHidden(true)
                    Text("Learn from videos you love").font(.largeTitle.bold())
                    Text("Build your vocabulary, practise a little every day, and take your lessons offline.")
                }
                Section(register ? "Create account" : "Welcome back") {
                    TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password).textContentType(register ? .newPassword : .password)
                    Button(register ? "Create account" : "Sign in") { perform {
                        if register {
                            _ = try await store.request(NativeStore.api + "registration", method: "POST", body: ["email": email, "password": password, "password_confirmation": password, "native_language": Locale.current.language.languageCode?.identifier ?? "en"], authenticated: false)
                            message = "Check your email and confirm your account, then sign in."; register = false
                        } else { try await store.signIn(["email": email, "password": password]) }
                    } }.disabled(busy || email.isEmpty || password.isEmpty)
                    if busy { ProgressView() }
                    if let message { Text(message).foregroundStyle(.secondary) }
                    Button(register ? "Already have an account? Sign in" : "New here? Create account") { register.toggle() }
                }
                Section {
                    Button("Continue with Google") { perform {
                        guard let controller = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
                        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: controller)
                        guard let code = result.serverAuthCode else { throw NativeFailure(status: 401, message: "Google did not return a sign-in code") }
                        try await store.signIn(["google_code": code])
                    } }
                    Button("Continue with Apple") { browser.start(provider: "apple", store: store) }
                    Button("Continue with GitHub") { browser.start(provider: "github", store: store) }
                    Button("Forgot password?") { emailAction("password") }
                    Button("Resend confirmation email") { emailAction("confirmation") }
                }
                Section {
                    Link("Privacy", destination: rootURL.appendingPathComponent("home/privacy"))
                    Link("Terms", destination: rootURL.appendingPathComponent("home/terms"))
                }
            }.navigationTitle("langlets.")
        }
    }
    func emailAction(_ path: String) { perform {
        guard !email.isEmpty else { message = "Enter your email first."; return }
        _ = try await store.request(NativeStore.api + path, method: "POST", body: ["email": email], authenticated: false)
        message = "If that address has an account, an email is on its way."
    } }
    func perform(_ action: @escaping () async throws -> Void) {
        busy = true
        Task { defer { busy = false }; do { try await action() } catch { message = error.localizedDescription } }
    }
}

struct NativeProfile: View {
    @EnvironmentObject var store: NativeStore
    @State private var language = "en"
    @State private var theme = "dark"
    @State private var emailDelivery = false
    @State private var pushDelivery = true
    @State private var confirmSignOut = false
    var body: some View {
        Form {
            Section("Account") {
                Text(store.account?.email ?? "")
                Text(store.account?.pro == true ? "Langlets Pro · Active" : "Free account")
                if store.account?.beta == true { Text("Unlimited imports while Langlets is in beta.") }
                Link("Contact the team", destination: rootURL.appendingPathComponent("support"))
                Link("Manage Apple subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
            Section("Preferences") {
                Picker("Native language", selection: $language) { Text("English").tag("en"); Text("Español").tag("es"); Text("עברית").tag("he") }
                Picker("Appearance", selection: $theme) { Text("Dark").tag("dark"); Text("Light").tag("light") }
                Toggle("Email reminders", isOn: $emailDelivery)
                Toggle("Push reminders", isOn: $pushDelivery)
                Button("Save preferences") { Task {
                    do {
                        _ = try await store.request(NativeStore.api + "account", method: "PATCH", body: ["native_language": language, "theme": theme, "notification_delivery": (emailDelivery ? ["email"] : []) + (pushDelivery ? ["push"] : [])])
                        await store.refresh()
                    } catch { store.error = error.localizedDescription }
                } }.disabled(!store.online)
                Button("Enable notifications on this device") {
                    PushNotifications.shared.isEnabled = true
                    PushNotifications.shared.register(ask: true) { token in
                        Task { do { _ = try await store.request(NativeStore.api + "device", method: "POST", body: ["token": token, "environment": PushNotifications.shared.environment, "app_version": PushNotifications.shared.appVersion]) } catch { store.error = error.localizedDescription } }
                    }
                }
                Button("Open notification settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                Button("Disable notifications on this device") { Task {
                    do {
                        if let token = PushNotifications.shared.deviceToken { _ = try await store.request(NativeStore.api + "device", method: "DELETE", body: ["token": token]) }
                        PushNotifications.shared.isEnabled = false
                    } catch { store.error = error.localizedDescription }
                } }
            }
            Section {
                NavigationLink("Daily challenge and reminders") { NativeChallengeScreen() }
                NavigationLink("Downloads") { NativeDownloads() }
                NavigationLink("Sync status") { NativeSyncStatus() }
                Link("Privacy", destination: rootURL.appendingPathComponent("home/privacy"))
                Link("Terms", destination: rootURL.appendingPathComponent("home/terms"))
                NavigationLink("Connected apps") { NativeConnections() }
                NavigationLink("Invitations") { NativeInvitations() }
                NavigationLink("Delete account") { NativeDeleteAccount() }
                Button("Sign out", role: .destructive) { confirmSignOut = true }
            }
        }.navigationTitle("Profile")
            .onAppear { language = store.account?.nativeLanguage ?? "en"; theme = store.account?.theme ?? "dark"; emailDelivery = store.account?.notificationDelivery.contains("email") ?? false; pushDelivery = store.account?.notificationDelivery.contains("push") ?? true }
            .confirmationDialog("Sign out and remove downloads?", isPresented: $confirmSignOut) {
                Button("Sign out", role: .destructive) { Task { do { try await store.signOut() } catch { store.error = error.localizedDescription } } }
            } message: { Text("Unsynced changes will be removed from this device. Sync them first to keep your progress.") }
    }
}

struct NativeSyncStatus: View {
    @EnvironmentObject var store: NativeStore
    var body: some View {
        List {
            if store.state.outbox.isEmpty { Label("All changes synced", systemImage: "checkmark.icloud") }
            ForEach(store.state.outbox) { item in
                VStack(alignment: .leading) { Text(item.failure == nil ? "Waiting to sync" : "Needs attention").font(.headline); Text(item.failure ?? "Your change is saved on this device.").font(.caption)
                    if item.failure != nil { Button("Discard failed change", role: .destructive) { Task { do { try await store.discardMutation(item.id) } catch { store.error = error.localizedDescription } } } }
                }
            }
            Button("Sync now") { Task { await store.refresh() } }.disabled(!store.online || store.syncing)
        }.navigationTitle("Sync status")
    }
}

struct NativeChallengeScreen: View {
    @EnvironmentObject var store: NativeStore
    @State private var selected: Set<Int> = []
    @State private var reminder = Date()
    var challenge: NativeChallenge? { store.cached("challenge", as: NativeChallenge.self) }
    var body: some View {
        Form {
            if let quest = challenge?.quest {
                Section("Today's challenge") {
                    Text(quest.kind.capitalized).font(.title2)
                    Button(quest.completed ? "Completed" : "I did it") { Task {
                        do { try await store.enqueue(["kind": .string("challenge_complete"), "day": .integer(quest.day)]); await store.load("challenge", as: NativeChallenge.self) }
                        catch { store.error = error.localizedDescription }
                    } }.disabled(quest.completed)
                }
            } else if let date = challenge?.firstChallengeOn { Text("Your challenge begins \(date)") }
            Section("Languages to learn") {
                ForEach(store.languages) { language in
                    Toggle(language.name, isOn: Binding(get: { selected.contains(language.id) }, set: { if $0 { selected.insert(language.id) } else { selected.remove(language.id) } }))
                }
            }
            Section("Reminder") {
                DatePicker("Daily reminder", selection: $reminder, displayedComponents: .hourAndMinute)
                Text(TimeZone.current.identifier).font(.caption)
                Button("Save") { Task {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: reminder)
                    do {
                        _ = try await store.request(NativeStore.api + "challenge", method: "PATCH", body: ["language_ids": Array(selected), "reminder_time": String(format: "%02d:%02d", parts.hour ?? 9, parts.minute ?? 0), "reminder_timezone": TimeZone.current.identifier])
                        await store.load("challenge", as: NativeChallenge.self)
                    } catch { store.error = error.localizedDescription }
                } }.disabled(selected.isEmpty || !store.online)
            }
        }.navigationTitle("Daily challenge").task {
            await store.load("challenge", as: NativeChallenge.self)
            selected = Set(challenge?.languageIds ?? [])
            if let time = challenge?.reminderTime {
                let parts = time.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2 { reminder = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) ?? Date() }
            }
        }
    }
}
