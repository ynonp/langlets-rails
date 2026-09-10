# Mobile builds

Langlets ships one multilingual app per platform. Spanish is included alongside
English and Hebrew; there is no separate Spanish application ID, OAuth client,
app group, or signing identity. Signed-in learners select **Native language →
Español** in Profile. Rails renders Spanish lessons and UI, and the native
bridge updates all four tab titles and the locale used for native close labels.
iOS also shares the account locale with its share extension. Startup resources
follow the device language until the account preference is available. Signed-out
web content continues to follow the host; it does not infer an account preference
from the device language.

## Android

Install JDK 21 and Android SDK platform 36/build-tools 36.0.0, then run:

```sh
cd langlets-android
./gradlew :app:assembleRelease :app:testDebugUnitTest
```

The APK is under `app/build/outputs/apk/release/`. Without the existing local
`keystore.properties` signing configuration it is explicitly an **unsigned**
APK and cannot be installed until signed. Use the existing production keystore
for an upgrade; creating a different key would make it incompatible with
installed copies. Release builds connect to `https://langlets.app`; authenticated
pages use the account's native language. Debug builds retain the existing
Android-emulator development URL.

Do not change `config/android_release.properties` or upload a public APK until
a signed release is ready: that manifest also controls the homepage download URL.
For a public release, bump both version fields, build with the production signing
configuration, and use `bin/upload-android-release` to publish the immutable APK.

## iOS

Use a Mac with Xcode and the project's resolved Swift packages. Build the shared
scheme, which includes the main application and its share extension:

```sh
xcodebuild -project langlets-ios/langlets/langlets.xcodeproj \
  -scheme langlets -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios CODE_SIGNING_ALLOWED=NO build
```

The simulator application is `build/ios/Build/Products/Debug-iphonesimulator/langlets.app`.
A simulator build is not an IPA for physical devices or TestFlight. Distribution
requires the existing Apple team certificates/profiles, a new build number for
both targets, and an Archive/export in Xcode. Preserve the bundle IDs, shared
keychain and app-group entitlements so sign-in, push and sharing keep working.

## GitHub Actions

`.github/workflows/mobile-builds.yml` is a manual build workflow. After the changes
are on a remote branch, run it with:

```sh
gh workflow run mobile-builds.yml --ref <branch>
```

It tests and uploads an unsigned Android release APK and a zipped iOS simulator
application from a macOS runner. It does not publish to stores or alter production.
The Linux devbox can build Android, but cannot run Xcode or produce an iOS archive.

## Spanish smoke check

- Open `https://es.langlets.app` after DNS and deployment; verify Spanish signup,
  confirmation/reset emails, OAuth return, library and course pages.
- In each native app, select Español in Profile and verify all four tabs, library,
  vocabulary, creation, lessons and notifications; then switch back to English
  and Hebrew, checking Hebrew RTL layout.
- On iOS, share a video after changing the language and check the Spanish share
  sheet. Verify the microphone permission prompt on a Spanish device.
- Confirm that importing uses Spanish as the translation target and that an
  existing course can request its Spanish translation.
