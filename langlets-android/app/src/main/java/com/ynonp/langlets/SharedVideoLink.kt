package com.ynonp.langlets

import java.net.URI

/** Extracts the first YouTube or TikTok URL from text supplied by a share intent. */
object SharedVideoLink {
    private val urlPattern = Regex("""https?://[^\s<>\"']+""", RegexOption.IGNORE_CASE)
    private val supportedDomains = setOf("youtube.com", "youtu.be", "tiktok.com")

    fun firstSupportedUrl(text: CharSequence?): String? {
        if (text == null) return null

        return urlPattern.findAll(text)
            .map { it.value.trimEnd('.', ',', ';', ':', '!', '?', ')', ']', '}') }
            .firstOrNull(::isSupported)
    }

    private fun isSupported(candidate: String): Boolean {
        val host = runCatching { URI(candidate).host?.lowercase() }.getOrNull() ?: return false

        return supportedDomains.any { domain -> host == domain || host.endsWith(".$domain") }
    }
}
