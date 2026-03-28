package com.langlets.android

import android.app.Application
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerFragmentDestinations

class LangletsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        configureHotwire()
    }

    private fun configureHotwire() {
        // Configure JSON converter for bridge components
        Hotwire.config.jsonConverter = KotlinXJsonConverter()

        // Enable debug logging
        Hotwire.config.debugLoggingEnabled = true
        Hotwire.config.webViewDebuggingEnabled = true

        // Set default fragment destination
        Hotwire.defaultFragmentDestination = WebFragment::class

        // Register fragment destinations
        Hotwire.registerFragmentDestinations(
            WebFragment::class,
            WebBottomSheetFragment::class
        )
    }
}
