package com.ynonp.langlets

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * The app's half of the browser-to-web-view session handoff. The server's half,
 * and the reasoning behind the whole thing, is in `NativeAuthHandoff`.
 *
 * The short version: GitHub and Apple sign-in cannot complete inside this app's
 * web view. Their consent pages are on a different host, so Hotwire's
 * [dev.hotwire.navigation.routing.BrowserTabRouteDecisionHandler] lifts them
 * into a Chrome Custom Tab — and a Custom Tab's cookies belong to Chrome. A flow
 * that starts here and finishes there is split across two cookie jars: the
 * `omniauth.state` written on this side is not there to be checked on that side,
 * and the session that does get established is Chrome's. iOS never meets this
 * because `ASWebAuthenticationSession` shares a jar with `WKWebsiteDataStore`;
 * there is no Android equivalent, which is the entire reason this file exists.
 *
 * So the flow is run *wholly* in the Custom Tab — one jar, so state and nonce
 * checks work again — and the session is carried back by a one-time token on the
 * `langlets://auth-success` deep link.
 *
 * ## Why the verifier
 *
 * A custom scheme is not exclusive: any installed app may declare `langlets://`
 * and receive that redirect. So the token is not enough on its own. Before the
 * browser opens, [begin] draws a random verifier, keeps it here, and sends only
 * `base64url(SHA-256(verifier))`; redemption has to produce the verifier. That
 * is RFC 7636's S256 exchange, used for exactly the reason it was designed —
 * whoever intercepts the redirect holds a value they cannot spend.
 *
 * The verifier is persisted rather than held in memory because Android may kill
 * this process while the Custom Tab is in front of it, and the deep link would
 * then arrive at a cold-started Activity with nothing to redeem.
 */
object AuthHandoff {
    private const val PREFS = "langlets_auth_handoff"
    private const val KEY_VERIFIER = "verifier"
    private const val KEY_STARTED_AT = "startedAt"

    /**
     * How long a stored verifier stays usable. It only has to outlive reading a
     * consent screen — plus, realistically, a password manager and a 2FA prompt
     * — and it matches the server's own window for the flow. Past it, the
     * verifier is a leftover from a sign-in the user abandoned.
     */
    private const val MAX_AGE_MILLIS = 30L * 60 * 1000

    /** base64url, no padding, no line breaks — what both ends of this agree on. */
    private const val BASE64_FLAGS = Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP

    private lateinit var prefs: SharedPreferences

    fun initialize(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    /**
     * Start a flow for [provider] and return the URL the browser should open.
     *
     * Any verifier from an earlier, abandoned attempt is replaced: only the most
     * recent flow can be completed, so a stale one cannot be resumed by a deep
     * link that arrives late.
     */
    fun begin(provider: String): String {
        val verifier = randomVerifier()

        prefs.edit()
            .putString(KEY_VERIFIER, verifier)
            .putLong(KEY_STARTED_AT, System.currentTimeMillis())
            .apply()

        val challenge = challengeFor(verifier)

        return "${Langlets.rootUrl}/users/auth/native_handoff_start" +
            "?provider=${provider.encoded()}&challenge=${challenge.encoded()}"
    }

    /**
     * The verifier for the flow in progress, consumed. Null when there is none,
     * or when it belongs to a flow too old to still be the one that just
     * finished.
     *
     * Consuming rather than merely reading is what keeps a single verifier from
     * being spent twice — the server enforces the same thing for the token, and
     * both halves should be one-shot for the same reason.
     */
    fun takeVerifier(): String? {
        val verifier = prefs.getString(KEY_VERIFIER, null)
        val startedAt = prefs.getLong(KEY_STARTED_AT, 0)

        forget()

        if (verifier.isNullOrEmpty()) return null
        if (System.currentTimeMillis() - startedAt > MAX_AGE_MILLIS) return null

        return verifier
    }

    fun forget() {
        prefs.edit().remove(KEY_VERIFIER).remove(KEY_STARTED_AT).apply()
    }

    /** Where to spend [token], proving ownership of the flow with [verifier]. */
    fun redemptionUrl(token: String, verifier: String): String {
        return "${Langlets.rootUrl}/users/auth/native_handoff" +
            "?token=${token.encoded()}&verifier=${verifier.encoded()}"
    }

    private fun randomVerifier(): String {
        val bytes = ByteArray(32).also { SecureRandom().nextBytes(it) }
        return Base64.encodeToString(bytes, BASE64_FLAGS)
    }

    private fun challengeFor(verifier: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(verifier.toByteArray(Charsets.US_ASCII))

        return Base64.encodeToString(digest, BASE64_FLAGS)
    }

    /**
     * base64url output contains `-` and `_`, which are query-safe, but encoding
     * is still the correct thing to do rather than a coincidence to rely on.
     */
    private fun String.encoded(): String = java.net.URLEncoder.encode(this, "UTF-8")
}
