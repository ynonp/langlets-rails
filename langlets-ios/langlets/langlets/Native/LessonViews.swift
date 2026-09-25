import SwiftUI

struct NativeLessonScreen: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let summary: NativeLessonSummary
    var body: some View {
        NavigationStack {
            Group {
                if let lesson = store.lesson(summary.id) { NativeLessonFlow(lesson: lesson) }
                else { ContentUnavailableView("Connect to get this lesson", systemImage: "arrow.down.circle", description: Text("Download lessons before travelling. Downloads need an access check every seven days.")) }
            }.navigationTitle(summary.name ?? "Practice").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
                .task { await store.load("lessons/\(summary.id)", as: NativeLesson.self) }
        }
    }
}
struct NativeReviewScreen: View {
    @EnvironmentObject var store: NativeStore
    let language: String
    var lesson: NativeLesson? { store.cached("review/\(language)", as: NativeLesson.self) }
    var body: some View {
        Group {
            if let lesson, lesson.availableOffline { NativeLessonFlow(lesson: lesson) }
            else { ContentUnavailableView("No downloaded review", systemImage: "character.book.closed", description: Text("Save vocabulary and open a review while connected to prepare it for offline practice.")) }
        }.navigationTitle("Vocabulary practice").task { await store.load("review/\(language)", as: NativeLesson.self) }
    }
}
struct NativeLessonFlow: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let lesson: NativeLesson
    @State private var index = 0
    @State private var finished = false
    @State private var saving = false
    var body: some View {
        Group {
            if finished {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 70)).foregroundStyle(.mint).accessibilityHidden(true)
                    Text("Lesson complete!").font(.largeTitle.bold())
                    Text(store.online ? "Your progress is saved." : "Saved on this device. Your progress will sync when you reconnect.")
                    Button("Continue") { dismiss() }.buttonStyle(.borderedProminent)
                }.padding()
            } else if lesson.activities.indices.contains(index) {
                VStack(spacing: 12) {
                    HStack {
                        Text("\(index + 1) of \(lesson.activities.count)").font(.caption.monospacedDigit())
                        ProgressView(value: Double(index), total: Double(max(1, lesson.activities.count)))
                        Menu("Activities") { ForEach(Array(lesson.activities.enumerated()), id: \.element.id) { offset, activity in Button(activity.title ?? activity.kind) { index = offset } } }
                    }.padding(.horizontal)
                    NativeExercise(activity: lesson.activities[index], lesson: lesson) { completeActivity() }.id(lesson.activities[index].id)
                    Button("Skip activity") { advance() }.font(.footnote).padding(.bottom, 8).disabled(saving)
                }
            } else { ContentUnavailableView("No exercises yet", systemImage: "book") }
        }.onAppear {
            let done = Set(lesson.completedActivityIds).union(store.state.completedActivities)
            index = min(store.state.lessonPositions[lesson.id] ?? lesson.activities.firstIndex(where: { !done.contains($0.id) }) ?? 0, max(0, lesson.activities.count - 1))
        }.onChange(of: index) { _, next in
            Task { do { try await store.recordPosition(lesson: lesson.id, index: next) } catch { store.error = error.localizedDescription } }
        }.onDisappear { NativePronunciation.shared.stop() }
    }
    func completeActivity() {
        guard !saving else { return }
        saving = true
        Task {
            defer { saving = false }
            do {
                try await store.enqueue(["kind": .string("activity_complete"), "activity_id": .integer(lesson.activities[index].id)])
                advance()
            } catch { store.error = error.localizedDescription }
        }
    }
    func advance() {
        NativePronunciation.shared.stop()
        if index + 1 < lesson.activities.count { index += 1 }
        else {
            Task {
                do { try await store.enqueue(["kind": .string("lesson_complete"), "lesson_id": .integer(lesson.id)]); finished = true; UINotificationFeedbackGenerator().notificationOccurred(.success) }
                catch { store.error = error.localizedDescription }
            }
        }
    }
}

struct NativeCourseTranscript: View {
    @EnvironmentObject var store: NativeStore
    let course: NativeCourse
    @State private var bundle: NativeDownload?
    var phrases: [NativePhrase] {
        guard let download = bundle ?? store.state.downloads[course.slug], download.lessons.allSatisfy(\.availableOffline) else { return [] }
        return download.phrases
    }
    var body: some View {
        NativeTranscript(phrases: phrases, end: course.lessons.compactMap(\.end).max())
            .navigationTitle("Watch and read").navigationBarTitleDisplayMode(.inline)
            .task {
                guard store.online else { return }
                do { let data = try await store.request(NativeStore.api + "courses/\(course.slug)/download"); bundle = try JSONDecoder.native.decode(NativeDownload.self, from: data) }
                catch { store.error = error.localizedDescription }
            }
    }
}

