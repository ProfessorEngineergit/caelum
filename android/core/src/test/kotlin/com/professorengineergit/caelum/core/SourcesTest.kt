package com.professorengineergit.caelum.core

import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

// Mirrors desktop/test/sources.test.js so all three apps parse sources the same way.
class SourcesTest {

    // Trimmed from a real science.nasa.gov/wp-json/wp/v2/apod-basic response.
    private val apod = """
    [
      {
        "date": "2026-10-02",
        "title": "The Complete Sharpless Catalog: 313 Nebulas",
        "permalink": "https://science.nasa.gov/image-article/apod-2026-october-2-the-complete-sharpless-catalog-313-nebulae/",
        "media_type": "image",
        "explanation": "<strong>Explanation:</strong> What does it take to image hundreds of nebulas? <a href=\"x\">Today’s image</a> contains 313 objects.<br><br><strong>APOD's email for image submissions has changed.</strong> Please see: <a href=\"y\">APOD Submissions</a><br><strong>Tomorrow's picture: </strong><a href=\"z\">just Curiosity</a>",
        "credit": "<a href=\"https://example.com\">Bing Xin</a>",
        "copyright": "<a href=\"https://example.com\">Bing Xin</a>",
        "url": "https://science.nasa.gov/image-article/apod-2026-october-2-the-complete-sharpless-catalog-313-nebulae/",
        "hdurl": "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/october/sharpless_catalog.png?w=4455&h=5592&fit=clip&crop=faces%2Cfocalpoint"
      },
      {
        "date": "2026-10-03",
        "title": "Selfie at Vera Rubin Ridge",
        "media_type": "image",
        "explanation": "<strong>Explanation: </strong>On sol 1943 the Curiosity Rover recorded this selfie.",
        "credit": "<strong>Image Credit:</strong> <a href=\"http://www.nasa.gov/\">NASA</a>, JPL-Caltech",
        "copyright": false,
        "url": "https://science.nasa.gov/image-article/apod-2026-october-3-selfie-at-vera-rubin-ridge/",
        "hdurl": "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/october/Sol1943CuriosityBodrov.jpg?w=1600&h=800&fit=clip"
      },
      {
        "date": "2026-09-13",
        "title": "Comet Video",
        "media_type": "video",
        "explanation": "A video.",
        "hdurl": "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/september/Comet_snapshot.png?w=0&h=0"
      },
      { "date": "2026-09-12", "title": "No image", "hdurl": false }
    ]
    """.trimIndent()

    @Test
    fun apodNewestFirstAndEntriesWithoutImageDropped() {
        assertEquals(listOf("2026-10-03", "2026-10-02", "2026-09-13"), ApodSource.parse(apod).map { it.date })
    }

    @Test
    fun apodWallpaperIsTheOriginalAndTheCdnCopyIsThePreview() {
        val sharpless = ApodSource.parse(apod)[1]
        assertEquals(
            "https://assets.science.nasa.gov/content/dam/science/cds/apod/apod/2026/october/sharpless_catalog.png",
            sharpless.imageUrl,
        )
        assertTrue(Regex("/dynamicimage/assets/.*\\?w=4455").containsMatchIn(sharpless.thumbUrl!!))
        assertEquals(Resolution.UHD, sharpless.resolution)
        assertEquals("apod-2026-10-02", sharpless.id)
    }

    @Test
    fun apodTextIsCleaned() {
        val (selfie, sharpless) = ApodSource.parse(apod)
        assertEquals(
            "What does it take to image hundreds of nebulas? Today’s image contains 313 objects.",
            sharpless.explanation,
        )
        assertEquals("Bing Xin", sharpless.credit)
        assertEquals("On sol 1943 the Curiosity Rover recorded this selfie.", selfie.explanation)
        assertEquals("NASA, JPL-Caltech", selfie.credit)
        assertEquals(Resolution.SD, selfie.resolution)
        assertEquals(
            "https://science.nasa.gov/image-article/apod-2026-october-3-selfie-at-vera-rubin-ridge/",
            selfie.pageUrl,
        )
    }

    @Test
    fun apodVideosAreFlaggedAndNeverClaim4k() {
        val video = ApodSource.parse(apod).first { it.isVideo }
        assertEquals("Comet Video", video.title)
        assertEquals(Resolution.SD, video.resolution)
    }

    @Test
    fun apodErrorBodiesAndGarbageParseToNothing() {
        assertEquals(
            emptyList(),
            ApodSource.parse("""{"code":"apod_basic_not_found","message":"APOD not found.","data":{"status":404}}"""),
        )
        assertEquals(emptyList(), ApodSource.parse("<html>"))
    }

    @Test
    fun apodOriginalUrlOnlyForTheResizingCdn() {
        assertNull(ApodSource.originalUrl("https://apod.nasa.gov/apod/image/2610/x.jpg"))
    }

    @Test
    fun apodPerDayRouteUsesUtcDates() {
        // 2026-10-02 23:30 UTC — already the 3rd in Berlin, still the 2nd for NASA's route.
        assertEquals("261002", ApodSource.yyMMdd(1_790_983_800_000L))
    }

    @Test
    fun rssDjangoplicityItemsWithEnclosures() {
        val xml = """<?xml version="1.0"?><rss><channel><title>Feed</title>
            <item><title>A galaxy &amp; friends</title><link>https://esahubble.org/images/potw2640a/</link>
              <description><![CDATA[<p>Spiral <b>galaxy</b>.</p>]]></description>
              <enclosure url="https://cdn.esahubble.org/archives/images/screen/potw2640a.jpg" type="image/jpeg" length="1"/></item>
            <item><title>Video</title><enclosure url="https://x/v.mp4" type="video/mp4"/></item>
          </channel></rss>"""
        val items = Rss.parse(xml)
        assertEquals(2, items.size)
        assertEquals("A galaxy & friends", items[0].title)
        assertEquals("https://esahubble.org/images/potw2640a/", items[0].link)
        assertEquals("https://cdn.esahubble.org/archives/images/screen/potw2640a.jpg", items[0].imageUrl)
        assertEquals("Spiral galaxy.", plainText(items[0].description))
        assertNull(items[1].imageUrl)
    }

    @Test
    fun registryHasTheSameSourcesAndOrderAsTheOtherApps() {
        assertEquals(
            listOf("apod", "hubble", "webb", "eso", "deep", "earth", "solar", "stations", "interstellar", "artist-impressions"),
            SourceRegistry().all.map { it.id },
        )
    }

    @Test
    fun galleriesHaveHttpsUrls() = runBlocking {
        for (source in SourceRegistry().all.drop(4)) {
            val images = source.fetchRecent(100)
            assertTrue(images.size >= 7, source.id)
            for (image in images) {
                assertTrue(image.imageUrl.startsWith("https://"), image.imageUrl)
                image.thumbUrl?.let { assertTrue(it.startsWith("https://"), it) }
            }
        }
    }

    @Test
    fun entitiesAndResolutionClasses() {
        assertEquals("Tom’s — A B", plainText("Tom&#8217;s &#x2014; A&nbsp;B"))
        assertEquals(Resolution.UHD, Resolution.classify(3840, 2160))
        assertEquals(Resolution.HD, Resolution.classify(1920, 1080))
        assertEquals(Resolution.SD, Resolution.classify(1600, 800))
    }
}
