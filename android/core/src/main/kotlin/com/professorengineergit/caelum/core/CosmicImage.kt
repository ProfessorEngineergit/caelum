package com.professorengineergit.caelum.core

import kotlinx.serialization.Serializable

/** How sharp an image is, by its longest edge. */
@Serializable
enum class Resolution(val label: String) {
    UHD("4K"), HD("HD"), SD("SD");

    companion object {
        fun classify(width: Int, height: Int): Resolution {
            val longest = maxOf(width, height)
            return when {
                longest >= 3840 -> UHD
                longest >= 1920 -> HD
                else -> SD
            }
        }
    }
}

/**
 * One picture from one source — the Android twin of `CosmicImage` in the macOS app
 * and of the objects `desktop/src/main/sources.js` returns.
 */
@Serializable
data class CosmicImage(
    val id: String,
    val title: String,
    val credit: String,
    val explanation: String?,
    /** `yyyy-MM-dd`, or null for undated sources. */
    val date: String?,
    val sourceId: String,
    val pageUrl: String?,
    /** Full-resolution image, used for the wallpaper. */
    val imageUrl: String,
    /** Smaller preview, if the source has one. */
    val thumbUrl: String?,
    val isVideo: Boolean,
    val resolution: Resolution,
) {
    val previewUrl: String get() = thumbUrl ?: imageUrl

    /**
     * A small copy for tiles and thumbnails (roughly [small] ? 300 : 700 px wide), using
     * the size variants every source's CDN offers; the preview when there's none.
     */
    fun thumbnailUrl(small: Boolean = false): String = smallerVariant(previewUrl, small)
}

internal fun smallerVariant(url: String, small: Boolean): String = when {
    // ESA/Hubble, ESA/Webb and ESO (Djangoplicity): …/images/screen/x.jpg
    "/images/screen/" in url -> url.replace("/images/screen/", if (small) "/images/thumb300y/" else "/images/thumb700x/")
    // NASA Image Library: x~medium.jpg (~640 px) → x~small.jpg
    "images-assets.nasa.gov" in url && small -> url.replace("~medium.", "~small.").replace("~orig.", "~small.")
    "images-assets.nasa.gov" in url -> url.replace("~orig.", "~medium.")
    // APOD on NASA's resizing CDN: ask it for a narrow copy.
    "/dynamicimage/" in url -> url.substringBefore('?') + "?w=" + (if (small) 320 else 720) + "&fit=clip"
    else -> url
}

/** A library of images, such as NASA APOD or a curated gallery. */
interface ImageSource {
    val id: String
    val name: String
    val subtitle: String
    /** Brand accent as 0xAARRGGBB. */
    val accent: Long

    /** Newest (or today's) images first. */
    suspend fun fetchRecent(limit: Int = 12): List<CosmicImage>
}

class SourceException(message: String) : Exception(message)

internal fun parseHexColor(hex: String): Long =
    0xFF000000L or hex.removePrefix("#").toLong(16)
