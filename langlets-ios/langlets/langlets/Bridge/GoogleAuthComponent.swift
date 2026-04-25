//
//  GoogleAuthComponent.swift
//  langlets
//
//  Created by Ynon Perek on 25/04/2026.
//


import HotwireNative
import GoogleSignIn

final class GoogleAuthComponent: BridgeComponent {
    nonisolated override class var name: String { "google-auth" }

    override func onReceive(message: Message) {
        print("[GoogleAuthComponent] Received message: \(message.event)")

        guard let event = Event(rawValue: message.event) else {
            print("[GoogleAuthComponent] Unknown event, ignoring")
            return
        }

        switch event {
        case .authorize:
            print("[GoogleAuthComponent] Handling authorize event")
            handleAuthorizeEvent(message: message)
        }
    }

    // MARK: Private

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
   }


    private func handleAuthorizeEvent(message: Message) {
        guard let viewController = viewController else {
            print("[GoogleAuthComponent] Missing view controller")
            reply(with: message.replacing(data: AuthorizeMessageData(code: nil, error: "Missing view controller")))
            return
        }

        print("[GoogleAuthComponent] Starting GIDSignIn...")
        GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController
        ) { [weak self] signInResult, error in
            if let error = error {
                print("[GoogleAuthComponent] Sign-in error: \(error.localizedDescription)")
                self?.reply(with: message.replacing(data: AuthorizeMessageData(code: nil, error: error.localizedDescription)))
                return
            }

            guard let serverAuthCode = signInResult?.serverAuthCode else {
                print("[GoogleAuthComponent] No serverAuthCode in sign-in result")
                self?.reply(with: message.replacing(data: AuthorizeMessageData(code: nil, error: "Missing server auth code")))
                return
            }

            print("[GoogleAuthComponent] Got serverAuthCode, sending reply")
            self?.reply(with: message.replacing(data: AuthorizeMessageData(code: serverAuthCode, error: nil)))
        }
    }

}

// MARK: Events

private extension GoogleAuthComponent {
    enum Event: String {
        case authorize
    }

    struct AuthorizeMessageData: Encodable {
        let code: String?
        let error: String?
    }
}
