import Foundation

extension NativeStore {
    // Pending desired-state edits are layered on cached server pages, so a relaunch
    // offline never visually undoes a saved change. Failed writes stay in Sync status.
    func vocabularyPage(_ key: String) -> [NativeVocabulary] {
        var entries = cached(key, as: NativePage<NativeVocabulary>.self)?.items ?? []
        if !online {
            var ids: Set<Int> = []
            entries = state.responses.keys.filter { $0.hasPrefix("vocabulary?") }.sorted().flatMap { cached($0, as: NativePage<NativeVocabulary>.self)?.items ?? [] }.filter { ids.insert($0.id).inserted }
            if let code = URLComponents(string: key)?.queryItems?.first(where: { $0.name == "language" })?.value, !code.isEmpty { entries = entries.filter { $0.language == code } }
        }
        for operation in state.outbox where operation.failure == nil {
            let data = operation.payload
            switch data["kind"] {
            case .string("word_remove")?:
                if case .integer(let id)? = data["token_id"] { entries.removeAll { $0.tokenId == id } }
            case .string("word_update")?:
                if case .integer(let id)? = data["entry_id"], let index = entries.firstIndex(where: { $0.id == id }) {
                    if case .bool(let value)? = data["practicing"] { entries[index].practicing = value }
                    if case .string(let value)? = data["translation"] { entries[index].translation = value }
                }
            case .string("word_create")?:
                guard (key == "vocabulary?page=1&filter=&language=" || key == "vocabulary?page=1&filter=&language=&q="), case .string(let text)? = data["sentence"], case .string(let translation)? = data["translation"], case .string(let language)? = data["language"], case .integer(let first)? = data["token_start"], case .integer(let last)? = data["token_end"] else { continue }
                let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
                guard first >= 0, last >= first, last < words.count else { continue }
                let normalized = words.joined(separator: " ")
                let start = words.prefix(first).joined(separator: " ").unicodeScalars.count + (first == 0 ? 0 : 1)
                let word = words[first...last].joined(separator: " ")
                let id = -(Int(operation.id.uuidString.prefix(8), radix: 16) ?? 1)
                let token = NativeToken(id: id, text: word, translation: translation, startIndex: start, endIndex: start + word.unicodeScalars.count - 1, start: nil, end: nil, questions: [], similarSounds: [], audio: nil)
                let phrase = NativePhrase(id: id, text: normalized, translation: "", language: language, rtl: ["he", "ar", "ar-JO"].contains(language), start: nil, provider: nil, videoId: nil, audio: nil, tokens: [token])
                entries.insert(NativeVocabulary(id: id, tokenId: id, language: language, translation: translation, practicing: true, custom: true, phrase: phrase, token: token), at: 0)
            default: break
            }
        }
        if key.contains("filter=paused") { entries = entries.filter { !$0.practicing } }
        return entries
    }
}
