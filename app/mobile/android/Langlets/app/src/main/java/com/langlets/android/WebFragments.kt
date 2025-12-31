package com.langlets.android

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import dev.hotwire.core.turbo.errors.VisitError
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment
import dev.hotwire.navigation.fragments.HotwireWebBottomSheetFragment

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class WebFragment : HotwireWebFragment() {

    private var offlineView: View? = null
    private var retryHandler: Handler? = null
    private var retryRunnable: Runnable? = null
    private var retryCount = 0
    private var countdownSeconds = 0

    // Retry intervals in seconds: 5s, 10s, 15s, 30s, then 60s forever
    private val retryIntervals = listOf(5, 10, 15, 30, 60)

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        retryHandler = Handler(Looper.getMainLooper())
    }

    override fun createErrorView(error: VisitError): View {
        return layoutInflater.inflate(R.layout.fragment_offline, view as? ViewGroup, false).apply {
            offlineView = this

            findViewById<Button>(R.id.retry_button)?.setOnClickListener {
                cancelAutoRetry()
                retryCount = 0
                reloadPage()
            }

            // Start auto-retry countdown
            scheduleAutoRetry()
        }
    }

    private fun scheduleAutoRetry() {
        cancelAutoRetry()

        val intervalIndex = minOf(retryCount, retryIntervals.size - 1)
        countdownSeconds = retryIntervals[intervalIndex]
        retryCount++

        startCountdown()
    }

    private fun startCountdown() {
        retryRunnable = object : Runnable {
            override fun run() {
                if (countdownSeconds > 0) {
                    updateRetryStatus(getString(R.string.retry_status_next, countdownSeconds))
                    countdownSeconds--
                    retryHandler?.postDelayed(this, 1000)
                } else {
                    updateRetryStatus(getString(R.string.retry_status_connecting))
                    reloadPage()
                }
            }
        }
        retryHandler?.post(retryRunnable!!)
    }

    private fun updateRetryStatus(message: String) {
        offlineView?.findViewById<TextView>(R.id.retry_status)?.apply {
            text = message
            visibility = View.VISIBLE
        }
    }

    private fun cancelAutoRetry() {
        retryRunnable?.let { retryHandler?.removeCallbacks(it) }
        retryRunnable = null
    }

    private fun reloadPage() {
        // Navigate to the current location to retry
        navigator.route(location)
    }

    override fun onDestroyView() {
        cancelAutoRetry()
        retryHandler = null
        offlineView = null
        super.onDestroyView()
    }
}

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web/modal/sheet")
class WebBottomSheetFragment : HotwireWebBottomSheetFragment()
