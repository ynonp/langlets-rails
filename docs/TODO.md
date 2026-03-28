# TODO

## Code Review Recommendations (Merge Checklist)

- [ ] **Database Config**: Revert hardcoded `username`, `password`, and `host` in `config/database.yml`. Use environment variables instead.
- [ ] **Android Development URL**: Update `MainActivity.kt` to use `http://10.0.2.2:3000` for local development.
- [ ] **Path Configuration**: Wire up the path configuration endpoint in `MainActivity.kt` (using `pathConfigurationSetting`) so the app consumes server-side rules.
- [ ] **UI Verification**: Manually verify that the `.turbo-native` CSS class correctly hides PWA-specific elements (install prompts, banners) when viewed in the Android app.


## Environment Setup

- [ ] Set PostgreSQL credentials in environment variables:
  ```
  POSTGRES_USERNAME=postgres
  POSTGRES_PASSWORD=postgres
  ```

- [ ] Or update `config/database.yml` to use env variables:
  ```yaml
  username: <%= ENV.fetch("POSTGRES_USERNAME", "postgres") %>
  password: <%= ENV.fetch("POSTGRES_PASSWORD", "postgres") %>
  ```

## Hotwire Native Testing

- [ ] Test path configuration endpoint: `curl http://localhost:3000/hotwire_native/path-configuration`
- [ ] Run Rails tests: `bin/rails test test/controllers/hotwire_native/`
- [ ] Open Android project in Android Studio and build
- [ ] Test Android app on emulator

---

## Hotwire Native Implementation - High Priority

### Environment-Based startLocation Configuration
**Description:** Make the Android app's `startLocation` configurable via environment variables instead of hardcoding it in code.

**Why:**
- Allows testing against local development server without rebuilding APK
- Supports staging server testing
- Enables easy switching between multiple servers running simultaneously
- Reduces need for multiple APK builds for different environments

**Implementation Options:**
1. **Build Variants Approach** (Recommended)
   - Create `debug`, `staging`, `release` build variants
   - Each variant has its own `startLocation` in `build.gradle.kts`
   - Example:
     ```kotlin
     buildTypes {
         debug {
             buildConfigField("String", "START_LOCATION", "\"http://192.168.1.100:3000\"")
         }
         release {
             buildConfigField("String", "START_LOCATION", "\"https://langlets.app\"")
         }
     }
     ```
   - Then use: `startLocation = BuildConfig.START_LOCATION`

2. **SharedPreferences Approach** (Most Flexible)
   - Store URL in SharedPreferences on first launch
   - Provide settings screen to change URL without rebuild
   - Good for rapid testing across multiple servers

3. **Environment Variables at Runtime**
   - Read from Android system environment variables
   - Less common but possible

**Current Code:**
```kotlin
// MainActivity.kt line 16
startLocation = "https://langlets.app"  // Hardcoded!
```

**Effort:** 1-2 hours

**Priority:** Medium (nice to have for development, required before multi-environment deployment)

---

## Medium Priority

### Disable Debug Flags for Production
**Description:** Currently `debugLoggingEnabled` and `webViewDebuggingEnabled` are always true.

**Impact:** Performance overhead in production, security concerns with debug logging.

**Fix:**
```kotlin
// LangletsApplication.kt
Hotwire.config.debugLoggingEnabled = BuildConfig.DEBUG
Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG
```

**Effort:** 15 minutes

---

### Enable Code Minification for Release
**Description:** ProGuard/R8 is currently disabled. Should be enabled for release builds to reduce APK size.

**Current:**
```kotlin
isMinifyEnabled = false
```

**Change to:**
```kotlin
isMinifyEnabled = true
```

**Effort:** 15 minutes (+ testing time to ensure no issues)

---

## Low Priority (Future Enhancement)

### iOS Implementation
- Create iOS wrapper app with Hotwire Native
- Implement same offline error handling and retry logic
- Apply same environment configuration approach

**Effort:** 8-10 hours

---

### Add Max Retry Limit
**Description:** Currently retries indefinitely on 60-second intervals.

**Consideration:** Might want to stop retrying after N attempts to avoid wasting battery/data.

**Not critical for:** Initial MVP

---

### Settings Screen for URL Configuration
**Description:** Allow users to change the server URL from within the app settings.

**Use Case:** QA testing different environments without rebuilding APK.

**Effort:** 2-3 hours

**Priority:** Post-launch feature

---

## Testing Checklist

- [ ] Test with local Rails server (http://192.168.1.x:3000)
- [ ] Test with staging server
- [ ] Test with production server (https://langlets.app)
- [ ] Test offline error handling on each server
- [ ] Test navigation between pages on each server
- [ ] Physical device testing with production URL
- [ ] Test with airplane mode enabled
- [ ] Test with WiFi on/off

---

## Deployment Checklist

Before pushing to Play Store:
- [ ] Debug logging disabled
- [ ] WebView debugging disabled
- [ ] Code minification enabled
- [ ] `usesCleartextTraffic` set to false or conditional
- [ ] `startLocation` points to production URL
- [ ] All testing passes
- [ ] Version code incremented
- [ ] Version name updated
- [ ] Release notes prepared
