# Hotwire Native Integration Guide

This document describes the process of integrating Hotwire Native into a Rails web application to create native iOS and Android wrapper apps. It covers the implementation approach, common challenges encountered, and solutions applied.

## Overview

Hotwire Native enables building native mobile apps that wrap your Rails web application. The native app loads your web content in a WebView while providing native UI controls and platform-specific features. From the Rails backend perspective, you detect Hotwire Native clients and serve optimized HTML/Turbo streams.

## Architecture

### High-Level Flow

1. **Native App** → Makes HTTP request with `Turbo Native` user agent
2. **Rails Backend** → Detects native client via user agent, serves optimized content
3. **WebView** → Renders HTML with Turbo integration
4. **Native Wrapper** → Provides platform controls (navigation, modals, etc.)

### Key Components

- **Rails Helper Methods**: Detect Hotwire Native clients
- **Android/iOS Wrapper Apps**: Built with Hotwire Native SDK
- **WebFragment/ViewControllers**: Handle navigation and error states
- **Offline Handling**: Custom error pages with auto-retry logic

## Android Implementation

### Setup

1. **Project Structure**
   ```
   app/mobile/android/Langlets/
   ├── app/
   │   ├── build.gradle.kts           # Dependencies and build config
   │   └── src/main/
   │       ├── AndroidManifest.xml    # Permissions and metadata
   │       ├── java/com/langlets/android/
   │       │   ├── MainActivity.kt         # Entry point, HotwireActivity
   │       │   ├── LangletsApplication.kt  # Hotwire configuration
   │       │   └── WebFragments.kt         # Custom error handling
   │       └── res/
   │           ├── layout/
   │           │   ├── activity_main.xml      # NavigatorHost container
   │           │   └── fragment_offline.xml   # Error/retry UI
   │           └── values/
   │               ├── strings.xml
   │               ├── colors.xml
   │               └── themes.xml
   ```

2. **Dependencies** (build.gradle.kts)
   ```kotlin
   dependencies {
       implementation("dev.hotwire:android:1.2.4")
       implementation("androidx.navigation:navigation-fragment-ktx:2.7.7")
       implementation("androidx.navigation:navigation-ui-ktx:2.7.7")
   }
   ```

3. **Permissions** (AndroidManifest.xml)
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
   <application android:hardwareAccelerated="true" />
   ```

### Key Files

#### MainActivity.kt

```kotlin
class MainActivity : HotwireActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
    }

    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(
            name = "main",
            startLocation = "https://your-domain.com",
            navigatorHostId = R.id.main_nav_host
        )
    )
}
```

**Key Points:**
- Extends `HotwireActivity` (provided by SDK)
- Sets `startLocation` to your Rails app URL
- Configures navigator with fragment container ID

#### WebFragments.kt

Extends `HotwireWebFragment` to provide custom error handling:

```kotlin
override fun createErrorView(error: VisitError): View {
    // Show custom offline UI with retry logic
    return layoutInflater.inflate(R.layout.fragment_offline, ...)
}

private fun reloadPage() {
    navigator.route(location)  // Use route() not refresh() or reload()
}
```

**Key Points:**
- Override `createErrorView()` to show custom error UI
- Implement auto-retry with escalating intervals (5s, 10s, 15s, 30s, 60s)
- Use `navigator.route(location)` to reload (not `navigator.refresh()`)

#### LangletsApplication.kt

```kotlin
class LangletsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Hotwire.config.jsonConverter = KotlinXJsonConverter()
        Hotwire.config.debugLoggingEnabled = true
        Hotwire.config.webViewDebuggingEnabled = true
        Hotwire.defaultFragmentDestination = WebFragment::class
        Hotwire.registerFragmentDestinations(WebFragment::class)
    }
}
```

### Problems & Solutions

#### Problem 1: Build Compilation Errors

**Symptom:** `Unresolved reference 'refresh'` or `Unresolved reference 'reload'`

**Root Cause:** The `navigator` object in Hotwire Native 1.2.4 doesn't have `refresh()` or `reload()` methods.

**Solution:** Use `navigator.route(location)` to reload the current page:
```kotlin
private fun reloadPage() {
    navigator.route(location)
}
```

#### Problem 2: Black Screen on Android Emulator

**Symptom:** App launches but WebView shows completely black screen. Chrome DevTools shows content is rendering correctly.

**Root Cause:** Android emulator's graphics state becomes corrupted after multiple builds/runs.

**Solution:** Cold boot the emulator:
1. Open Android Device Manager
2. Select the emulator
3. Click "Cold Boot Now"

**Alternative:** Set emulator graphics to "Software" mode in AVD settings.

**Prevention:** Enable hardware acceleration in AndroidManifest.xml:
```xml
<application android:hardwareAccelerated="true" />
```

#### Problem 3: Offline Error Page Not Displaying

**Symptom:** Custom offline error layout not shown when network is unavailable.

**Root Cause:** Error view creation wasn't properly integrated with Hotwire fragment lifecycle.

**Solution:** Override `createErrorView()` in WebFragment and ensure proper view inflation with parent ViewGroup.

### Build & Testing

#### Local Testing (Android Studio)

1. **Point to local Rails server:**
   - Edit `MainActivity.kt`:
     ```kotlin
     startLocation = "http://192.168.x.x:3000"  // Your local IP
     ```
   - Enable cleartext traffic in AndroidManifest.xml:
     ```xml
     <application android:usesCleartextTraffic="true" />
     ```

2. **Run emulator:**
   - Android Studio → Run → Select device

3. **Debug with Chrome DevTools:**
   - Open `chrome://inspect/#devices` in Chrome
   - Inspect WebView content in real-time

#### Building APK for Physical Device

