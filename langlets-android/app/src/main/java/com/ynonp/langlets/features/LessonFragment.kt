package com.ynonp.langlets.features

import android.os.Bundle
import android.view.View
import com.ynonp.langlets.R
import dev.hotwire.core.turbo.visit.VisitAction
import dev.hotwire.core.turbo.visit.VisitOptions
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink

/**
 * Course lesson and review lesson screens, including the review lesson build's
 * waiting and failed screens. The Android counterpart of iOS's
 * `LessonViewController`, and it exists for the same reason: the toolbar control
 * on these screens must **close the whole lesson**, not step back one activity.
 *
 * Path configuration presents all of these in a modal context, so the library
 * already swaps the toolbar's back arrow for a close icon. What it does not do
 * is change what the icon means — the stock handler is `navigator.pop()`, one
 * entry at a time. Most of a lesson's activities swap inside a Turbo Frame and
 * never touch the back stack, but the ones that do visit (a review build's
 * waiting screen handing off to the finished lesson, a lesson's finish page)
 * would otherwise leave the user tapping X repeatedly to get out of a session
 * they asked to leave once.
 *
 * Also note the app bar is kept here even though this is the first screen of its
 * modal context, which is the case [WebFragment] would normally hide it for.
 * Without it there is no close affordance at all: the modal covers the bottom
 * navigation, and a lesson's own web page has no exit of its own.
 */
@HotwireDestinationDeepLink(uri = "hotwire://fragment/web/lesson")
class LessonFragment : WebFragment() {
    override val showsAppBar: Boolean
        get() = true

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        toolbarForNavigation()?.apply {
            setNavigationIcon(R.drawable.ic_close)
            setNavigationContentDescription(R.string.close_lesson)
            setNavigationOnClickListener { closeLesson() }
        }
    }

    /**
     * Leave the lesson.
     *
     * Two cases, and the second is the one worth spelling out:
     *
     * **There is something underneath** (the ordinary path — a lesson opened from
     * a course page). Pop, then check again on the next frame and pop any further
     * modal entry. Most of a lesson's activities swap inside a Turbo Frame and
     * never touch the back stack, so this usually pops exactly once; the loop is
     * for the visits that do stack, such as a review build's waiting screen
     * handing off to the finished lesson. It cannot run away, because the entry
     * underneath the modal context is by definition not a [LessonFragment].
     *
     * `Navigator.pop` defers its work until the current destination reports
     * itself ready, so re-checking after the view has processed the previous pop
     * is what makes the count come out right; popping in a tight loop would queue
     * several pops against the same back stack state.
     *
     * **The lesson is the only entry.** This happens when the lesson *is* the
     * back stack — a notification or share deep link that cold-boots straight
     * into one, or a redirect that replaced the root. There is nothing to pop,
     * and the earlier version of this method simply did nothing, leaving the X
     * dead and the system back button quitting the app. Route to the tab's own
     * start location instead, which is where dismissing should land anyway.
     */
    private fun closeLesson() {
        val navigator = this.navigator

        if (navigator.isAtStartDestination()) {
            navigator.route(
                navigator.configuration.startLocation,
                VisitOptions(action = VisitAction.REPLACE)
            )
            return
        }

        navigator.pop()

        view?.post {
            (navigator.currentDestination as? LessonFragment)
                ?.takeIf { it !== this }
                ?.closeLesson()
        }
    }
}
