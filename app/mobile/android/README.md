# Langlets Android App

A Hotwire Native Android wrapper for the Langlets Rails application.

## Prerequisites

- **Android Studio** (Arctic Fox or later)
- **JDK 17** (bundled with Android Studio)
- **Rails server** running locally

## Setup

1. **Open the project in Android Studio:**
   ```
   File → Open → Select: app/mobile/android/Langlets/
   ```

2. **Wait for Gradle sync** to complete (may take a few minutes on first open)

3. **If you see "Invalid Gradle JDK" error:**
   - Click "Use Embedded JDK" in the notification banner
   - Or: File → Settings → Build → Gradle → Gradle JDK → Select "Embedded JDK"

## Running on Emulator

1. **Start the Rails server:**
   ```bash
   bin/dev
   ```

2. **Create an emulator** (if you don't have one):
   - Tools → Device Manager → Create Device
   - Select a phone (e.g., Pixel 6)
   - Select a system image (API 34 recommended)
   - Finish setup

3. **Run the app:**
   - Select your emulator from the device dropdown
   - Click the green Run button (or Shift+F10)

4. **Access the app:**
   - The app connects to `http://10.0.2.2:3000` (emulator's localhost mapping)
   - Login with your Langlets credentials

## Building APK

### Debug APK (for testing)

1. Build → Build Bundle(s) / APK(s) → Build APK(s)
2. Find APK at: `app/mobile/android/Langlets/app/build/outputs/apk/debug/app-debug.apk`

### Release APK (for distribution)

1. **Create a keystore** (first time only):
   ```
   Build → Generate Signed Bundle / APK → APK → Create new...
   ```

2. **Update the base URL** in `MainActivity.kt`:
   ```kotlin
   private const val BASE_URL = "https://your-production-url.com"
   ```

3. **Generate signed APK:**
   ```
   Build → Generate Signed Bundle / APK → APK → Select keystore → Release
   ```

## Project Structure

```
Langlets/
├── build.gradle.kts          # Root - plugin versions
├── settings.gradle.kts       # Project settings
├── gradle.properties         # Gradle config
└── app/
    ├── build.gradle.kts      # App dependencies
    └── src/main/
        ├── AndroidManifest.xml
        ├── java/com/langlets/android/
        │   ├── MainActivity.kt              # TurboActivity entry point
        │   └── MainSessionNavHostFragment.kt # WebView configuration
        └── res/
            ├── layout/activity_main.xml
            ├── values/                      # strings, themes, colors
            └── drawable/                    # launcher icons
```

## Configuration

| Setting | Value | Location |
|---------|-------|----------|
| Base URL | `http://10.0.2.2:3000` | MainActivity.kt |
| Path Config | `/hotwire_native/path-configuration` | MainActivity.kt |
| User Agent | `Turbo Native Android` | MainSessionNavHostFragment.kt |
| Min SDK | 26 (Android 8.0) | app/build.gradle.kts |
| Target SDK | 34 (Android 14) | app/build.gradle.kts |

## Troubleshooting

**App shows blank screen:**
- Ensure Rails server is running (`bin/dev`)
- Check emulator has internet access

**"Plugin com.android.application not found":**
- Make sure you opened the `Langlets/` folder, not the parent `android/` folder

**Gradle sync fails:**
- File → Invalidate Caches → Invalidate and Restart
- Delete `.gradle/` and `.idea/` folders, reopen project

**WebView not loading:**
- Check `AndroidManifest.xml` has `android:usesCleartextTraffic="true"`
- Verify `INTERNET` permission is present
