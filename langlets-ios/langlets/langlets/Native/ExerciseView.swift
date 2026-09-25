import SwiftUI

struct NativeExercise: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.scenePhase) private var scenePhase
    let activity: NativeActivity
    let lesson: NativeLesson
    let completed: () -> Void
    @State private var card = 0
    @State private var choices: [String] = []
    @State private var answer = ""
    @State private var correct = false
    @State private var feedback: String?
    @State private var hint = false
    @State private var ordered: [Int] = []
    @State private var picked: [Int] = []
    @State private var matchingLeft: Int?
    @State private var matched: Set<Int> = []
    @StateObject private var speech = NativeSpeech()
    @StateObject private var playback = NativePlayback()

    var phrases: [NativePhrase] {
        let chosen = activity.phraseIds.compactMap { id in lesson.phrases.first { $0.id == id } }
        return chosen.isEmpty ? lesson.phrases.filter { $0.tokens.contains { activity.tokenIds.contains($0.id) } } : chosen
    }
    var tokens: [NativeToken] {
        let all = lesson.phrases.flatMap(\.tokens)
        return activity.tokenIds.compactMap { id in all.first { $0.id == id } }
    }
    var phrase: NativePhrase? {
        if tokenBased, let token { return lesson.phrases.first { $0.tokens.contains { $0.id == token.id } } }
        return phrases.indices.contains(card) ? phrases[card] : nil
    }
    var token: NativeToken? { tokens.indices.contains(card) ? tokens[card] : nil }
    var tokenBased: Bool { ["FlashcardActivity", "WriteMissingWordActivity", "LanguageAlignmentActivity", "TokensChainActivity", "MatchTokensActivity", "FindAnswerActivity"].contains(activity.kind) }
    var count: Int { tokenBased ? tokens.count : phrases.count }
    var isRead: Bool { activity.kind == "ReadTranslatedActivity" }
    var isWatch: Bool { activity.kind == "WatchVideoActivity" }
    var isCloze: Bool { ["FlashcardActivity", "WriteMissingWordActivity"].contains(activity.kind) }
    var isMatching: Bool { ["MatchTokensActivity", "LanguageAlignmentActivity"].contains(activity.kind) }
    var units: [String] {
        guard let phrase else { return [] }
        // Use explicit token spans for languages without whitespace; keep punctuation/gaps as units.
        let scalars = Array(phrase.text.unicodeScalars)
        let sorted = phrase.tokens.sorted { ($0.startIndex ?? 0) < ($1.startIndex ?? 0) }
        guard !sorted.isEmpty else { return phrase.text.split(separator: " ").map(String.init) }
        var result: [String] = []; var cursor = 0
        for token in sorted {
            guard let first = token.startIndex, let last = token.endIndex, first >= cursor, last >= first, last < scalars.count else { continue }
            if first > cursor { let gap = String(String.UnicodeScalarView(scalars[cursor..<first])).trimmingCharacters(in: .whitespaces); if !gap.isEmpty { result.append(gap) } }
            result.append(String(String.UnicodeScalarView(scalars[first...last]))); cursor = last + 1
        }
        if cursor < scalars.count { let tail = String(String.UnicodeScalarView(scalars[cursor...])).trimmingCharacters(in: .whitespaces); if !tail.isEmpty { result.append(tail) } }
        return result
    }
    var body: some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey(title)).font(.title2.bold()).multilineTextAlignment(.center).padding(.horizontal)
            if !isRead && !isWatch && !isMatching { Text("\(min(card + 1, max(count, 1))) / \(max(count, 1))").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            if isWatch {
                NativeTranscript(phrases: phrases, end: lesson.end)
            } else if activity.kind == "ListenActivity" {
                NativeListeningExercise(phrases: phrases, tokenIds: activity.tokenIds, end: lesson.end, completed: completed)
            } else if isMatching {
                matching
            } else if activity.kind == "SortPhrasesActivity" {
                sorting
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        if isRead {
                            ForEach(phrases) { Text($0.translation).font(.title3).frame(maxWidth: .infinity, alignment: .leading) }
                        } else if let phrase {
                            if isCloze {
                                if store.online, let provider = phrase.provider, let videoId = phrase.videoId {
                                    NativeProviderPlayer(provider: provider, videoId: videoId, start: phrase.start ?? 0, end: phrase.tokens.compactMap(\.end).max(), playback: playback).frame(height: 200)
                                }
                                Text(token.map { correct ? phrase.text : phrase.cloze($0) } ?? phrase.text).font(.title2).environment(\.layoutDirection, phrase.rtl ? .rightToLeft : .leftToRight)
                                Text(token?.translation ?? "").foregroundStyle(.secondary)
                                if activity.kind == "WriteMissingWordActivity" && !hint && !correct {
                                    TextField("Missing word", text: $answer).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled().onSubmit { check(answer, expected: token?.text ?? "") }
                                    Button("Check") { check(answer, expected: token?.text ?? "") }.buttonStyle(.borderedProminent)
                                    Button("Hint") { hint = true }
                                } else { options(expected: token?.text ?? "") }
                            } else if activity.kind == "WordOrderActivity" {
                                Text(phrase.translation).font(.title3)
                                Text(picked.map { units[$0] }.joined(separator: " ")).font(.title2).frame(minHeight: 80).frame(maxWidth: .infinity).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) {
                                    ForEach(ordered, id: \.self) { index in Button(units[index]) { picked.append(index) }.buttonStyle(.bordered).disabled(picked.contains(index) || correct) }
                                }.environment(\.layoutDirection, phrase.rtl ? .rightToLeft : .leftToRight)
                                Button("Undo") { if !picked.isEmpty { picked.removeLast() } }.disabled(correct)
                                Button("Check") { result(picked.map { units[$0] } == units) }.buttonStyle(.borderedProminent).disabled(picked.count != units.count || correct)
                            } else if activity.kind == "SpeakActivity" {
                                Text(phrase.text).font(.title2)
                                Text(phrase.translation).foregroundStyle(.secondary)
                                Button("Listen") { NativePronunciation.shared.speak(phrase.text, language: phrase.language) }
                                Button(speech.listening ? "Stop recording" : "Practise speaking") { if speech.listening { speech.stop() } else { Task { await speech.start(language: phrase.language) } } }.buttonStyle(.borderedProminent)
                                Text(speech.text).font(.title3)
                                if let error = speech.error { Text(error).font(.caption) }
                                Button("Check pronunciation") { check(speech.text, expected: phrase.text) }.disabled(speech.text.isEmpty)
                                Button("I practised aloud") { result(true) }
                            } else if activity.kind == "FindAnswerActivity" {
                                Text(token?.questions.first ?? "Find the matching word").font(.title2)
                                Text(phrase.text).font(.title3)
                                NativeTokenChips(tokens: phrase.tokens) { picked in result(picked.id == token?.id) }
                            } else if activity.kind == "TokensChainActivity" {
                                Text(token?.text ?? "").font(.largeTitle)
                                options(expected: token?.translation ?? "")
                            } else if activity.kind == "ListenActivity" || activity.kind == "AudioToTranslation" {
                                Button { NativePronunciation.shared.speak(phrase.text, language: phrase.language) } label: { Label("Listen to the sentence", systemImage: "speaker.wave.2.fill").font(.title3) }.buttonStyle(.borderedProminent)
                                Text("Choose its meaning").foregroundStyle(.secondary)
                                options(expected: phrase.translation)
                            } else if activity.kind == "MatchPhrasesActivity" {
                                Text(phrase.text).font(.title2)
                                Button("Listen") { NativePronunciation.shared.speak(phrase.text, language: phrase.language) }
                                options(expected: phrase.translation)
                            } else {
                                ContentUnavailableView("Update needed", systemImage: "arrow.down.app", description: Text("This activity needs a newer version of Langlets. You can skip it and continue."))
                            }
                        } else { Text("There are no questions in this activity.") }
                        if let feedback { Text(LocalizedStringKey(feedback)).foregroundStyle(correct ? .green : .orange).accessibilityAddTraits(.updatesFrequently) }
                    }.padding()
                }
            }
            if correct || isRead || isWatch || count == 0 || (isMatching && matched.count == tokens.count) {
                VStack(spacing: 8) {
                    if correct, let phrase { Text(phrase.translation).font(.subheadline).lineLimit(4) }
                    Button(isRead || isWatch || isMatching || activity.kind == "SortPhrasesActivity" || card + 1 >= count ? "Next activity" : "Next") { next() }
                        .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                }.padding().background(.thinMaterial)
            }
        }.onAppear { prepare() }.onChange(of: card) { _, _ in prepare() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stop(); playback.pause() } }
            .onDisappear { speech.stop(); playback.pause(); NativePronunciation.shared.stop() }
    }
    var title: String {
        switch activity.kind {
        case "ReadTranslatedActivity": return "Before you watch"
        case "WatchVideoActivity": return "Watch and understand"
        case "FlashcardActivity", "WriteMissingWordActivity": return "Find the missing word"
        case "WordOrderActivity": return "Build the sentence"
        case "SortPhrasesActivity": return "Put the sentences in order"
        case "SpeakActivity": return "Say it aloud"
        case "ListenActivity", "AudioToTranslation": return "Listen and understand"
        case "FindAnswerActivity": return "Find the answer"
        default: return "Match the meaning"
        }
    }
    @ViewBuilder func options(expected: String) -> some View {
        ForEach(Array(choices.enumerated()), id: \.offset) { _, choice in
            Button(choice) { check(choice, expected: expected) }.buttonStyle(.bordered).controlSize(.large).disabled(correct).frame(maxWidth: .infinity)
        }
    }
    var matching: some View {
        ScrollView {
            let pageTokens = Array(tokens.dropFirst(card * 5).prefix(5))
            let right = ordered.compactMap { pageTokens.indices.contains($0) ? pageTokens[$0] : nil }
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 12) {
                    ForEach(pageTokens) { token in Button(token.text) {
                        matchingLeft = token.id
                        Task { await NativePronunciation.shared.play(token, language: phrase?.language ?? lesson.language ?? "en", store: store) }
                    }.buttonStyle(.bordered).controlSize(.large).tint(matchingLeft == token.id ? .mint : .secondary).disabled(matched.contains(token.id)).frame(minHeight: 60) }
                }
                VStack(spacing: 12) {
                    ForEach(right) { token in Button(token.translation) {
                        if matchingLeft == token.id {
                            matched.insert(token.id); matchingLeft = nil
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            if pageTokens.allSatisfy({ matched.contains($0.id) }), matched.count < tokens.count { card += 1 }
                        } else { UINotificationFeedbackGenerator().notificationOccurred(.error) }
                    }.buttonStyle(.bordered).controlSize(.large).disabled(matched.contains(token.id)).frame(minHeight: 60) }
                }
            }.padding()
            Text("\(matched.count) / \(tokens.count) matched").font(.caption)
        }
    }
    var sorting: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(ordered.enumerated()), id: \.element) { position, index in
                    HStack {
                        Text(phrases[index].text).frame(maxWidth: .infinity, alignment: .leading)
                        Button { if position > 0 { ordered.swapAt(position, position - 1) } } label: { Image(systemName: "arrow.up") }.accessibilityLabel("Move sentence up").disabled(position == 0 || correct)
                        Button { if position + 1 < ordered.count { ordered.swapAt(position, position + 1) } } label: { Image(systemName: "arrow.down") }.accessibilityLabel("Move sentence down").disabled(position + 1 == ordered.count || correct)
                    }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                Button("Check order") { result(ordered == Array(phrases.indices)) }.buttonStyle(.borderedProminent).disabled(correct)
                if let feedback { Text(LocalizedStringKey(feedback)) }
            }.padding()
        }
    }
    func prepare() {
        correct = false; feedback = nil; answer = ""; hint = false; picked = []
        if activity.kind == "SortPhrasesActivity" { ordered = Array(phrases.indices).shuffled(); return }
        if activity.kind == "WordOrderActivity" { ordered = Array(units.indices).shuffled(); return }
        if isMatching { ordered = Array(0..<min(5, max(0, tokens.count - card * 5))).shuffled(); return }
        let expected = isCloze ? token?.text : tokenBased ? token?.translation : phrase?.translation
        guard let expected else { choices = []; return }
        let pool = isCloze ? lesson.phrases.flatMap(\.tokens).map(\.text) : tokenBased ? tokens.map(\.translation) : phrases.map(\.translation)
        choices = ([expected] + Array(Set(pool).subtracting([expected])).shuffled().prefix(3)).shuffled()
    }
    func normalize(_ text: String) -> String { text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: lesson.language ?? "en")).components(separatedBy: CharacterSet.alphanumerics.inverted).joined() }
    func check(_ answer: String, expected: String) { result(!expected.isEmpty && normalize(answer) == normalize(expected)) }
    func result(_ success: Bool) {
        correct = success; feedback = success ? "Well done!" : "Try again"
        UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
        if success { speech.stop(); playback.pause() }
    }
    func next() {
        if isRead || isWatch || isMatching || activity.kind == "SortPhrasesActivity" || card + 1 >= count { completed() }
        else { card += 1 }
    }
}
