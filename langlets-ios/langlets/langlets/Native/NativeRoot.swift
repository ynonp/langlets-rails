import SwiftUI

struct NativeRoot: View {
    @StateObject private var store = NativeStore.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if !store.ready { ProgressView("Opening Langlets…") }
            else if store.session == nil { NativeWelcome() }
            else {
                TabView(selection: $store.selectedTab) {
                    NavigationStack { NativeHome() }.tabItem { Label("Home", systemImage: "house") }.tag(0)
                    NavigationStack { NativeLibrary() }.tabItem { Label("Library", systemImage: "play.rectangle.on.rectangle") }.tag(1)
                    NavigationStack { NativeVocabularyList() }.tabItem { Label("Vocabulary", systemImage: "character.book.closed") }.tag(2)
                    NavigationStack { NativeCreate() }.tabItem { Label("Create", systemImage: "plus.circle") }.tag(3)
                }
                .id(store.session?.userId)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !store.online || !store.state.outbox.isEmpty {
                        HStack {
                            Image(systemName: store.online ? "arrow.triangle.2.circlepath" : "wifi.slash")
                            Text(store.online ? "\(store.state.outbox.count) changes waiting to sync" : "Offline · Your downloaded practice is available")
                                .font(.caption)
                            Spacer()
                        }.padding(8).background(.thinMaterial)
                    }
                }
            }
        }
        .environmentObject(store)
        .environment(\.locale, Locale(identifier: store.account?.nativeLanguage ?? Locale.current.language.languageCode?.identifier ?? "en"))
        .environment(\.layoutDirection, store.account?.nativeLanguage == "he" ? .rightToLeft : .leftToRight)
        .preferredColorScheme(store.account?.theme == "light" ? .light : .dark)
        .tint(.mint)
        .task { await store.start() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } else { NativePronunciation.shared.stop() } }
        .sheet(isPresented: Binding(get: { store.session != nil && store.invitationRoute }, set: { store.invitationRoute = $0 })) { NavigationStack { NativeInvitations() }.environmentObject(store) }
        .sheet(item: Binding(get: { store.resetPasswordToken.map(CourseDestination.init) }, set: { store.resetPasswordToken = $0?.id })) { destination in
            NativeEmailAction(token: destination.id, reset: true).environmentObject(store)
        }
        .sheet(item: Binding(get: { store.confirmationToken.map(CourseDestination.init) }, set: { store.confirmationToken = $0?.id })) { destination in
            NativeEmailAction(token: destination.id, reset: false).environmentObject(store)
        }
        .sheet(isPresented: Binding(get: { store.session != nil && store.challengeRoute }, set: { store.challengeRoute = $0 })) { NavigationStack { NativeChallengeScreen() }.environmentObject(store) }
        .sheet(item: Binding(get: { (store.session == nil ? nil : store.reviewRoute).map(CourseDestination.init) }, set: { store.reviewRoute = $0?.id })) { destination in
            NavigationStack { NativeReviewScreen(language: destination.id) }.environmentObject(store)
        }
        .sheet(isPresented: $store.needsSignIn) { NativeSignIn().environmentObject(store) }
        .sheet(item: Binding(get: { (store.session == nil ? nil : store.courseRoute).map(CourseDestination.init) }, set: { store.courseRoute = $0?.id })) { destination in
            NavigationStack { NativeCourseScreen(slug: destination.id).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { store.courseRoute = nil } } } }
                .environmentObject(store)
        }
        .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
    private struct CourseDestination: Identifiable { let id: String }
}

struct NativeAccountToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { NativeProfile() } label: { Image(systemName: "person.crop.circle") }.accessibilityLabel("Profile")
            }
        }
    }
}
extension View { func accountToolbar() -> some View { modifier(NativeAccountToolbar()) } }

