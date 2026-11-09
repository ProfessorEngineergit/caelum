package com.professorengineergit.caelum.core

import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.net.URI
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * NASA's Astronomy Picture of the Day via the keyless science.nasa.gov route that
 * replaced the retired api.nasa.gov/planetary/apod. A port of `APODSource.swift`
 * and of the `apod` source in `desktop/src/main/sources.js`: `hdurl` is the image
 * (the poster frame for videos) on NASA's resizing CDN, capped at ~1280 px; the
 * original lives at the same path under /content/dam/.
 */
class ApodSource(
    private val http: HttpClient = HttpClient(),
    private val now: () -> Long = System::currentTimeMillis,
) : ImageSource {
    override val id = "apod"
    override val name = "NASA APOD"
    override val subtitle = "Astronomy Picture of the Day"
    override val accent = 0xFF5EE7FFL

    override suspend fun fetchRecent(limit: Int): List<CosmicImage> {
        val count = limit.coerceIn(1, 25)
        val list = runCatching { parse(http.fetchText("$ENDPOINT?per_page=$count&_fields=$FIELDS")) }
            .getOrDefault(emptyList())
        if (list.isNotEmpty()) return list

        // The list route misbehaves now and then; ask for each day on its own.
        val days = (0 until minOf(count, 8)).map { n -> yyMMdd(now() - n * 86_400_000L) }
        val images = coroutineScope {
            days.map { day ->
                async { runCatching { parse(http.fetchText("$ENDPOINT/$day?_fields=$FIELDS")) }.getOrDefault(emptyList()) }
            }.awaitAll()
        }.flatten().sortedByDescending { it.date.orEmpty() }
        if (images.isEmpty()) throw SourceException("The source returned no images.")
        return images
    }

    companion object {
        const val ENDPOINT = "https://science.nasa.gov/wp-json/wp/v2/apod-basic"
        private const val FIELDS = "date,title,explanation,credit,copyright,media_type,url,hdurl,permalink"

        private val json = Json { ignoreUnknownKeys = true; isLenient = true }

        /** Newest first; entries without a usable image are dropped. Garbage parses to nothing. */
        fun parse(body: String): List<CosmicImage> {
            val root = runCatching { json.parseToJsonElement(body) }.getOrNull() ?: return emptyList()
            val entries = when (root) {
                is JsonArray -> root.toList()
                else -> listOf(root)
            }
            return entries.mapNotNull { (it as? JsonObject)?.let(::map) }
                .sortedByDescending { it.date.orEmpty() }
        }

        private fun map(e: JsonObject): CosmicImage? {
            // WordPress sends false/null for empty fields.
            fun str(key: String): String? = (e[key] as? JsonPrimitive)?.takeIf { it.isString }?.content

            val hd = str("hdurl")?.trim()
            if (!isHttp(hd) || hd == null) return null

            val isImage = (str("media_type") ?: "image").lowercase() == "image"
            val date = str("date")?.takeIf { DATE.containsMatchIn(it) }?.substring(0, 10)
            val size = originalSize(hd)
            val page = listOf(str("permalink"), str("url")).firstOrNull(::isHttp)?.trim()

            return CosmicImage(
                id = "apod-${date ?: hd.hashCode().toUInt().toString(36)}",
                title = plainText(str("title")).ifEmpty { "Astronomy Picture of the Day" },
                credit = cleanCredit(str("copyright")) ?: cleanCredit(str("credit")) ?: "NASA APOD",
                explanation = cleanExplanation(str("explanation")),
                date = date,
                sourceId = "apod",
                pageUrl = page ?: "https://science.nasa.gov/apod/",
                imageUrl = originalUrl(hd) ?: hd,
                thumbUrl = hd,
                isVideo = !isImage,
                resolution = when {
                    !isImage -> Resolution.SD
                    size != null -> Resolution.classify(size.first, size.second)
                    else -> Resolution.HD
                },
            )
        }

        private val DATE = Regex("^\\d{4}-\\d{2}-\\d{2}")

        /** …/dynamicimage/assets/science/…/x.jpg?w=… → …/content/dam/science/…/x.jpg */
        fun originalUrl(hd: String): String? = runCatching {
            val uri = URI(hd)
            val marker = "/dynamicimage/assets/"
            val path = uri.rawPath ?: return null
            if (!path.startsWith(marker)) return null
            "${uri.scheme}://${uri.rawAuthority}/content/dam/" + path.substring(marker.length)
        }.getOrNull()

        /** The original's size from the CDN URL's w/h (NASA writes 0 when unknown). */
        private fun originalSize(hd: String): Pair<Int, Int>? {
            val query = runCatching { URI(hd).rawQuery }.getOrNull() ?: return null
            val params = query.split('&').mapNotNull {
                val parts = it.split('=', limit = 2)
                if (parts.size == 2) parts[0] to parts[1] else null
            }.toMap()
            val w = params["w"]?.toIntOrNull() ?: 0
            val h = params["h"]?.toIntOrNull() ?: 0
            return if (w > 0 && h > 0) w to h else null
        }

        private val NOTICE_TEASERS = listOf(
            "APOD's email", "APOD’s email", "APOD's main NASA site", "APOD’s main NASA site",
            "Tomorrow's picture", "Tomorrow’s picture", "Tomorrow's Picture", "Tomorrow’s Picture",
        )
        private val NOTICE_BREAK = Regex("<br[^>]*>\\s*(?:<br[^>]*>\\s*)*<(?:strong|b)\\b", RegexOption.IGNORE_CASE)
        private val EXPLANATION_LABEL = Regex("^explanation:\\s*", RegexOption.IGNORE_CASE)
        private val CREDIT_LABEL = Regex(
            "^(?:image\\s+)?(?:credit\\s*(?:&|and)\\s*copyright|credit|copyright)\\s*:\\s*",
            RegexOption.IGNORE_CASE,
        )

        /** Explanation without the "Explanation:" label and the site notices after it. */
        fun cleanExplanation(html: String?): String? {
            if (html == null) return null
            // Notices follow as bold lines after a break: "…end.<br><br><strong>APOD's email…"
            val cut = NOTICE_BREAK.find(html)?.range?.first
            var text = plainText(if (cut != null) html.substring(0, cut) else html)
            for (teaser in NOTICE_TEASERS) {
                val i = text.indexOf(teaser)
                if (i >= 0) text = text.substring(0, i)
            }
            text = EXPLANATION_LABEL.replace(text.trim(), "").trim()
            return text.ifEmpty { null }
        }

        fun cleanCredit(html: String?): String? {
            val text = plainText(html)
            if (text.isEmpty()) return null
            return CREDIT_LABEL.replace(text, "").trim().ifEmpty { null }
        }

        private val YYMMDD = DateTimeFormatter.ofPattern("yyMMdd").withZone(ZoneOffset.UTC)

        internal fun yyMMdd(millis: Long): String = YYMMDD.format(Instant.ofEpochMilli(millis))
    }
}
