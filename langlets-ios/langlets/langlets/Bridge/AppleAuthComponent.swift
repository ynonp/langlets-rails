//
//  AppleAuthComponent.swift
//  langlets
//

import HotwireNative
import AuthenticationServices

/// Runs the native Sign in with Apple flow (AuthenticationServices) when the
/// web login page's Apple button is tapped inside the app, then replies to the
/// web bridge with the identity token so it can be POSTed to the backend.
///
/// Requires the "Sign in with Apple" capability on the app target.
final class AppleAuthComponent: BridgeComponent {
    nonisolated override class var name: String { "apple-auth" }

    // Kept alive for the duration of the authorization flow.
    private var signInCoordinator: AppleSignInCoordinator?

    override func onReceive(message: Message) {
        print("[AppleAuthComponent] Received message: \(message.event)")

        guard let event = Event(rawValue: message.event) else {
            print("[AppleAuthComponent] Unknown event, ignoring")
            return
        }

        switch event {
        case .authorize:
            handleAuthorizeEvent(message: message)
        }
    }

    // MARK: Private

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }

    private func handleAuthorizeEvent(message: Message) {
        guard let window = viewController?.view.window else {
            print("[AppleAuthComponent] Missing window for presentation")
            reply(with: message.replacing(data: AuthorizeMessageData(identityToken: nil, name: nil, error: "Missing view controller")))
            return
        }

        let coordinator = AppleSignInCoordinator(anchor: window) { [weak self] result in
            switch result {
            case .success(let credential):
                guard let tokenData = credential.identityToken,
                      let identityToken = String(data: tokenData, encoding: .utf8) else {
                    print("[AppleAuthComponent] No identity token in credential")
                    self?.reply(with: message.replacing(data: AuthorizeMessageData(identityToken: nil, name: nil, error: "Missing identity token")))
                    return
                }

                // Apple only provides the name on the very first authorization.
                var name: String?
                if let fullName = credential.fullName {
                    let formatted = PersonNameComponentsFormatter().string(from: fullName)
                    name = formatted.isEmpty ? nil : formatted
                }

                print("[AppleAuthComponent] Got identity token, sending reply")
                self?.reply(with: message.replacing(data: AuthorizeMessageData(identityToken: identityToken, name: name, error: nil)))

            case .failure(let error):
                // Canceling the sheet is not an error worth alerting about.
                // Cancellation surfaces as .canceled, but also as .unknown when
                // the sheet is dismissed before Face ID or without an iCloud
                // account — replying here would make the web page show an error
                // mid-dismissal.
                if let authError = error as? ASAuthorizationError,
                   authError.code == .canceled || authError.code == .unknown {
                    print("[AppleAuthComponent] Sign-in canceled by user (code \(authError.code.rawValue))")
                    return
                }
                print("[AppleAuthComponent] Sign-in error: \(error.localizedDescription)")
                self?.reply(with: message.replacing(data: AuthorizeMessageData(identityToken: nil, name: nil, error: error.localizedDescription)))
            }
            self?.signInCoordinator = nil
        }

        signInCoordinator = coordinator
        coordinator.start()
    }
}

// MARK: Events

private extension AppleAuthComponent {
    enum Event: String {
        case authorize
    }

    struct AuthorizeMessageData: Encodable {
        let identityToken: String?
        let name: String?
        let error: String?
    }
}

// MARK: - AppleSignInCoordinator

/// Owns the ASAuthorizationController delegate callbacks for a single
/// Sign in with Apple attempt.
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void

    init(anchor: ASPresentationAnchor, completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.anchor = anchor
        self.completion = completion
    }

    func start() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(ASAuthorizationError(.invalidResponse)))
            return
        }
        completion(.success(credential))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor
    }
}
