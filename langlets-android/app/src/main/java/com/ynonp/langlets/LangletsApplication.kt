package com.ynonp.langlets

import android.app.Application
import com.ynonp.langlets.bridge.GoogleAuthComponent
import com.ynonp.langlets.bridge.LanguageSelectionComponent
import com.ynonp.langlets.bridge.NotificationPreferenceComponent
import com.ynonp.langlets.bridge.ProgressHapticComponent
import com.ynonp.langlets.bridge.SignOutComponent
import com.ynonp.langlets.bridge.TabBadgeComponent
import com.ynonp.langlets.bridge.TabVisibilityComponent
import com.ynonp.langlets.bridge.WebAuthComponent
import com.ynonp.langlets.features.LessonFragment
import com.ynonp.langlets.features.WebFragment
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.logging.HotwireLogLevel
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.fragments.HotwireWebBottomSheetFragment
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations
import dev.hotwire.navigation.config.registerRouteDecisionHandlers
import dev.hotwire.navigation.routing.BrowserTabRouteDecisionHandler
import dev.hotwire.navigation.routing.SystemNavigationRouteDecisionHandler

class LangletsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        LanguageStore.initialize(this)
        AuthHandoff.initialize(this)
        configureHotwire()
    }

    private fun configureHotwire() {
        Hotwire.defaultFragmentDestination = WebFragment::class

        // registerFragmentDestinations replaces the default list rather than
        // adding to it, so the library's bottom sheet has to be named explicitly
        // to stay reachable. No rule targets it today — the iOS config's one
        // medium-detent sheet (the deleted Credits screen) is gone — but leaving
        // it registered means a future `hotwire://fragment/web/modal/sheet` rule
        // is a path-configuration change rather than an app release.
        Hotwire.registerFragmentDestinations(
            WebFragment::class,
            HotwireWebBottomSheetFragment::class,
            LessonFragment::class
        )

        // Which components are here is load-bearing: the library advertises the
        // registered names in the User-Agent, and `BridgeComponent#enabled` on
        // the web side keys off that list. A component left out doesn't fail —
        // the web controller simply falls back to its browser behavior, which is
        // exactly what we want for the ones missing below.
        //
        // Deliberately NOT registered, and why:
        //
        // - `native-audio-feedback`: it exists to swap the Web Audio API for
        //   native playback of bundled correct/incorrect/complete sounds, and
        //   there are no such sound files in this repo (the iOS component looks
        //   them up in a `sounds/` subdirectory that was never added). Leaving it
        //   unregistered keeps `audio_feedback_controller.js` in charge, which
        //   actually makes sound.
        //
        // - `auth-bridge` (GitHub) and `apple-auth`: on iOS these lift OAuth out
        //   of the web view into `ASWebAuthenticationSession` and Apple's own
        //   sheet, and both end with a credential in the app's hands. Android
        //   has neither, so `web-auth` below stands in for the pair; all three
        //   sit on the same two buttons and only the registered one is enabled.
        //   Google is separate again and cannot use any of them, because it
        //   refuses to serve its consent screen to a browser it can tell an app
        //   launched — see GoogleAuthComponent's class comment.
        //
        // - `push` / `native-token` / `apple-purchase`: FCM, the share extension
        //   and StoreKit respectively. None have an Android counterpart yet.
        Hotwire.registerBridgeComponents(
            BridgeComponentFactory("progress-haptic", ::ProgressHapticComponent),
            BridgeComponentFactory("sign-out", ::SignOutComponent),
            BridgeComponentFactory("language-selection", ::LanguageSelectionComponent),
            BridgeComponentFactory("tab-badge", ::TabBadgeComponent),
            BridgeComponentFactory("tab-visibility", ::TabVisibilityComponent),
            BridgeComponentFactory("notification-preference", ::NotificationPreferenceComponent),
            BridgeComponentFactory("google-auth", ::GoogleAuthComponent),
            BridgeComponentFactory("web-auth", ::WebAuthComponent)
        )

        // Replaces the library's default handler list. Ours stands in for
        // AppNavigationRouteDecisionHandler; the other two are the stock ones and
        // must stay, in this order — the browser tab handles external http(s)
        // links, and system navigation is what turns the server's
        // `langlets://auth-success` redirect back into an Intent for MainActivity.
        Hotwire.registerRouteDecisionHandlers(
            LangletsRouteDecisionHandler(),
            BrowserTabRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler()
        )

        Hotwire.config.jsonConverter = KotlinXJsonConverter()
        Hotwire.config.makeCustomWebView = { context -> LangletsWebView(context) }
        // "LangletsNative" is the stable marker ApplicationController#native_app?
        // looks for, and it is deliberately the same string iOS sends — every
        // native client routes to the shared /app content. "(Android)" is the
        // narrower marker for the handful of places where the two platforms
        // genuinely differ (ApplicationController#android_app?): today, the copy
        // that points users at the iOS share extension. Do not repurpose it for
        // routing.
        Hotwire.config.applicationUserAgentPrefix = "${Langlets.USER_AGENT_PREFIX}/1.0 (Android);"
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG
        Hotwire.config.logger.logLevel = if (BuildConfig.DEBUG) {
            HotwireLogLevel.DEBUG
        } else {
            HotwireLogLevel.NONE
        }

        // Two sources, and the order is not cosmetic: the bundled asset is the
        // offline fallback and the first-launch seed, and the server copy wins
        // once it arrives — so which screens are modal can change with a Rails
        // deploy instead of a Play Store release. The two must stay identical in
        // the repo; test/controllers/configurations_controller_test.rb enforces
        // it for both platforms.
        //
        // Note this is `android_v1`, not the iOS file. The rules are the same
        // ones, but Android's path configuration additionally needs a `uri` per
        // rule naming the fragment destination to build, which the iOS copy has
        // no concept of.
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/path_configuration.json",
                remoteFileUrl = "${Langlets.rootUrl}/configurations/android_v1.json"
            )
        )
    }
}
