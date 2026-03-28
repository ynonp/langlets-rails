# Specification: Hotwire Native Integration

## Goal
Wrap the Langlets Rails web app in native iOS/Android shells using Turbo WebViews, solving iOS PWA session/cookie issues while providing a native-feeling experience.

## User Stories
- As a mobile user, I want to use Langlets as a native app so that my login session persists reliably
- As a developer, I want to detect native app requests so that I can conditionally hide web-only UI elements

## Specific Requirements

**Path Configuration Endpoint**
- Create Rails controller at `HotwireNative::ConfigurationsController`
- Serve JSON at `/hotwire-native/path-configuration`
- Skip CSRF verification for mobile access
- Return settings and rules structure for navigation control
- MVP rule: match all paths with default context

**User-Agent Detection Helpers**
- Add `turbo_native_app?` helper to detect any Turbo Native request
- Add `turbo_native_ios?` helper to detect iOS native app
- Add `turbo_native_android?` helper to detect Android native app
- Match against "Turbo Native" string in user agent
- Make helpers available in all views via ApplicationHelper

**Layout Modifications**
- Add `turbo-native` CSS class to body when native app detected
- Conditionally hide PWA meta tags (manifest, apple-mobile-web-app) for native apps
- Keep existing web behavior unchanged for browser users

**Native CSS Styles**
- Add `.turbo-native` selector to application.tailwind.css
- Hide PWA install banners and prompts when in native wrapper
- Use Tailwind conventions for styling

**Android App Structure**
- Create project at `app/mobile/android/`
- Use Kotlin with TurboActivity and TurboWebViewFragment
- Configure base URL: `http://10.0.2.2:3000` for emulator
- Set user agent to include "Turbo Native Android"
- Enable JavaScript, DOM storage, and cookie persistence
- Add Turbo dependency: `dev.hotwire:turbo:7.1.0`
- Min SDK 26, Target SDK 34

**iOS App Structure (Document Only)**
- Document structure at `app/mobile/ios/` for future implementation
- Requires Mac access - blocked for now
- Will use Swift with turbo-ios via SPM

**Session Persistence**
- Use WebView CookieManager for cookie storage on Android
- Leverage existing Devise remember_me (1 year) configuration
- Validate login persists across: navigation, background/foreground, idle time

## Visual Design
No visual assets provided.

## Existing Code to Leverage

**ApplicationHelper (`app/helpers/application_helper.rb`)**
- Add new detection methods alongside existing helpers
- Follow existing pattern of simple, focused helper methods

**Devise Configuration (`config/initializers/devise.rb`)**
- Already configured for 1-year remember_me cookies
- Sessions controller forces remember_me on login
- No changes needed - just leverage existing behavior

**Application Layout (`app/views/layouts/application.html.erb`)**
- Existing PWA meta tags to conditionally hide
- Body element where turbo-native class will be added
- Standard Rails 8 layout structure

**Tailwind CSS (`app/assets/stylesheets/application.tailwind.css`)**
- Existing responsive styles and dark theme
- Add new .turbo-native selector following existing patterns

## Out of Scope
- Offline lessons/content caching
- Push notifications
- Native UI screens (tabs, modals)
- App Store / Play Store publishing
- iOS implementation (blocked - no Mac access)
- Production deployment configuration
- Performance optimizations
- Analytics integration in native apps
- Deep linking / universal links
- Background sync
