package com.ynonp.langlets.bridge

import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import android.util.Log
import com.ynonp.langlets.BuildConfig
import androidx.lifecycle.lifecycleScope
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/**
 * Signs in with Google through Credential Manager, and hands the resulting
 * Google ID token back to the web side, which posts it to
 * `/users/auth/native_google` where its signature, audience and expiry are
 * verified.
 *
 * **Why this exists at all.** Every other link in this app is content the web
 * view can just load, and OAuth looks like it should be too. It isn't. The
 * redirect flow starts in the web view — where Rails writes `omniauth.state`
 * into the session cookie — and then `accounts.google.com` is a different host,
 * so Hotwire's `BrowserTabRouteDecisionHandler` correctly hands it to a Chrome
 * Custom Tab. Google's callback then arrives in a *different cookie jar*: no
 * `omniauth.state` to check against, and any session it did create would belong
 * to Chrome, not to this app. Keeping it in the web view instead is not an
 * option either — Google refuses to render its consent screen in an embedded
 * WebView (`disallowed_useragent`), and defeating that check by editing the user
 * agent is against their policy.
 *
 * So the credential has to be obtained natively and carried across by hand. That
 * is the same shape as iOS's `GoogleAuthComponent`; only the SDK and the
 * credential type differ, and `native_google` accepts both.
 *
 * **Why an ID token rather than a serverAuthCode** (which is what iOS sends, and
 * would have needed no server change): the ID token is self-verifying, so the
 * server checks a signature instead of holding a second conversation with Google
 * on every sign-in, and it reuses the JWKS verification `native_apple` already
 * does.
 *
 * **This requires an Android OAuth client to exist**, in the same Google Cloud
 * project as the Web client, registered with this app's package name and the
 * SHA-1 of its signing certificate — one entry per certificate, so debug and
 * release each need theirs. That client id is never named in this file and is not
 * the [SERVER_CLIENT_ID] below; Play services looks the caller up by package and
 * signature before it will mint a token, and refuses with
 * `UNREGISTERED_ON_API_CONSOLE` when it finds nothing. It surfaces as a
 * *cancellation* (see [isProviderFailure]), which is a long way from the actual
 * cause, so: if sign-in fails on a new signing key, this is why.
 *
 * Paired with app/javascript/controllers/bridge/google_auth_controller.js.
 */
class GoogleAuthComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "authorize") return

        val fragment = delegate.destination.fragment
        val activity = this.activity ?: return

        fragment.lifecycleScope.launch {
            val response = try {
                val option = GetSignInWithGoogleOption.Builder(SERVER_CLIENT_ID).build()
                val request = GetCredentialRequest.Builder().addCredentialOption(option).build()

                // The Activity, not the application context: this call presents
                // the account sheet, so it needs something that can host UI.
                val credential = CredentialManager.create(activity)
                    .getCredential(activity, request)
                    .credential

                idTokenFrom(credential)
                    ?.let { AuthorizeResponse(idToken = it) }
                    ?: AuthorizeResponse(error = "Unexpected credential type")
            } catch (e: GetCredentialException) {
                // Log every failure, including cancellation. The framework
                // reports a provider-side failure as a *cancellation* when its
                // sheet dismisses itself — an unregistered app, Play services
                // refusing the request — so treating the cancellation type as
                // "nothing to see here" and staying silent turns every real
                // error into a button that does nothing at all. The type and
                // message here are the only way to tell the two apart.
                Log.w(TAG, "Credential Manager returned ${e.type}: ${e.errorMessage}", e)

                when {
                    e is NoCredentialException ->
                        AuthorizeResponse(error = "No Google account is available on this device.")

                    e is GetCredentialCancellationException && !isProviderFailure(e) ->
                        // A genuine dismissal. Said explicitly rather than by
                        // replying with nothing: an empty reply is
                        // indistinguishable from a failed one, and the web side
                        // would then tell someone who deliberately closed the
                        // sheet that Google "could not authenticate" them.
                        AuthorizeResponse(cancelled = true)

                    else ->
                        AuthorizeResponse(error = userFacingError(e))
                }
            }

            replyTo("authorize", response)
        }
    }

    /**
     * What the sign-in screen should say about a failure.
     *
     * Play services' own messages are written for whoever configured the app, not
     * for whoever is trying to sign in — `[8] Unknown error
     * [status=UNREGISTERED_ON_API_CONSOLE]` is precise, actionable, and
     * meaningless to a user who just wants to log in. Debug builds show it
     * anyway, because during bring-up the person reading the screen *is* the
     * person who can fix it; release builds get a sentence, and the detail stays
     * in Logcat where it was already logged.
     */
    private fun userFacingError(e: GetCredentialException): String {
        val detail = e.errorMessage?.toString() ?: e.type
        return if (BuildConfig.DEBUG) detail else "Google sign-in isn't available right now."
    }

    /**
     * Whether a "cancelled" exception is really Play services reporting its own
     * failure.
     *
     * Credential Manager has one cancellation type and two very different things
     * map onto it: the user dismissing the sheet, and the provider giving up
     * after the user has already chosen an account. The second arrives with a
     * Play services status code in brackets — `[16] Account reauth failed.`,
     * `[8] ...` — which a genuine dismissal never carries. That bracketed prefix
     * is the only signal separating them.
     *
     * Getting this wrong is silent in the worst way: a real failure classified as
     * a dismissal shows the user nothing at all, and "the button does nothing" is
     * a bug report with no evidence in it.
     */
    private fun isProviderFailure(e: GetCredentialException): Boolean {
        return PROVIDER_STATUS_PREFIX.containsMatchIn(e.errorMessage ?: return false)
    }

    private fun idTokenFrom(credential: androidx.credentials.Credential): String? {
        if (credential !is CustomCredential) return null
        if (credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) return null

        return GoogleIdTokenCredential.createFrom(credential.data).idToken
    }

    @Serializable
    data class AuthorizeResponse(
        val idToken: String? = null,
        val error: String? = null,
        val cancelled: Boolean = false
    )

    private companion object {
        const val TAG = "GoogleAuthComponent"

        /** A leading `[16]`-style Play services status code. See isProviderFailure. */
        val PROVIDER_STATUS_PREFIX = Regex("""^\s*\[\d+]""")

        /**
         * The **Web** OAuth client id — the same one Rails' OmniAuth backend uses
         * (`Rails.application.credentials.google_client_id`) and the same one the
         * iOS app passes as `serverClientID`. It is not an Android client id and
         * must not be replaced with one: it is the `aud` claim the server pins
         * the returned token against, which is the whole basis for trusting it.
         */
        const val SERVER_CLIENT_ID =
            "570385807243-a77uce7m9eu2i7d8tsbveal8ejpit5d3.apps.googleusercontent.com"
    }
}
