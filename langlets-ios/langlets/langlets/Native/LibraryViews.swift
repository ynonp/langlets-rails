import SwiftUI

struct NativeCreate: View {
    @EnvironmentObject var store: NativeStore
    @State private var preview: Preview?
    @State private var previewURL = ""
    @State private var busy = false
    @State private var clientToken = UUID()
    @State private var status: String?
    struct Preview: Decodable {
        let title: String
        let thumbnailUrl: String?
        let status: String
        let cost: Int
        let pro: Bool
        let credits: Int
        let courseSlug: String?
    }
    var body: some View {
        Form {
            Section("Turn a video into practice") {
                Text("Paste a YouTube or TikTok link, or share a video directly to Langlets from its share menu.")
                TextField("Video link", text: $store.importDraft).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                PasteButton(payloadType: String.self) { values in store.importDraft = values.first ?? "" }
                Button("Preview") { perform {
                    var query = URLComponents(); query.queryItems = [URLQueryItem(name: "url", value: store.importDraft)]
                    let data = try await store.request(NativeStore.api + "import_preview?" + (query.percentEncodedQuery ?? ""))
                    preview = try JSONDecoder.native.decode(Preview.self, from: data)
                    previewURL = store.importDraft
                } }.disabled(busy || !store.online || store.importDraft.isEmpty)
                if busy { ProgressView() }
            }
            if let preview, previewURL == store.importDraft {
                Section {
                    Text(preview.title).font(.headline)
                    if preview.status == "paused" { Text("This course belongs to your paused Pro library. Contact support to restore access.") }
                    else if preview.status == "in_queue" { NavigationLink("Already being prepared · View status") { NativeImportStatus() } }
                    else if preview.status == "in_library", let slug = preview.courseSlug { NavigationLink("Open course") { NativeCourseScreen(slug: slug) } }
                    else {
                        Text(preview.pro ? "Included with Pro" : "\(preview.cost) import credit · \(preview.credits) remaining")
                        Button("Create this langlet") { perform {
                            _ = try await store.request("/api/v1/import_requests", method: "POST", body: ["url": previewURL, "client_token": clientToken.uuidString])
                            status = "Your video is being prepared. Follow its progress in Import status."
                            self.preview = nil; store.importDraft = ""; clientToken = UUID()
                            await store.refresh()
                        } }.disabled(busy || !store.online || (!preview.pro && preview.cost > preview.credits))
                    }
                }
            }
            if let status { Section { Text(status) } }
            NavigationLink("Import status") { NativeImportStatus() }
        }.navigationTitle("Create").accountToolbar()
            .onChange(of: store.importDraft) { _, _ in preview = nil; clientToken = UUID() }
    }
    func perform(_ action: @escaping () async throws -> Void) {
        busy = true
        Task { defer { busy = false }; do { try await action() } catch { store.error = error.localizedDescription } }
    }
}

struct NativeImportStatus: View {
    @EnvironmentObject var store: NativeStore
    @State private var items: [NativeImport] = []
    var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title ?? "Video").font(.headline)
                Text(item.status == "failed" ? "Import failed. The team is reviewing it; no credit was used." : item.status.capitalized).font(.subheadline)
                if ["queued", "importing", "detecting"].contains(item.status) { ProgressView(value: Double(item.progressPercent ?? 0), total: 100) }
                if let course = item.course { NavigationLink("Open course") { NativeCourseScreen(slug: course.slug) } }
                if ["failed", "ready", "queued"].contains(item.status) {
                    Button(item.status == "queued" ? "Cancel import" : "Remove from history", role: .destructive) { Task {
                        do { _ = try await store.request(NativeStore.api + "imports/\(item.id)", method: "DELETE"); await refresh() }
                        catch { store.error = error.localizedDescription }
                    } }
                }
            }.padding(.vertical, 8)
        }.navigationTitle("Import status").refreshable { await refresh() }.task {
            await refresh()
            while !Task.isCancelled && items.contains(where: { ["queued", "importing", "detecting"].contains($0.status) }) {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                await refresh()
            }
        }
    }
    func refresh() async {
        guard store.online else { return }
        do { let data = try await store.request("/api/v1/import_requests"); items = try JSONDecoder.native.decode(NativeImports.self, from: data).importRequests }
        catch { store.error = error.localizedDescription }
    }
}

