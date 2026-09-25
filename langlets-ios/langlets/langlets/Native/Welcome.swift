import SwiftUI

struct NativeOnboarding: Decodable {
    let beta: Bool
    let languages: [NativeLanguage]
    let examples: [Example]
    struct Example: Decodable { let title: String; let url: String; let thumbnailUrl: String? }
}
struct NativeWelcome: View {
    @EnvironmentObject var store: NativeStore
    @State private var step = 0
    @State private var config: NativeOnboarding?
    @State private var selected: Set<Int> = []
    @State private var reminder = Date()
    @State private var delivery = true
    var body: some View {
        NavigationStack {
            if step == 3 { NativeSignIn() }
            else {
                Form {
                    Section {
                        Image(systemName: step == 0 ? "play.bubble.fill" : step == 1 ? "globe" : "sparkles.tv").font(.system(size: 56)).foregroundStyle(.mint).accessibilityHidden(true)
                        Text(step == 0 ? "A little practice. Videos you love." : step == 1 ? "Make it a daily habit" : "Choose your first video").font(.largeTitle.bold())
                    }
                    if step == 0 {
                        Text("Watch, understand, and remember new words in context. Download your lessons to keep practising wherever you are.")
                        if config?.beta == true { Section { Text("Free Pro during beta").font(.headline); Text("Create unlimited langlets while beta lasts.") } }
                        Button("Get started") { step = 1 }
                        Button("I already have an account") { step = 3 }
                    } else if step == 1 {
                        Section("Languages to learn") {
                            ForEach(config?.languages ?? []) { language in
                                Toggle(language.name, isOn: Binding(get: { selected.contains(language.id) }, set: { if $0 { selected.insert(language.id) } else { selected.remove(language.id) } }))
                            }
                        }
                        DatePicker("Reminder time", selection: $reminder, displayedComponents: .hourAndMinute)
                        Toggle("Daily push reminders", isOn: $delivery)
                        Button("Continue") {
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: reminder)
                            store.onboardingIntent = NativeOnboardingIntent(languageIds: Array(selected), reminderTime: String(format: "%02d:%02d", parts.hour ?? 9, parts.minute ?? 0), timezone: TimeZone.current.identifier, push: delivery)
                            step = 2
                        }.disabled(selected.isEmpty)
                        Button("Set up later") { step = 2 }
                    } else {
                        Text("Create a free account to turn a video into a langlet. You can review the video before starting the import.")
                        TextField("YouTube or TikTok link", text: $store.importDraft).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        ForEach(config?.examples ?? [], id: \.url) { example in Button(example.title) { store.importDraft = example.url } }
                        Button("Continue to account") { step = 3 }
                    }
                }.navigationTitle("langlets.").toolbar { if step > 0 { ToolbarItem(placement: .cancellationAction) { Button("Back") { step -= 1 } } } }
                    .task {
                        guard config == nil else { return }
                        do { let data = try await store.request(NativeStore.api + "onboarding", authenticated: false); config = try JSONDecoder.native.decode(NativeOnboarding.self, from: data) }
                        catch { /* Welcome and sign-in remain usable while offline. */ }
                    }
            }
        }
    }
}
struct NativeOnboardingIntent: Codable {
    let languageIds: [Int]
    let reminderTime: String
    let timezone: String
    let push: Bool
}