struct NativeHome: View {
    @EnvironmentObject var store: NativeStore
    var courses: [NativeCourse] { store.cached("courses?enrolled=true", as: NativePage<NativeCourse>.self)?.items ?? [] }
    var latest: [NativeCourse] { store.cached("courses", as: NativePage<NativeCourse>.self)?.items ?? [] }
    var unfinished: [NativeCourse] { courses.filter { Set($0.completedLessonIds).union(store.state.completedLessons).intersection($0.lessons.map(\.id)).count < $0.lessonCount } }
    var body: some View {
        List {
            Section {
                HStack { Label("\(store.account?.streak ?? 0) day streak", systemImage: "flame.fill"); Spacer(); Text("\(store.account?.totalXp ?? 0) XP") }
                NavigationLink("Daily challenge") { NativeChallengeScreen() }
            }
            if let bootstrap = store.cached("bootstrap", as: NativeBootstrap.self), !bootstrap.reviewLanguages.isEmpty {
                Section("Daily vocabulary") {
                    ForEach(bootstrap.reviewLanguages, id: \.self) { code in
                        NavigationLink("Practice \(store.languages.first { $0.code == code }?.name ?? code)") { NativeReviewScreen(language: code) }
                    }
                }
            }
            Section("Continue") {
                if unfinished.isEmpty { ContentUnavailableView("No langlets yet", systemImage: "play.rectangle", description: Text("Share a video to Langlets or explore the Library to start learning.")) }
                ForEach(Array(unfinished.prefix(2))) { course in NavigationLink { NativeCourseScreen(slug: course.slug) } label: { NativeCourseRow(course: course) } }
            }
            Section("Latest imports") {
                ForEach(Array(latest.prefix(4))) { course in NavigationLink { NativeCourseScreen(slug: course.slug) } label: { NativeCourseRow(course: course) } }
                Button("View all") { store.selectedTab = 1 }
            }
            Section {
                NavigationLink("Started videos") { NativeStartedCourses() }
                NavigationLink("Downloads") { NativeDownloads() }
                NavigationLink("Playlists") { NativePlaylists() }
                NavigationLink("Notifications") { NativeNotifications() }
            }
        }.navigationTitle("langlets.").accountToolbar()
            .refreshable { await store.refresh() }
            .task { await store.load("courses", as: NativePage<NativeCourse>.self) }
    }
}

struct NativeCourseRow: View {
    let course: NativeCourse
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: course.thumbnailUrl.flatMap(URL.init(string:))) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.secondary) }
                .frame(width: 88, height: 66).clipped().clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(course.name).font(.headline).lineLimit(2)
                Text("\(course.language ?? "") · \(course.lessonCount) lessons").font(.caption).foregroundStyle(.secondary)
                if !course.completedLessonIds.isEmpty { ProgressView(value: Double(course.completedLessonIds.count), total: Double(max(course.lessonCount, 1))) }
            }
        }.padding(.vertical, 4)
    }
}

struct NativeLibrary: View {
    @EnvironmentObject var store: NativeStore
    @State private var query = ""
    @State private var language = ""
    @State private var filter = ""
    @State private var page = 1
    var key: String {
        var parts = URLComponents(); parts.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "language", value: language), URLQueryItem(name: "filter", value: filter), URLQueryItem(name: "page", value: String(page))]
        return "courses?" + (parts.percentEncodedQuery ?? "")
    }
    var results: NativePage<NativeCourse>? { store.cached(key, as: NativePage<NativeCourse>.self) }
    var offlineCourses: [NativeCourse] {
        store.state.downloads.values.map(\.course).filter { (language.isEmpty || $0.language == language) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }.sorted { $0.name < $1.name }
    }
    var body: some View {
        List {
            Section {
                Picker("Language", selection: $language) { Text("All languages").tag(""); ForEach(store.languages) { Text($0.name).tag($0.code) } }
                Picker("Show", selection: $filter) { Text("All").tag(""); Text("My imports").tag("my_imports") }
                NavigationLink("Import status") { NativeImportStatus() }
                NavigationLink("Playlists") { NativePlaylists() }
            }
            if results?.items.isEmpty == true { ContentUnavailableView.search(text: query) }
            if !store.online { Text("Searching downloaded courses").font(.caption).foregroundStyle(.secondary) }
            ForEach(store.online ? (results?.items ?? []) : offlineCourses) { course in NavigationLink { NativeCourseScreen(slug: course.slug) } label: { NativeCourseRow(course: course) } }
            HStack {
                if page > 1 { Button("Previous") { page -= 1 } }
                Spacer()
                if results?.nextPage != nil { Button("Next") { page += 1 } }
            }
        }.navigationTitle("Library").accountToolbar().searchable(text: $query)
            .task(id: key) { try? await Task.sleep(for: .milliseconds(300)); guard !Task.isCancelled else { return }; await store.load(key, as: NativePage<NativeCourse>.self) }
            .onChange(of: query) { _, _ in page = 1 }.onChange(of: language) { _, _ in page = 1 }
            .refreshable { await store.load(key, as: NativePage<NativeCourse>.self) }
    }
}