1. **Update startLocation to production URL:**
   ```kotlin
   startLocation = "https://langlets.app"
   ```

2. **Build APK:**
   - Android Studio → Build → Build Bundle(s)/APK(s) → Build APK
   - Generated APK: `app/mobile/android/Langlets/app/build/outputs/apk/debug/app-debug.apk`

3. **Install on device:**
   ```bash
   adb install app/build/outputs/apk/debug/app-debug.apk
   ```

4. **Test:**
   - Launch app on physical device
   - Verify navigation works
   - Test offline handling (toggle airplane mode)

### Testing Checklist

- [ ] Local emulator with local Rails server
- [ ] Local emulator with production URL
- [ ] Physical device with production URL
- [ ] Network error handling (offline page displays)
- [ ] Retry logic works (auto and manual)
- [ ] Navigation between pages works
- [ ] Forms submit correctly

## iOS Implementation

### Setup

1. **Project Structure** (To be implemented)
   ```
   app/mobile/ios/Langlets/
   ├── Langlets.xcodeproj
   ├── Langlets/
   │   ├── AppDelegate.swift
   │   ├── SceneDelegate.swift
   │   ├── WebViewController.swift
   │   └── Assets.xcassets
   └── Langlets.xcworkspace  (when CocoaPods added)
   ```

2. **Dependencies**
   - Hotwire Native for iOS (via CocoaPods or Swift Package Manager)
   - Version compatibility to match Android implementation

### Key Differences from Android

- **Navigation:** Use `UIViewController` and `UINavigationController` instead of fragments
- **Error Handling:** Implement custom `WKWebViewDelegate` methods
- **Configuration:** Use `AppDelegate.swift` for Hotwire setup
- **Offline UI:** Use `UIView` with XIB or Storyboard

### Implementation Plan

1. Create iOS project with Hotwire Native
2. Implement custom `WebViewController` with error handling
3. Add offline error page UI
4. Implement retry logic with same intervals as Android
5. Configure start location
6. Test with local and production servers
7. Build and test on physical device

### Testing Checklist (iOS)

- [ ] Xcode build succeeds
- [ ] App launches on simulator
- [ ] App loads Rails content in WebView
- [ ] Network error handling works
- [ ] Auto-retry works
- [ ] Navigation works
- [ ] Physical device testing

## Rails Backend Integration

### Helper Methods

```ruby
# app/helpers/application_helper.rb
def turbo_native_app?
  request.user_agent.to_s.match?(/Turbo Native/i)
end

def turbo_native_ios?
  request.user_agent.to_s.match?(/Turbo Native.*iOS/i)
end

def turbo_native_android?
  request.user_agent.to_s.match?(/Turbo Native.*Android/i)
end
```

### Usage in Controllers

```ruby
class LessonsController < ApplicationController
  def show
    respond_to do |format|
      format.turbo_stream if turbo_native_app?
      format.html
    end
  end
end
```

### Usage in Views

```erb
<% if turbo_native_app? %>
  <!-- Optimized for native app -->
<% else %>
  <!-- Web-only features -->
<% end %>
```

## Testing Environment

### Recommended Setup

1. **Local Development:**
   - Rails server on `localhost:3000`
   - Android emulator configured to access local IP (e.g., `192.168.1.100:3000`)
   - Test with both HTTP (cleartext) and HTTPS

2. **Production Testing:**
   - Build APK/IPA with production URL
   - Install on physical devices
   - Test with real network conditions

3. **Continuous Testing:**
   - Set up staging environment separate from production
   - Test each release candidate on physical devices before production deployment

### CI/CD Considerations

- Add Android APK build to CI pipeline
- Add iOS IPA build to CI pipeline
- Run UI tests on cloud-based device farms
- Test both native and web versions in CI

## Common Pitfalls

1. **Forgetting user agent detection** → App behaves differently than expected
   - Solution: Always use helper methods to detect native clients

2. **Hardcoding localhost in production APK** → App won't work for users
   - Solution: Use build variants or environment variables

3. **Not testing on physical devices** → Miss platform-specific issues
   - Solution: Test on real devices early and often

4. **Emulator graphics corruption** → Wasted time debugging non-existent code bugs
   - Solution: Cold boot emulator when graphics seem corrupted

5. **Ignoring offline scenarios** → App breaks when user is offline
   - Solution: Implement proper error handling and retry logic

## Deployment Checklist

Before releasing to app stores:

- [ ] APK/IPA builds successfully
- [ ] Tested on Android 8+ / iOS 12+
- [ ] All navigation paths tested
- [ ] Form submissions working
- [ ] Offline error handling verified
- [ ] Deep linking tested (if applicable)
- [ ] Backend detects native clients correctly
- [ ] No console errors in Chrome DevTools
- [ ] Touch interactions work smoothly
- [ ] Performance acceptable on older devices

## Resources

- [Hotwire Native Documentation](https://github.com/hotwired/hotwire-native)
- [Hotwire Native Android](https://github.com/hotwired/hotwire-native-android)
- [Hotwire Native iOS](https://github.com/hotwired/hotwire-native-ios)
- [Android WebView Documentation](https://developer.android.com/reference/android/webkit/WebView)
- [iOS WKWebView Documentation](https://developer.apple.com/documentation/webkit/wkwebview)

## Future Improvements

1. **Push Notifications:** Integrate FCM (Android) and APNs (iOS)
2. **Deep Linking:** Implement URI schemes for better navigation
3. **Custom Fonts:** Add webfont caching for offline availability
4. **Analytics:** Track native vs web user behavior
5. **A/B Testing:** Run experiments differently on native apps
6. **Performance Optimization:** Implement caching strategies
7. **Native Modules:** Use platform-specific features (camera, location, etc.)
