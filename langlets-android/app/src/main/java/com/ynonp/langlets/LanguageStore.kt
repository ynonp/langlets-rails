package com.ynonp.langlets

import android.content.Context
import android.content.SharedPreferences
import androidx.core.net.toUri

/**
 * The learning language the user picked during onboarding, plus the checkpoint
 * that lets an interrupted onboarding resume on the next cold launch.
 *
 * This is the Android counterpart of the iOS `UserDefaults` keys
 * `selectedLanguage` and `pendingOnboardingURL`, and it exists for the same
 * reason: the app appends `?lang=<iso>` to every tab's start URL, and without it
 * the server bounces the first request of every launch to language onboarding.
 *
 * There is no App Group equivalent here — that suite only existed for the iOS
 * share extension, which Android does not have.
 */
object LanguageStore {
    private const val PREFS = "langlets"
    private const val KEY_LANGUAGE = "selectedLanguage"
    private const val KEY_PENDING_ONBOARDING_URL = "pendingOnboardingURL"

    /** The onboarding pages worth checkpointing for the next cold launch. */
    private val onboardingPaths = listOf("/onboarding/welcome", "/onboarding/language")

    private lateinit var prefs: SharedPreferences

    fun initialize(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    var language: String?
        get() = prefs.getString(KEY_LANGUAGE, null)?.ifEmpty { null }
        set(value) = prefs.edit().putString(KEY_LANGUAGE, value).apply()

    /**
     * Reset every account-specific checkpoint. Called by the sign-out bridge and
     * whenever the server's signed-out redirect is seen, so that the next sign-in
     * — which may be a different account — cannot inherit this one's language and
     * silently skip onboarding.
     */
    fun reset() {
        prefs.edit()
            .remove(KEY_LANGUAGE)
            .remove(KEY_PENDING_ONBOARDING_URL)
            .apply()
    }

    fun clearPendingOnboardingUrl() {
        prefs.edit().remove(KEY_PENDING_ONBOARDING_URL).apply()
    }

    /**
     * Checkpoint an unfinished onboarding page before the navigator follows it.
     * The web navigation stack is lost when Android kills the process; this
     * survives and lets the next cold launch resume the same URL, `returnto` and
     * all, instead of restarting the flow from `/app`.
     */
    fun rememberPendingOnboardingUrl(url: String) {
        if (language != null) return
        val uri = url.toUri()
        if (uri.path !in onboardingPaths) return

        // Store path + query only. The host comes from Langlets.rootUrl when the
        // checkpoint is read back, so a debug checkpoint can't outlive a switch
        // to the production server.
        val relative = buildString {
            append(uri.path)
            uri.encodedQuery?.let { append("?").append(it) }
        }
        prefs.edit().putString(KEY_PENDING_ONBOARDING_URL, relative).apply()
    }

    private fun pendingOnboardingUrl(): String? {
        val pending = prefs.getString(KEY_PENDING_ONBOARDING_URL, null) ?: return null
        val uri = pending.toUri()
        if (uri.path !in onboardingPaths) return null
        return Langlets.rootUrl + pending
    }

    /**
     * Restore the authenticated account's server-side language preference. Rails
     * sends it as `ios_lang` after login (the parameter name predates Android and
     * is shared by both shells) so that a prior sign-out can safely clear device
     * state without forcing a returning user back through onboarding.
     *
     * @return true when a language was restored, so the caller can reload.
     */
    fun restoreFrom(url: String): Boolean {
        val restored = url.toUri().getQueryParameter("ios_lang")?.ifEmpty { null } ?: return false
        if (restored == language) return false

        language = restored
        clearPendingOnboardingUrl()
        return true
    }

    /**
     * The start URL for a tab, carrying the language picked during onboarding.
     * Until one has been picked, an interrupted onboarding's checkpoint wins over
     * the tab's own path — otherwise a cold launch would rebuild the flow from
     * `/app` and lose the `returnto` the user was headed for.
     */
    fun startUrl(path: String): String {
        val lang = language ?: return pendingOnboardingUrl() ?: (Langlets.rootUrl + path)
        return "${Langlets.rootUrl}$path?lang=$lang"
    }
}
