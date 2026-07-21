import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let sourceButton = UIButton(type: .system)
    private let translationButton = UIButton(type: .system)
    private let importButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    private var sharedURL: URL?
    private let clientToken = UUID().uuidString
    private var languages = ShareStore.languages
    private var sourceLanguage: ShareStore.Language!
    private var translationLanguage: ShareStore.Language!

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDefaults()
        buildUI()
        loadSharedURL()
    }

    private func configureDefaults() {
        let selectedISO = ShareStore.defaults?.string(forKey: "selectedLanguage")
        sourceLanguage = languages.first { $0.isoName == selectedISO }
            ?? languages.first { $0.englishName == "Spanish" }
            ?? languages[0]
        translationLanguage = languages.first { $0.englishName == "English" } ?? languages[0]
    }

    private func buildUI() {
        view.backgroundColor = UIColor(red: 10 / 255, green: 21 / 255, blue: 33 / 255, alpha: 1)

        titleLabel.text = "Create a Langlets course"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .white

        urlLabel.text = "Reading shared YouTube link…"
        urlLabel.font = .preferredFont(forTextStyle: .footnote)
        urlLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        urlLabel.numberOfLines = 2

        configureLanguageButton(sourceButton, title: "Video language")
        configureLanguageButton(translationButton, title: "Translate to")
        refreshLanguageMenus()

        importButton.setTitle("Import · 1 credit", for: .normal)
        importButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        importButton.backgroundColor = UIColor(red: 65 / 255, green: 224 / 255, blue: 178 / 255, alpha: 1)
        importButton.setTitleColor(UIColor(red: 8 / 255, green: 29 / 255, blue: 32 / 255, alpha: 1), for: .normal)
        importButton.layer.cornerRadius = 24
        importButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        importButton.isEnabled = false
        importButton.addTarget(self, action: #selector(submit), for: .touchUpInside)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, urlLabel, sourceButton, translationButton,
            importButton, statusLabel, cancelButton
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

    private func configureLanguageButton(_ button: UIButton, title: String) {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = UIColor.white.withAlphaComponent(0.08)
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        configuration.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        configuration.titleAlignment = .leading
        button.configuration = configuration
        button.accessibilityLabel = title
        button.showsMenuAsPrimaryAction = true
    }

    private func refreshLanguageMenus() {
        sourceButton.setTitle("Video language:  \(sourceLanguage.englishName)", for: .normal)
        translationButton.setTitle("Translate to:  \(translationLanguage.englishName)", for: .normal)
        sourceButton.menu = languageMenu(selected: sourceLanguage) { [weak self] language in
            self?.sourceLanguage = language
            self?.refreshLanguageMenus()
        }
        translationButton.menu = languageMenu(selected: translationLanguage) { [weak self] language in
            self?.translationLanguage = language
            self?.refreshLanguageMenus()
        }
    }

    private func languageMenu(selected: ShareStore.Language, selection: @escaping (ShareStore.Language) -> Void) -> UIMenu {
        UIMenu(children: languages.map { language in
            UIAction(title: language.englishName,
                     state: language == selected ? .on : .off) { _ in selection(language) }
        })
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
        guard let url, Self.isYouTube(url) else {
            urlLabel.text = "Share a YouTube video link to create a course."
            statusLabel.text = "No YouTube link was found."
            return
        }
        sharedURL = url
        urlLabel.text = url.absoluteString
        importButton.isEnabled = true
    }

    private static func isYouTube(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")
    }

    @objc private func submit() {
        guard let sharedURL else { return }
        guard let token = ShareStore.accessToken else {
            statusLabel.text = "Open Langlets and sign in before sharing a video."
            return
        }

        importButton.isEnabled = false
        statusLabel.text = "Adding to your Queue…"
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
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "url": sharedURL.absoluteString,
            "clip_language": sourceLanguage.englishName,
            "translation_language": translationLanguage.englishName,
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
            statusLabel.text = "Couldn’t connect: \(error.localizedDescription)"
            importButton.isEnabled = true
        } else if status == 200 || status == 201 {
            statusLabel.text = body?["status"] as? String == "ready"
                ? "Already in your Library — no credit used."
                : "Added to your Queue. We’ll notify you when it’s ready."
            importButton.isHidden = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        } else {
            let description = body?["error_description"] as? String
            switch status {
            case 401: statusLabel.text = "Open Langlets and sign in again."
            case 402: statusLabel.text = "You’re out of credits."
            case 422: statusLabel.text = description ?? "That video can’t be imported."
            default: statusLabel.text = description ?? "Something went wrong. Please try again."
            }
            importButton.isEnabled = true
        }
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}
