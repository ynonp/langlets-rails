# Task Breakdown: Hotwire Native Integration

## Overview
Total Tasks: 18

## Task List

### Rails Backend

#### Task Group 1: Path Configuration Endpoint
**Dependencies:** None

- [x] 1.0 Complete path configuration endpoint
  - [x] 1.1 Write 3 focused tests for path configuration
    - Test endpoint returns valid JSON
    - Test response includes settings and rules keys
    - Test CSRF is skipped for the endpoint
  - [x] 1.2 Create `HotwireNative::ConfigurationsController`
    - Create directory: `app/controllers/hotwire_native/`
    - Action: `show`
    - Skip CSRF with `skip_before_action :verify_authenticity_token`
    - Return JSON: `{ settings: {}, rules: [{ patterns: ["/.*"], properties: { context: "default" } }] }`
  - [x] 1.3 Add route to `config/routes.rb`
    - Namespace: `hotwire_native`
    - Route: `get 'path-configuration', to: 'configurations#show'`
  - [x] 1.4 Ensure endpoint tests pass
    - Run ONLY the 3 tests written in 1.1
    - Verify endpoint accessible at `/hotwire-native/path-configuration`

**Acceptance Criteria:**
- Endpoint returns valid JSON at `/hotwire-native/path-configuration`
- CSRF verification is skipped
- Response matches expected structure

#### Task Group 2: User-Agent Detection Helpers
**Dependencies:** None (can run parallel with Task Group 1)

- [x] 2.0 Complete user-agent detection helpers
  - [x] 2.1 Write 4 focused tests for detection helpers
    - Test `turbo_native_app?` returns true for "Turbo Native" user agent
    - Test `turbo_native_ios?` returns true for "Turbo Native iOS" user agent
    - Test `turbo_native_android?` returns true for "Turbo Native Android" user agent
    - Test helpers return false for regular browser user agents
  - [x] 2.2 Add helpers to `app/helpers/application_helper.rb`
    - `turbo_native_app?` - matches `/Turbo Native/i`
    - `turbo_native_ios?` - matches `/Turbo Native.*iOS/i`
    - `turbo_native_android?` - matches `/Turbo Native.*Android/i`
  - [x] 2.3 Ensure helper tests pass
    - Run ONLY the 4 tests written in 2.1

**Acceptance Criteria:**
- All 3 helper methods work correctly
- Detection is case-insensitive
- Helpers available in all views

#### Task Group 3: Layout and Styling
**Dependencies:** Task Group 2

- [x] 3.0 Complete layout modifications and native styles
  - [x] 3.1 Write 3 focused tests for layout behavior
    - Test body has `turbo-native` class when native user agent
    - Test PWA meta tags hidden when native user agent
    - Test normal browser requests unchanged
  - [x] 3.2 Modify `app/views/layouts/application.html.erb`
    - Add conditional `turbo-native` class to body element
    - Wrap PWA meta tags in `unless turbo_native_app?` conditional
  - [x] 3.3 Add styles to `app/assets/stylesheets/application.tailwind.css`
    - Add `.turbo-native` selector
    - Hide any PWA install prompts/banners
  - [x] 3.4 Ensure layout tests pass
    - Run ONLY the 3 tests written in 3.1

**Acceptance Criteria:**
- Body has correct class based on user agent
- PWA elements hidden for native apps
- Normal web experience unchanged

### Android App

#### Task Group 4: Android Project Setup
**Dependencies:** Task Groups 1-3 (Rails backend complete)

- [x] 4.0 Complete Android project structure
  - [x] 4.1 Create project directory structure
    - `app/mobile/android/src/main/java/com/langlets/android/`
    - `app/mobile/android/src/main/res/layout/`
    - `app/mobile/android/src/main/res/values/`
  - [x] 4.2 Create `build.gradle.kts`
    - Add Turbo dependency: `dev.hotwire:turbo:7.1.0`
    - Set minSdk: 26, targetSdk: 34
    - Add Kotlin and navigation dependencies
  - [x] 4.3 Create `AndroidManifest.xml`
    - Add INTERNET permission
    - Set `android:usesCleartextTraffic="true"` for dev HTTP
    - Configure main activity
  - [x] 4.4 Create `MainActivity.kt`
    - Extend TurboActivity
    - Set base URL: `http://10.0.2.2:3000`
    - Set user agent: "Turbo Native Android"
  - [x] 4.5 Create `MainSessionNavHostFragment.kt`
    - Extend TurboWebViewFragment
    - Enable JavaScript, DOM storage
    - Configure CookieManager for session persistence
  - [x] 4.6 Create `activity_main.xml`
    - FrameLayout with FragmentContainerView
    - Full-screen WebView container

**Acceptance Criteria:**
- Project compiles in Android Studio
- Gradle sync succeeds
- All required files in place

### Documentation

#### Task Group 5: iOS Documentation
**Dependencies:** None

- [x] 5.0 Document iOS structure for future implementation
  - [x] 5.1 Create `app/mobile/ios/README.md`
    - Document planned project structure
    - List dependencies (turbo-ios via SPM)
    - Note Mac requirement
    - Provide setup instructions for future

**Acceptance Criteria:**
- iOS structure documented
- Clear instructions for future implementation

### Integration Testing

#### Task Group 6: End-to-End Validation
**Dependencies:** Task Groups 1-4

- [ ] 6.0 Validate complete integration
  - [ ] 6.1 Manual test: Rails server responds to path configuration
    - Start Rails server
    - Curl `/hotwire-native/path-configuration`
    - Verify JSON response
  - [ ] 6.2 Manual test: Android emulator loads app
    - Start Android emulator (Pixel 7, API 34)
    - Build and run Android app
    - Verify Langlets loads in WebView
  - [ ] 6.3 Manual test: Session persistence
    - Log in via Android app
    - Background the app
    - Return to app
    - Verify still logged in
  - [ ] 6.4 Manual test: User agent detection
    - Check Rails logs for "Turbo Native Android" user agent
    - Verify body has `turbo-native` class in Android app

**Acceptance Criteria:**
- Android app loads Langlets successfully
- Login session persists across app lifecycle
- User agent correctly detected by Rails

## Execution Order

Recommended implementation sequence:
1. Task Group 1: Path Configuration Endpoint ✅
2. Task Group 2: User-Agent Detection Helpers ✅
3. Task Group 3: Layout and Styling ✅
4. Task Group 4: Android Project Setup ✅
5. Task Group 5: iOS Documentation ✅
6. Task Group 6: End-to-End Validation (Manual - requires running app)
