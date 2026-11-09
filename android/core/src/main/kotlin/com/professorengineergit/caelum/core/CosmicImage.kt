package com.professorengineergit.caelum.core

/** How sharp an image is, by its longest edge. */
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
