package com.ynonp.langlets.bridge

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination

/**
 * A short haptic tick when the user completes a lesson activity, matching the
 * medium-style `UIImpactFeedbackGenerator` on iOS.
 *
 * Fired by app/javascript/controllers/bridge/progress_haptic_controller.js on
 * the page's own `activity:completed` event, so the web side stays the single
 * source of truth for *when* an activity is done.
 */
class ProgressHapticComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "activityCompleted") return

        val context = activity ?: return
        val vibrator = vibrator(context) ?: return
        if (!vibrator.hasVibrator()) return

        val effect = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // EFFECT_TICK is the platform's own "something small succeeded"
            // haptic and respects the device's haptic strength setting.
            VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
        } else {
            // Android 9 is still supported, but predefined effects arrived in
            // Android 10. Keep its fallback deliberately brief and lightweight.
            VibrationEffect.createOneShot(10, VibrationEffect.DEFAULT_AMPLITUDE)
        }
        vibrator.vibrate(effect)
    }

    private fun vibrator(context: Context): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }
}
