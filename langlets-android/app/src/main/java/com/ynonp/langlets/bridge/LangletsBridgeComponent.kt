package com.ynonp.langlets.bridge

import com.ynonp.langlets.MainActivity
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.navigation.destinations.HotwireDestination

/**
 * Shared plumbing for the components that need to talk to the native shell.
 *
 * The reach from a component to the Activity is short but worth naming: bridge
 * messages arrive on the destination fragment, and several of them
 * (`tab-badge`, `tab-visibility`, `sign-out`) are really
 * addressed to the tab bar. On iOS that hop is a `NotificationCenter` post,
 * because the sending page may be a modal sheet whose view controller has no
 * `tabBarController`. Android has no such gap — a fragment in a modal context is
 * still hosted by this Activity — so the reference is direct.
 *
 * [activity] is null only while the fragment is detached, which is why every
 * caller treats it as optional rather than asserting.
 */
abstract class LangletsBridgeComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    protected val activity: MainActivity?
        get() = delegate.destination.fragment.activity as? MainActivity
}