struct NativeTranscript: View {
    @EnvironmentObject var store: NativeStore
    let phrases: [NativePhrase]
    var end: Double? = nil
    @StateObject private var playback = NativePlayback()
    @State private var translation = false
    @State private var textOnly = false
    @State private var karaoke = true
    @State private var sentencePause = false
    @State private var selected: SelectedWord?
    @State private var lastPhrase: Int?
    @State private var resumeAfterWord = false
    struct SelectedWord: Identifiable { let token: NativeToken; let phrase: NativePhrase; var id: Int { token.id } }
    var body: some View {
        VStack(spacing: 8) {
            if !textOnly, store.online, let phrase = phrases.first, let provider = phrase.provider, let videoId = phrase.videoId {
                NativeProviderPlayer(provider: provider, videoId: videoId, start: phrase.start ?? 0, end: end, playback: playback).frame(height: 220)
            } else if !store.online && !textOnly { Label("Video needs a connection · Read and practise offline", systemImage: "wifi.slash").font(.caption).padding() }
            if let failure = playback.failure { Text(failure).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Toggle("Translation", isOn: $translation).labelsHidden().accessibilityLabel("Show translation")
                Menu { Toggle("Text only", isOn: $textOnly); Toggle("Karaoke", isOn: $karaoke); Toggle("Pause after sentences", isOn: $sentencePause) } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Playback options")
                Spacer()
                Button { UIPasteboard.general.string = phrases.map { translation ? $0.translation : $0.text }.joined(separator: "\n") } label: { Image(systemName: "doc.on.doc") }.accessibilityLabel("Copy transcript")
            }.padding(.horizontal)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(phrases) { phrase in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    if translation { Text(phrase.translation).font(.title3) }
                                    else {
                                        NativeInlinePhrase(phrase: phrase, time: karaoke ? playback.position : nil, selectedId: selected?.id) { token in
                                            resumeAfterWord = resumeAfterWord || playback.playing
                                            playback.pause(); selected = SelectedWord(token: token, phrase: phrase)
                                            Task {
                                                await playback.pauseAndWait()
                                                guard selected?.id == token.id else { return }
                                                await NativePronunciation.shared.play(token, language: phrase.language, store: store)
                                            }
                                        }
                                    }
                                    Spacer(minLength: 4)
                                    Button { playback.seek(phrase.start ?? 0) } label: { Image(systemName: "play.circle") }.accessibilityLabel("Replay sentence")
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).environment(\.layoutDirection, phrase.rtl ? .rightToLeft : .leftToRight).id(phrase.id)
                        }
                    }.padding()
                }.onChange(of: playback.position) { old, value in
                    let active = phrases.last { ($0.start ?? 0) <= value }?.id
                    if sentencePause && value >= old && value - old < 2 {
                        let boundaries = phrases.dropLast().enumerated().map { index, phrase in phrase.tokens.compactMap(\.end).max() ?? phrases[index + 1].start ?? .infinity }
                        if boundaries.contains(where: { old < $0 && $0 <= value }) { playback.pause() }
                    }
                    if active != lastPhrase {
                        lastPhrase = active
                        if let active { withAnimation { proxy.scrollTo(active, anchor: .center) } }
                    }
                }
            }
        }.onChange(of: textOnly) { _, value in if value { playback.pause() } }
            .onDisappear { playback.pause(); NativePronunciation.shared.stop() }
            .sheet(item: $selected, onDismiss: {
                NativePronunciation.shared.stop()
                if resumeAfterWord { playback.resume() }; resumeAfterWord = false
            }) { word in
                VStack(spacing: 20) {
                    Text(word.token.text).font(.largeTitle.bold())
                    Text(word.token.translation).font(.title2)
                    Button("Save word") { Task {
                        do { try await store.enqueue(["kind": .string("word_save"), "token_id": .integer(word.token.id)]); selected = nil }
                        catch { store.error = error.localizedDescription }
                    } }.buttonStyle(.borderedProminent)
                    Button("Close") { selected = nil; NativePronunciation.shared.stop() }
                }.padding().presentationDetents([.medium])
            }
    }
}

struct NativeTokenChips: View {
    let tokens: [NativeToken]
    var activeTime: Double? = nil
    let selected: (NativeToken) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], alignment: .leading) {
            ForEach(tokens) { token in
                Button(token.text) { selected(token) }.buttonStyle(.bordered)
                    .tint(activeTime != nil && (token.start ?? .infinity) <= activeTime! && (token.end ?? -.infinity) > activeTime! ? .mint : .secondary)
            }
        }
    }
}
