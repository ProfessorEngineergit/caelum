package com.professorengineergit.caelum.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The hand-curated galleries. Their data is `desktop/src/main/galleries.json`
 * (generated from `StaticGallerySource.swift`), copied in at build time.
 */
class GallerySource(
    private val gallery: Gallery,
    private val now: () -> Long = System::currentTimeMillis,
) : ImageSource {
    override val id get() = gallery.id
    override val name get() = gallery.name
    override val subtitle get() = gallery.subtitle
    override val accent get() = parseHexColor(gallery.accent)

    override suspend fun fetchRecent(limit: Int): List<CosmicImage> {
        val assets = gallery.assets
        if (assets.isEmpty()) throw SourceException("The source returned no images.")
        // Rotates daily for variety, deterministic within a day.
        val offset = ((now() / 86_400_000L) % assets.size).toInt()
        val rotated = assets.drop(offset) + assets.take(offset)
        return rotated.take(maxOf(limit, 1)).map { a ->
            CosmicImage(
                id = "${gallery.id}-${a.identifier}",
                title = a.title,
                credit = a.credit,
                explanation = a.explanation,
                date = a.date,
                sourceId = gallery.id,
                pageUrl = a.pageURL,
                imageUrl = a.imageURL,
                thumbUrl = a.thumbURL,
                isVideo = false,
                resolution = Resolution.entries.firstOrNull { it.label == a.resolution } ?: Resolution.UHD,
            )
        }
    }

    @Serializable
    data class Gallery(
        val id: String,
        val name: String,
        val subtitle: String,
        val accent: String,
        val assets: List<Asset>,
    )

    @Serializable
    data class Asset(
        val identifier: String,
        val title: String,
        val credit: String,
        val explanation: String? = null,
        val imageURL: String,
        val thumbURL: String? = null,
        val pageURL: String? = null,
        val resolution: String? = null,
        val date: String? = null,
    )

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        /** Every gallery bundled with the app, in display order. */
        fun bundled(): List<GallerySource> {
            val stream = GallerySource::class.java.getResourceAsStream("/galleries.json")
                ?: error("galleries.json is missing from the build")
            val text = stream.bufferedReader().use { it.readText() }
            return json.decodeFromString<List<Gallery>>(text).map { GallerySource(it) }
        }
    }
}
