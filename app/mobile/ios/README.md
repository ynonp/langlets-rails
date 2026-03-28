# Langlets iOS App

## Status
**Blocked** - Requires Mac with Xcode for development.

## Overview
Native iOS wrapper for Langlets using Hotwire Turbo Native (turbo-ios).

## Requirements
- macOS with Xcode 15+
- Swift 5.9+
- iOS 15.0+ deployment target
- Apple Developer account (for device testing)

## Dependencies
Add via Swift Package Manager (SPM):
```
https://github.com/hotwired/turbo-ios
```

## Planned Project Structure
```
Langlets/
├── Langlets.xcodeproj
├── Langlets/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── MainViewController.swift
│   ├── Info.plist
│   └── Assets.xcassets/
└── LangletsTests/
```

## Key Implementation Files

### AppDelegate.swift
```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
}
```

### SceneDelegate.swift
```swift
import UIKit
import Turbo

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private lazy var navigationController = UINavigationController()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        let session = Session(webView: WKWebView())
        session.delegate = self

        let url = URL(string: "http://localhost:3000")!
        let visit = session.visit(url)
    }
}
```

### MainViewController.swift
```swift
import UIKit
import Turbo
import WebKit

class MainViewController: VisitableViewController {
    private static let baseURL = URL(string: "http://localhost:3000")!
    private static let pathConfigurationURL = URL(string: "http://localhost:3000/hotwire_native/path-configuration")!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure WebView
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "Turbo Native iOS"

        // Configure path configuration
        let pathConfiguration = PathConfiguration(sources: [
            .server(pathConfigurationURL)
        ])
    }
}
```

## Configuration

### User Agent
Set to include `Turbo Native iOS` for Rails detection:
```swift
config.applicationNameForUserAgent = "Turbo Native iOS"
```

### Base URL
- Development: `http://localhost:3000`
- Production: `https://langlets.app` (future)

### Session Persistence
iOS handles cookies automatically via `WKWebsiteDataStore.default()`.
Devise remember_me cookies (1 year) will persist across sessions.

## Setup Instructions

1. **Create Xcode Project**
   - Open Xcode → New Project → iOS App
   - Product Name: Langlets
   - Bundle ID: com.langlets.ios
   - Language: Swift
   - Interface: Storyboard

2. **Add Turbo iOS Package**
   - File → Add Package Dependencies
   - Enter: `https://github.com/hotwired/turbo-ios`
   - Add to target: Langlets

3. **Configure Info.plist**
   - Add `NSAppTransportSecurity` for development HTTP
   - Set `UIApplicationSceneManifest` for scene delegate

4. **Build & Run**
   - Select iOS Simulator or device
   - Build (Cmd+B)
   - Run (Cmd+R)

## Testing Checklist
- [ ] App launches successfully
- [ ] Login page loads
- [ ] Session persists after backgrounding
- [ ] Navigation works correctly
- [ ] User agent detected by Rails

## Notes
- iOS implementation will mirror Android functionality
- Same path configuration endpoint used
- Same session handling strategy via cookies