struct NativePlaylists: View {
    @EnvironmentObject var store: NativeStore
    var courseSlug: String? = nil
    @State private var name = ""
    @State private var page = 1
    var key: String { "playlists?page=\(page)" }
    var result: NativePage<NativePlaylist>? { store.cached(key, as: NativePage<NativePlaylist>.self) }
    var body: some View {
        List {
            Section("New playlist") {
                TextField("Name", text: $name)
                Button("Create playlist") { Task {
                    do { _ = try await store.request(NativeStore.api + "playlists", method: "POST", body: ["name": name]); name = ""; await store.load(key, as: NativePage<NativePlaylist>.self) }
                    catch { store.error = error.localizedDescription }
                } }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !store.online)
            }
            ForEach(result?.items ?? []) { playlist in
                if let courseSlug, playlist.owned {
                    Button(playlist.name) { Task {
                        do { _ = try await store.request(NativeStore.api + "playlists/\(playlist.id)", method: "PATCH", body: ["course_slug": courseSlug, "included": true]) }
                        catch { store.error = error.localizedDescription }
                    } }
                } else { NavigationLink(playlist.name) { NativePlaylistScreen(playlist: playlist) } }
            }
            HStack { if page > 1 { Button("Previous") { page -= 1 } }; Spacer(); if result?.nextPage != nil { Button("Next") { page += 1 } } }
        }.navigationTitle("Playlists").task(id: key) { await store.load(key, as: NativePage<NativePlaylist>.self) }
    }
}

struct NativePlaylistScreen: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let playlist: NativePlaylist
    @State private var page = 1
    @State private var confirm = false
    var key: String { "playlists/\(playlist.id)?page=\(page)" }
    var result: NativePlaylist? { store.cached(key, as: NativePlaylist.self) }
    var body: some View {
        List {
            Text(playlist.description ?? "")
            ForEach(result?.courses?.items ?? []) { course in
                NavigationLink { NativeCourseScreen(slug: course.slug) } label: { NativeCourseRow(course: course) }
                    .swipeActions { if playlist.owned { Button("Remove", role: .destructive) { Task {
                        do { _ = try await store.request(NativeStore.api + "playlists/\(playlist.id)", method: "PATCH", body: ["course_slug": course.slug, "included": false]); await store.load(key, as: NativePlaylist.self) }
                        catch { store.error = error.localizedDescription }
                    } } } }
            }
            HStack { if page > 1 { Button("Previous") { page -= 1 } }; Spacer(); if result?.courses?.nextPage != nil { Button("Next") { page += 1 } } }
            if playlist.owned { Button("Delete playlist", role: .destructive) { confirm = true }.disabled(!store.online) }
        }.navigationTitle(playlist.name).task(id: key) { await store.load(key, as: NativePlaylist.self) }
            .confirmationDialog("Delete this playlist? Your courses will remain.", isPresented: $confirm) {
                Button("Delete playlist", role: .destructive) { Task { do { _ = try await store.request(NativeStore.api + "playlists/\(playlist.id)", method: "DELETE"); dismiss() } catch { store.error = error.localizedDescription } } }
            }
    }
}

struct NativeNotifications: View {
    @EnvironmentObject var store: NativeStore
    @State private var page = 1
    var key: String { "notifications?page=\(page)" }
    var result: NativePage<NativeNotice>? { store.cached(key, as: NativePage<NativeNotice>.self) }
    var body: some View {
        List {
            Button("Mark all read") { mark(nil) }
            ForEach(result?.items ?? []) { notice in
                Button {
                    mark(notice.id)
                    if let path = notice.url, let url = URL(string: path, relativeTo: rootURL) { store.route(url) }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(notice.title).font(.headline)
                        Text(notice.body).foregroundStyle(.secondary)
                        if !notice.read { Text("New").font(.caption).foregroundStyle(.mint) }
                    }.padding(.vertical, 5)
                }
            }
            HStack { if page > 1 { Button("Previous") { page -= 1 } }; Spacer(); if result?.nextPage != nil { Button("Next") { page += 1 } } }
        }.navigationTitle("Notifications").task(id: key) { await store.load(key, as: NativePage<NativeNotice>.self) }
    }
    func mark(_ id: Int?) { Task {
        var payload: [String: NativeValue] = ["kind": .string("notification_read")]
        if let id { payload["notification_id"] = .integer(id) }
        do { try await store.enqueue(payload); await store.sync(); await store.load(key, as: NativePage<NativeNotice>.self) }
        catch { store.error = error.localizedDescription }
    } }
}

struct NativeStartedCourses: View {
    @EnvironmentObject var store: NativeStore
    @State private var page = 1
    var key: String { "courses?enrolled=true&page=\(page)" }
    var result: NativePage<NativeCourse>? { store.cached(key, as: NativePage<NativeCourse>.self) }
    var body: some View {
        List {
            ForEach(result?.items ?? []) { course in NavigationLink { NativeCourseScreen(slug: course.slug) } label: { NativeCourseRow(course: course) } }
            HStack { if page > 1 { Button("Previous") { page -= 1 } }; Spacer(); if result?.nextPage != nil { Button("Next") { page += 1 } } }
        }.navigationTitle("Started videos").task(id: key) { await store.load(key, as: NativePage<NativeCourse>.self) }
    }
}
