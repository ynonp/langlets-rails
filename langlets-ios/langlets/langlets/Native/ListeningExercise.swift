import SwiftUI

struct NativeListeningExercise: View {
    @EnvironmentObject var store: NativeStore
    let phrases: [NativePhrase]
    let tokenIds: [Int]
    let end: Double?
    let completed: () -> Void
    @StateObject private var playback = NativePlayback()
    @State private var answered: Set<Int> = []
    @State private var pending: NativeToken?
    @State private var options: [String] = []
    @State private var feedback = ""
    var blanks: [NativeToken] { phrases.flatMap(\.tokens).filter { tokenIds.contains($0.id) } }
    var body: some View {
        VStack(spacing: 14) {
            if store.online, let first = phrases.first, let provider = first.provider, let id = first.videoId {
                NativeProviderPlayer(provider: provider, videoId: id, start: first.start ?? 0, end: end, playback: playback).frame(height: 220)
            } else {
                Text("Offline listening uses your device's pronunciation voice.").font(.caption).foregroundStyle(.secondary)
                Button("Listen to the next sentence") { nextOffline() }.buttonStyle(.borderedProminent)
            }
            if let phrase = currentPhrase {
                Text(pending.map { phrase.cloze($0) } ?? phrase.text).font(.title2).padding().environment(\.layoutDirection, phrase.rtl ? .rightToLeft : .leftToRight)
            }
            if let pending {
                Text(pending.translation).font(.title3)
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        if option == pending.text {
                            answered.insert(pending.id); self.pending = nil; feedback = "Well done!"
                            playback.resume()
                        } else { feedback = "Try again" }
                    }.buttonStyle(.bordered).controlSize(.large)
                }
            } else { Text("Listen and fill the missing words.").foregroundStyle(.secondary) }
            Text(feedback).font(.caption)
            Spacer()
            if answered.count >= blanks.count { Button("Next activity", action: completed).buttonStyle(.borderedProminent).padding() }
        }.onChange(of: playback.position) { _, time in
            guard pending == nil else { return }
            if let token = blanks.first(where: { !answered.contains($0.id) && ($0.start ?? phraseStart($0)) <= time + 0.2 }) {
                playback.pause(); present(token)
            }
        }.onDisappear { playback.pause(); NativePronunciation.shared.stop() }
    }
    var currentPhrase: NativePhrase? {
        if let pending { return phrases.first { $0.tokens.contains { $0.id == pending.id } } }
        return phrases.last { ($0.start ?? 0) <= playback.position } ?? phrases.first
    }
    func phraseStart(_ token: NativeToken) -> Double { phrases.first { $0.tokens.contains { $0.id == token.id } }?.start ?? 0 }
    func present(_ token: NativeToken) {
        pending = token
        let distractors = Set(token.similarSounds + phrases.flatMap(\.tokens).map(\.text)).subtracting([token.text])
        options = ([token.text] + distractors.shuffled().prefix(1)).shuffled()
    }
    func nextOffline() {
        guard let token = blanks.first(where: { !answered.contains($0.id) }), let phrase = phrases.first(where: { $0.tokens.contains { $0.id == token.id } }) else { return }
        present(token)
        NativePronunciation.shared.speak(phrase.text, language: phrase.language)
    }
}
