import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    private var sharedURL: URL?
    private let clientToken = UUID().uuidString

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadSharedURL()
    }

    private func buildUI() {
        view.backgroundColor = UIColor(red: 10 / 255, green: 21 / 255, blue: 33 / 255, alpha: 1)

        titleLabel.text = localizedAppString("Create a Langlets course", comment: "Share status")
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .white

        urlLabel.text = localizedAppString("Reading shared video link…", comment: "Share status")
        urlLabel.font = .preferredFont(forTextStyle: .footnote)
        urlLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        urlLabel.numberOfLines = 2

        cancelButton.setTitle(localizedAppString("Cancel", comment: "Share status"), for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, urlLabel, statusLabel, cancelButton
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -22),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }

    private func loadSharedURL() {
        let providers = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                let url = item as? URL ?? (item as? String).flatMap(URL.init(string:))
                DispatchQueue.main.async { self?.accept(url: url) }
            }
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                let url = (item as? String).flatMap(Self.firstURL(in:))
                DispatchQueue.main.async { self?.accept(url: url) }
            }
        } else {
            accept(url: nil)
        }
    }

    nonisolated private static func firstURL(in text: String) -> URL? {
        let range = NSRange(text.startIndex..., in: text)
        return try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            .firstMatch(in: text, range: range)?.url
    }

    private func accept(url: URL?) {
        guard let url, Self.isSupportedVideo(url) else {
            urlLabel.text = localizedAppString("Share a YouTube or TikTok video link to create a course.", comment: "Share status")
            statusLabel.text = localizedAppString("No video link was found.", comment: "Share status")
            return
        }
        sharedURL = url
        urlLabel.text = url.absoluteString
        statusLabel.text = localizedAppString("Adding to your Queue…", comment: "Share status")
        submit()
    }

    // Host-only, deliberately: the extension decides "is this worth POSTing",
    // not "which video is this". Rails re-validates and canonicalizes, and for
    // TikTok it is the only thing that *can* — a vt.tiktok.com share link
    // carries a redirect token rather than a post id, and only TikTok's oEmbed
    // resolves one. Parsing an id here would fail every link TikTok's own share
    // sheet produces.
    private static func isSupportedVideo(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return Self.supportedHosts.contains(host) ||
            Self.supportedDomains.contains(where: { host.hasSuffix(".\($0)") })
    }

    private static let supportedHosts: Set<String> = ["youtu.be", "youtube.com", "tiktok.com"]
    // Covers www., m., vt. and vm. subdomains without listing each one.
    private static let supportedDomains: Set<String> = ["youtube.com", "tiktok.com"]

    private func submit() {
        guard let sharedURL else { return }
        guard let token = ShareStore.accessToken else {
            statusLabel.text = localizedAppString("Open Langlets and sign in before sharing a video.", comment: "Share status")
            return
        }

        statusLabel.text = localizedAppString("Adding to your Queue…", comment: "Share status")
        // Same split as the host app's rootURL — a debug extension posting to
        // production would file real imports against a real account while you
        // think you're testing locally. This target can't see SceneDelegate's
        // constant, so the switch is repeated rather than shared.
        let importsEndpoint = URL(string: "https://langlets.app/api/v1/import_requests")!
        var request = URLRequest(url: importsEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // The endpoint only queues the import — it does no pipeline work — so a
        // response takes well under a second and the sheet can afford to wait
        // for it. The short timeout is what keeps that promise honest: this
        // sheet's only control is Cancel, so a stalled network has to become a
        // sentence rather than a spinner the user sits through. `client_token`
        // makes the retry it invites free.
        request.timeoutInterval = 8
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "url": sharedURL.absoluteString,
            "client_token": clientToken
        ])

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async { self?.handleResponse(data: data, response: response, error: error) }
        }.resume()
    }

    private func handleResponse(data: Data?, response: URLResponse?, error: Error?) {
        let status = (response as? HTTPURLResponse)?.statusCode
        let body = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }

        if let error {
            statusLabel.text = String(format: localizedAppString("Couldn’t connect: %@", comment: "Connection error"), error.localizedDescription)
        } else if status == 200 || status == 201 {
            // "ready" now only comes back when a client_token replay finds a
            // finished request: the first POST answers before the language is
            // known, so it can't yet tell that the course was already yours.
            statusLabel.text = body?["status"] as? String == "ready"
                ? localizedAppString("Already in your Library — no credit used.", comment: "Share status")
                : localizedAppString("Added to your Queue. We’ll notify you when it’s ready.", comment: "Share status")
            extensionContext?.completeRequest(returningItems: nil)
        } else {
            let description = body?["error_description"] as? String
            switch status {
            case 401: statusLabel.text = localizedAppString("Open Langlets and sign in again.", comment: "Share status")
            // Both 402 shapes — an empty balance and a paused Pro library — carry a
            // sentence naming the way forward, and credits cannot be topped up,
            // so prefer the server's copy over anything hardcoded here.
            case 402: statusLabel.text = description ?? localizedAppString("You’re out of free imports.", comment: "Share status")
            case 422: statusLabel.text = description ?? localizedAppString("That video can’t be imported.", comment: "Share status")
            default: statusLabel.text = description ?? localizedAppString("Something went wrong. Please try again.", comment: "Share status")
            }
        }
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}
