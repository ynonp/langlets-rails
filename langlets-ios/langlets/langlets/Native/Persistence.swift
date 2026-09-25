import Foundation
import Security
import CryptoKit

struct NativeFailure: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}
enum NativeKeychain {
    private static let account = "native-session-v1"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.ynonp.langlets.native",
         kSecAttrAccount as String: account]
    }
    static func read() -> NativeSession? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder.native.decode(NativeSession.self, from: data)
    }
    static func write(_ session: NativeSession) throws {
        let data = try JSONEncoder.native.encode(session)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var q = query
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw NativeFailure(status: 0, message: "Could not securely save sign-in") }
        } else if status != errSecSuccess { throw NativeFailure(status: 0, message: "Could not securely save sign-in") }
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
}

actor NativeDisk {
    private func directory(_ account: Int) throws -> URL {
        var url = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Native-v1/\(account)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        return url
    }
    func read(_ account: Int) throws -> NativeSnapshot {
        let path = try directory(account).appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: path.path) else { return NativeSnapshot() }
        let snapshot = try JSONDecoder.native.decode(NativeSnapshot.self, from: Data(contentsOf: path))
        guard snapshot.version == 1 else { throw NativeFailure(status: 0, message: "This download format needs an app update") }
        return snapshot
    }
    func save(_ state: NativeSnapshot, account: Int) throws {
        let data = try JSONEncoder.native.encode(state)
        try data.write(to: directory(account).appendingPathComponent("state.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func clear(_ account: Int) throws { try FileManager.default.removeItem(at: directory(account)) }
    func pruneAudio(keeping ids: Set<Int>, account: Int) throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory(account), includingPropertiesForKeys: nil)
        for file in files where file.lastPathComponent.hasPrefix("audio-") {
            let id = Int(file.deletingPathExtension().lastPathComponent.dropFirst(6))
            if id == nil || !ids.contains(id!) { try FileManager.default.removeItem(at: file) }
        }
    }
    func audioURL(_ audio: NativeAudio, account: Int) throws -> URL {
        try directory(account).appendingPathComponent("audio-\(audio.id).wav")
    }
    func downloadAudio(_ audio: NativeAudio, account: Int) async throws {
        let path = try audioURL(audio, account: account)
        if FileManager.default.fileExists(atPath: path.path) { return }
        guard let url = URL(string: audio.url), url.scheme == "https" || url.host == "devbox" else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count == audio.byteSize,
              Data(Insecure.MD5.hash(data: data)).base64EncodedString() == audio.checksum else { throw URLError(.cannotDecodeContentData) }
        try Task.checkCancellation()
        try data.write(to: path, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
