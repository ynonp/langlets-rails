import SwiftUI

struct NativeVocabularyList: View {
    @EnvironmentObject var store: NativeStore
    @State private var query = ""
    @State private var page = 1
    @State private var paused = false
    @State private var language = ""
    @State private var add = false
    @State private var removed: NativeVocabulary?
    var key: String {
        var parts = URLComponents(); parts.queryItems = [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "filter", value: paused ? "paused" : ""), URLQueryItem(name: "language", value: language), URLQueryItem(name: "q", value: query)]
        return "vocabulary?" + (parts.percentEncodedQuery ?? "")
    }
    var result: NativePage<NativeVocabulary>? { store.cached(key, as: NativePage<NativeVocabulary>.self) }
    var entries: [NativeVocabulary] { store.vocabularyPage(key).filter { query.isEmpty || ($0.phrase.text + " " + $0.translation).localizedCaseInsensitiveContains(query) } }
    var body: some View {
        List {
            Picker("Language", selection: $language) { Text("All languages").tag(""); ForEach(store.languages) { Text($0.name).tag($0.code) } }
            Toggle("Paused words", isOn: $paused)
            ForEach(entries) { entry in
                NavigationLink { NativeWordDetail(entry: entry) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.token.text).font(.headline)
                        Text(entry.translation).foregroundStyle(.secondary)
                        Text(entry.phrase.text).font(.caption).lineLimit(2)
                    }.padding(.vertical, 4)
                }.disabled(entry.id < 0).swipeActions {
                    Button("Delete", role: .destructive) { Task { do { try await store.enqueue(["kind": .string("word_remove"), "token_id": .integer(entry.tokenId)]); removed = entry; await store.sync(); await store.load(key, as: NativePage<NativeVocabulary>.self) } catch { store.error = error.localizedDescription } } }
                }
            }
            if let removed { Button("Undo deletion of \(removed.token.text)") { Task { do { try await store.enqueue(["kind": .string("word_save"), "token_id": .integer(removed.tokenId)]); self.removed = nil; await store.sync(); await store.load(key, as: NativePage<NativeVocabulary>.self) } catch { store.error = error.localizedDescription } } } }
            HStack { if page > 1 { Button("Previous") { page -= 1 } }; Spacer(); if result?.nextPage != nil { Button("Next") { page += 1 } } }
        }.navigationTitle("Vocabulary").accountToolbar().searchable(text: $query, prompt: "Search vocabulary")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button { add = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add word") } }
            .sheet(isPresented: $add) { NativeAddWord().environmentObject(store) }
            .task(id: key) { try? await Task.sleep(for: .milliseconds(250)); guard !Task.isCancelled else { return }; await store.load(key, as: NativePage<NativeVocabulary>.self) }
            .onChange(of: query) { _, _ in page = 1 }
            .refreshable { await store.load(key, as: NativePage<NativeVocabulary>.self) }
    }
}
struct NativeWordDetail: View {
    @EnvironmentObject var store: NativeStore
    let entry: NativeVocabulary
    @State private var practicing = true
    @State private var translation = ""
    var body: some View {
        Form {
            Section { Text(entry.phrase.text).font(.title2); Text(entry.token.text).font(.headline); Text(entry.translation) }
            Button("Listen") { Task { await NativePronunciation.shared.play(entry.token, language: entry.language, store: store) } }
            Toggle("Practise this word", isOn: $practicing)
            TextField("Translation", text: $translation)
            Button("Save changes") { Task {
                var payload: [String: NativeValue] = ["kind": .string("word_update"), "entry_id": .integer(entry.id), "practicing": .bool(practicing)]
                payload["translation"] = .string(translation)
                do { try await store.enqueue(payload) } catch { store.error = error.localizedDescription }
            } }
        }.navigationTitle(entry.token.text).onAppear { practicing = entry.practicing; translation = entry.translation }
    }
}
struct NativeAddWord: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    @State private var sentence = ""
    @State private var translation = ""
    @State private var language = "es"
    @State private var first: Int?
    @State private var last: Int?
    var words: [String] { sentence.split(whereSeparator: \.isWhitespace).map(String.init) }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Language", selection: $language) { ForEach(store.languages) { Text($0.name).tag($0.code) } }
                TextField("Sentence", text: $sentence, axis: .vertical).onChange(of: sentence) { _, _ in first = nil; last = nil }
                Section("Tap the first and last word to save") {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        Button { if first == nil || last != nil { first = index; last = nil } else { last = index } } label: {
                            HStack { Text(word); Spacer(); if selected(index) { Image(systemName: "checkmark") } }
                        }
                    }
                }
                TextField("Translation", text: $translation)
                Button("Save word") { Task {
                    guard let first else { return }
                    do { try await store.enqueue(["kind": .string("word_create"), "sentence": .string(sentence), "language": .string(language), "token_start": .integer(min(first, last ?? first)), "token_end": .integer(max(first, last ?? first)), "translation": .string(translation)]); dismiss() }
                    catch { store.error = error.localizedDescription }
                } }.disabled(first == nil || translation.trimmingCharacters(in: .whitespaces).isEmpty)
            }.navigationTitle("Add vocabulary").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    func selected(_ index: Int) -> Bool { guard let first else { return false }; return (min(first, last ?? first)...max(first, last ?? first)).contains(index) }
}
