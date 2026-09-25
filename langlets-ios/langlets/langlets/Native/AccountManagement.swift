import SwiftUI

struct NativeConnection: Decodable, Identifiable { let id: Int; let name: String; let scopes: String; let current: Bool }
struct NativeInvitation: Codable, Identifiable { let id: Int; let name: String; let expiresAt: String }

struct NativeConnections: View {
    @EnvironmentObject var store: NativeStore
    @State private var page = 1
    @State private var revoke: NativeConnection?
    var key: String { "connections?page=\(page)" }
    @State private var items: [NativeConnection] = []
    @State private var nextPage: Int?
    var body: some View {
        List {
            ForEach(items) { connection in
                VStack(alignment: .leading) {
                    Text(connection.name).font(.headline)
                    Text(connection.scopes).font(.caption)
                    if connection.current { Text("This session").font(.caption) }
                    else { Button("Revoke access", role: .destructive) { revoke = connection } }
                }
            }
            HStack { if page > 1 { Button("Previous") { page -= 1 } }; Spacer(); if nextPage != nil { Button("Next") { page += 1 } } }
        }.navigationTitle("Connected apps").task(id: page) { await refresh() }
            .confirmationDialog("Revoke this app's access?", isPresented: Binding(get: { revoke != nil }, set: { if !$0 { revoke = nil } })) {
                Button("Revoke", role: .destructive) { Task {
                    guard let revoke else { return }
                    do { _ = try await store.request(NativeStore.api + "connections/\(revoke.id)", method: "DELETE"); self.revoke = nil; await refresh() }
                    catch { store.error = error.localizedDescription }
                } }
            }
    }
    func refresh() async {
        do { let data = try await store.request(NativeStore.api + key); let result = try JSONDecoder.native.decode(ConnectionPage.self, from: data); items = result.items; nextPage = result.nextPage }
        catch { store.error = error.localizedDescription }
    }
    private struct ConnectionPage: Decodable { let items: [NativeConnection]; let nextPage: Int? }
}
struct NativeInvitations: View {
    @EnvironmentObject var store: NativeStore
    @State private var page = 1
    var key: String { "invitations?page=\(page)" }
    var result: NativePage<NativeInvitation>? { store.cached(key, as: NativePage<NativeInvitation>.self) }
    var body: some View {
        List {
            ForEach(result?.items ?? []) { invitation in
                VStack(alignment: .leading, spacing: 12) {
                    Text(invitation.name).font(.headline)
                    HStack { Button("Accept") { decide(invitation, "accept") }.buttonStyle(.borderedProminent); Button("Decline", role: .destructive) { decide(invitation, "decline") } }.disabled(!store.online)
                }
            }
            HStack { if page > 1 { Button("Previous") { page -= 1 } }; Spacer(); if result?.nextPage != nil { Button("Next") { page += 1 } } }
        }.navigationTitle("Invitations").task(id: page) { await refresh() }
    }
    func refresh() async { await store.load(key, as: NativePage<NativeInvitation>.self) }
    func decide(_ invitation: NativeInvitation, _ decision: String) { Task {
        do { _ = try await store.request(NativeStore.api + "invitations/\(invitation.id)", method: "PATCH", body: ["decision": decision]); await refresh() }
        catch { store.error = error.localizedDescription }
    } }
}
struct NativeDeleteAccount: View {
    @EnvironmentObject var store: NativeStore
    @State private var password = ""
    @State private var confirmation = false
    var body: some View {
        Form {
            Text("Deleting your account removes your saved vocabulary, learning progress, and personal data. This cannot be undone.")
            SecureField("Confirm password", text: $password).textContentType(.password)
            Button("Delete my account", role: .destructive) { confirmation = true }.disabled(password.isEmpty || !store.online)
            Text("If you use social sign-in, set a password with the password recovery email before deleting your account.").font(.caption)
        }.navigationTitle("Delete account").confirmationDialog("Permanently delete your account?", isPresented: $confirmation) {
            Button("Delete account", role: .destructive) { Task {
                do { _ = try await store.request(NativeStore.api + "account", method: "DELETE", body: ["confirmation": "DELETE", "password": password]); try await store.clearLocalAccount() }
                catch { store.error = error.localizedDescription }
            } }
        }
    }
}

struct NativeEmailAction: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    let token: String
    let reset: Bool
    @State private var password = ""
    @State private var confirmation = ""
    @State private var message: String?
    @State private var complete = false
    var body: some View {
        NavigationStack {
            Form {
                if reset && !complete {
                    SecureField("New password", text: $password).textContentType(.newPassword)
                    SecureField("Confirm password", text: $confirmation).textContentType(.newPassword)
                }
                if let message { Text(message) }
                if complete { Button("Continue to sign in") { dismiss() } }
                else { Button(reset ? "Reset password" : "Confirm my email") { Task {
                    do {
                        _ = try await store.request(NativeStore.api + (reset ? "password" : "confirmation/verify"), method: reset ? "PATCH" : "POST", body: reset ? ["reset_password_token": token, "password": password, "password_confirmation": confirmation] : ["confirmation_token": token], authenticated: false)
                        complete = true; message = reset ? "Password updated. You can now sign in." : "Email confirmed. You can now sign in."
                    } catch { message = error.localizedDescription }
                } }.disabled(reset && (password.isEmpty || password != confirmation)) }
            }.navigationTitle(reset ? "Reset password" : "Confirm email").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
