package com.ynonp.langlets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SharedVideoLinkTest {
    @Test
    fun extractsYouTubeUrlFromSharedText() {
        assertEquals(
            "https://youtu.be/kJQP7kiw5Fk?si=example",
            SharedVideoLink.firstSupportedUrl(
                "Luis Fonsi - Despacito https://youtu.be/kJQP7kiw5Fk?si=example"
            )
        )
    }

    @Test
    fun extractsTikTokShareUrlAndDropsSentencePunctuation() {
        assertEquals(
            "https://vm.tiktok.com/ZMexample/",
            SharedVideoLink.firstSupportedUrl(
                "Watch this video on TikTok: https://vm.tiktok.com/ZMexample/."
            )
        )
    }

    @Test
    fun skipsUnsupportedUrlBeforeSupportedVideo() {
        assertEquals(
            "https://www.youtube.com/shorts/kJQP7kiw5Fk",
            SharedVideoLink.firstSupportedUrl(
                "More info https://example.com/video then https://www.youtube.com/shorts/kJQP7kiw5Fk"
            )
        )
    }

    @Test
    fun rejectsLookalikeAndUnrelatedHosts() {
        assertNull(SharedVideoLink.firstSupportedUrl("https://youtube.com.evil.example/watch?v=123"))
        assertNull(SharedVideoLink.firstSupportedUrl("https://example.com/video"))
        assertNull(SharedVideoLink.firstSupportedUrl("not a URL"))
    }
}
