package com.ynonp.langlets

import androidx.core.net.toUri
import dev.hotwire.core.turbo.visit.VisitProposal
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.routing.Router

/**
 * In-app navigation for this app's own host, plus the two things that have to be
 * decided from the proposal rather than from path configuration.
 *
 * This replaces the library's `AppNavigationRouteDecisionHandler`; it matches the
 * same proposals and, in the ordinary case, makes the same decision. It is the
 * Android counterpart of iOS's `SceneDelegate.handle(proposal:from:)`, and it
 * exists for the same reason that method does: path configuration is a function
 * of the URL alone, so anything that depends on *device* state (has a language
 * been chosen? did the server just sign us out?) has nowhere else to live.
 */
class LangletsRouteDecisionHandler : Router.RouteDecisionHandler {
    override val name = "langlets-app-navigation"

    override fun matches(
        proposal: VisitProposal,
        configuration: NavigatorConfiguration
    ): Boolean {
        return configuration.startLocation.toUri().host == proposal.location.toUri().host
    }

    override fun handle(
        proposal: VisitProposal,
        configuration: NavigatorConfiguration,
        activity: HotwireActivity
    ): Router.Decision {
        val main = activity as? MainActivity ?: return Router.Decision.NAVIGATE

        main.observeProposedLocation(proposal.location)

        // Authentication just succeeded. Rebuild the tabs rather than following
        // the redirect — see MainActivity.isLeavingAuthFlow for why following it
        // silently does nothing.
        if (main.isLeavingAuthFlow(proposal.location)) {
            main.reloadTabs()
            return Router.Decision.CANCEL
        }

        // The marketing root is not a screen this app has. Signed-in native users
        // are redirected to /app by Rails anyway, but a link that reaches it —
        // the wordmark in the shared web header, for one — should land on the
        // Home tab rather than push a stray copy of Home onto whichever tab the
        // user happened to be in.
        if (proposal.location.toUri().path.orEmpty().let { it == "" || it == "/" }) {
            main.returnHome()
            return Router.Decision.CANCEL
        }

        return Router.Decision.NAVIGATE
    }
}