struct NativeCourseScreen: View {
    @EnvironmentObject var store: NativeStore
    let slug: String
    @State private var working = false
    @State private var confirm: String?
    @State private var lesson: NativeLessonSummary?
    var course: NativeCourse? { store.cached("courses/\(slug)", as: NativeCourse.self) ?? store.state.downloads[slug]?.course }
    var body: some View {
        Group {
            if let course {
                List {
                    Section {
                        NativeCourseRow(course: course)
                        Button(store.state.downloads[slug] == nil ? "Download for offline practice" : "Refresh download") { run { try await store.download(slug) } }
                            .disabled(working || !store.online)
                        if working { ProgressView(store.downloadProgress[slug] ?? "Preparing…") }
                        NavigationLink("Watch and read") { NativeCourseTranscript(course: course) }
                        if !course.enrolled { Button("Learn this") { action("enroll") } }
                        if !course.translationReady { Button("Translate into my language") { action("translate") } }
                    }
                    Section("Lessons") {
                        ForEach(course.lessons) { row in
                            Button { lesson = row } label: {
                                HStack {
                                    Text(row.name ?? "Lesson")
                                    Spacer()
                                    if course.completedLessonIds.contains(row.id) || store.state.completedLessons.contains(row.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint) }
                                }.padding(.vertical, 8)
                            }
                        }
                    }
                    Section {
                        NavigationLink("Add to playlist") { NativePlaylists(courseSlug: slug) }
                        if course.shared {
                            ShareLink("Share link", item: rootURL.appendingPathComponent("courses/\(slug)"))
                            Button("Stop sharing") { action("unshare") }
                        } else { Button("Create public link") { confirm = "share" } }
                        Button("Mark all lessons complete") { confirm = "mark_done" }
                        Button("Reset progress", role: .destructive) { confirm = "reset" }
                        if course.owned { Button("Remove from my library", role: .destructive) { confirm = "delete" } }
                    }.disabled(!store.online || working)
                }
            } else { ContentUnavailableView("Course unavailable", systemImage: "wifi.slash", description: Text("Connect to download this course.")) }
        }.navigationTitle(course?.name ?? "Course").navigationBarTitleDisplayMode(.inline)
            .task { await store.load("courses/\(slug)", as: NativeCourse.self) }
            .sheet(item: $lesson) { NativeLessonScreen(summary: $0).environmentObject(store) }
            .confirmationDialog("Confirm this change", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })) {
                Button("Confirm", role: confirm == "delete" || confirm == "reset" ? .destructive : nil) { if let confirm { action(confirm) }; confirm = nil }
            } message: { Text(confirm == "share" ? "Anyone with this link will be able to read the course." : "This updates your course and progress on all devices.") }
    }
    func action(_ name: String) {
        run {
            if ["reset", "delete"].contains(name) { await store.sync() }
            _ = try await store.request(NativeStore.api + "courses/\(slug)/action", method: "POST", body: ["operation": name])
            if ["reset", "delete"].contains(name), let course { try await store.resetLocalProgress(course) }
            if name == "delete" { try await store.removeDownload(slug) }
            await store.load("courses/\(slug)", as: NativeCourse.self)
            await store.refresh()
        }
    }
    func run(_ action: @escaping () async throws -> Void) {
        working = true
        Task { defer { working = false }; do { try await action() } catch { store.error = error.localizedDescription } }
    }
}

struct NativeDownloads: View {
    @EnvironmentObject var store: NativeStore
    var body: some View {
        List {
            ForEach(store.state.downloads.values.map(\.course).sorted { $0.name < $1.name }) { course in
                NavigationLink { NativeCourseScreen(slug: course.slug) } label: { NativeCourseRow(course: course) }
                    .swipeActions { Button("Remove download", role: .destructive) { Task { do { try await store.removeDownload(course.slug) } catch { store.error = error.localizedDescription } } } }
            }
            if store.state.downloads.isEmpty { ContentUnavailableView("No downloads", systemImage: "arrow.down.circle", description: Text("Open a course and download it before going offline.")) }
            NavigationLink("Sync status") { NativeSyncStatus() }
        }.navigationTitle("Downloads")
    }
}
