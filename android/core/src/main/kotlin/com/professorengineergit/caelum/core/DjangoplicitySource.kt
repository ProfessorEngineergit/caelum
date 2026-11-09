package com.professorengineergit.caelum.core

/**
 * ESA/Hubble, ESA/Webb and ESO all run Djangoplicity and publish the same kind of
 * RSS feed. A port of `DjangoplicitySource.swift`.
 */
class DjangoplicitySource(
    override val id: String,
    override val name: String,
    override val subtitle: String,
    override val accent: Long,
    private val feedUrl: String,
    private val credit: String,
    private val http: HttpClient = HttpClient(),
) : ImageSource {

    override suspend fun fetchRecent(limit: Int): List<CosmicImage> {
        val images = Rss.parse(http.fetchText(feedUrl))
            .filter { it.imageUrl != null && IMAGE_EXT.containsMatchIn(it.imageUrl) }
            .map { item ->
                val url = item.imageUrl!!
                CosmicImage(
                    id = "$id-$url",
                    title = item.title.ifEmpty { name },
                    credit = credit,
                    explanation = plainText(item.description).ifEmpty { null },
                    date = null,
                    sourceId = id,
                    pageUrl = item.link,
                    // The feed links the "screen" size; "large" is the crisp wallpaper.
                    imageUrl = url.replace("/screen/", "/large/").replace("/thumb/", "/large/"),
                    thumbUrl = url,
                    isVideo = false,
                    resolution = Resolution.UHD,
                )
            }
        if (images.isEmpty()) throw SourceException("The source returned no images.")
        return images.take(limit)
    }

    companion object {
        internal val IMAGE_EXT = Regex("\\.(jpe?g|png)", RegexOption.IGNORE_CASE)

        fun hubble(http: HttpClient = HttpClient()) = DjangoplicitySource(
            "hubble", "ESA/Hubble", "Picture of the Week", 0xFF8B7CFFL,
            "https://esahubble.org/images/potw/feed/", "ESA/Hubble & NASA", http,
        )

        fun webb(http: HttpClient = HttpClient()) = DjangoplicitySource(
            "webb", "James Webb", "ESA/Webb Images", 0xFFFFB45EL,
            "https://esawebb.org/images/feed/", "ESA/Webb, NASA & CSA", http,
        )

        fun eso(http: HttpClient = HttpClient()) = DjangoplicitySource(
            "eso", "ESO", "Picture of the Week", 0xFF5EF2B0L,
            "https://www.eso.org/public/images/potw/feed/", "ESO", http,
        )
    }
}

/** Minimal RSS/Atom reader: title, link, description and the first image enclosure. */
object Rss {
    data class Item(val title: String, val link: String?, val description: String?, val imageUrl: String?)

    private val ITEM = Regex("<(?:item|entry)\\b[^>]*>([\\s\\S]*?)</(?:item|entry)>", RegexOption.IGNORE_CASE)
    private val MEDIA = Regex("<(?:enclosure|media:content|media:thumbnail)\\b[^>]*>", RegexOption.IGNORE_CASE)
    private val URL_ATTR = Regex("\\burl=\"([^\"]+)\"", RegexOption.IGNORE_CASE)
    private val TYPE_ATTR = Regex("\\btype=\"([^\"]+)\"", RegexOption.IGNORE_CASE)
    private val HREF_LINK = Regex("<link\\b[^>]*href=\"([^\"]+)\"", RegexOption.IGNORE_CASE)
    private val CDATA = Regex("^\\s*<!\\[CDATA\\[([\\s\\S]*?)]]>\\s*$")

    fun parse(xml: String): List<Item> = ITEM.findAll(xml).map { match ->
        val body = match.groupValues[1]

        fun tag(name: String): String? {
            val m = Regex("<$name\\b[^>]*>([\\s\\S]*?)</$name>", RegexOption.IGNORE_CASE).find(body) ?: return null
            return CDATA.replace(m.groupValues[1], "$1").trim()
        }

        val imageUrl = MEDIA.findAll(body).firstNotNullOfOrNull { el ->
            val url = URL_ATTR.find(el.value)?.groupValues?.get(1)
            val type = TYPE_ATTR.find(el.value)?.groupValues?.get(1).orEmpty()
            if (url != null && (type.startsWith("image") || DjangoplicitySource.IMAGE_EXT.containsMatchIn(url))) {
                decodeEntities(url)
            } else {
                null
            }
        }
        val link = tag("link")?.takeIf { it.isNotEmpty() } ?: HREF_LINK.find(body)?.groupValues?.get(1)

        Item(
            title = plainText(tag("title")),
            link = link?.let(::decodeEntities),
            description = tag("description") ?: tag("summary"),
            imageUrl = imageUrl,
        )
    }.toList()
}
