package com.professorengineergit.caelum.data

import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import coil3.ImageLoader
import coil3.request.ImageRequest
import coil3.request.SuccessResult
import coil3.request.allowHardware
import coil3.size.Precision
import coil3.toBitmap
import com.professorengineergit.caelum.core.CosmicImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Downloads an image at a sensible size and makes it the wallpaper. */
class WallpaperSetter(
    private val context: Context,
    private val imageLoader: ImageLoader,
) {
    private val manager: WallpaperManager = WallpaperManager.getInstance(context)

    /** Whether this device lets apps change the wallpaper at all (some managed devices don't). */
    val isAllowed: Boolean
        get() = manager.isWallpaperSupported && manager.isSetWallpaperAllowed

    suspend fun apply(image: CosmicImage, target: WallpaperTarget) {
        check(isAllowed) { "This device doesn't allow changing the wallpaper." }
        val bitmap = download(image.imageUrl) ?: download(image.previewUrl)
            ?: error("The image couldn't be downloaded.")
        withContext(Dispatchers.IO) {
            val which = when (target) {
                WallpaperTarget.HOME -> WallpaperManager.FLAG_SYSTEM
                WallpaperTarget.LOCK -> WallpaperManager.FLAG_LOCK
                WallpaperTarget.BOTH -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
            }
            manager.setBitmap(bitmap, null, true, which)
        }
    }

    /**
     * Gigapixel originals (APOD has them) would exhaust memory, so the image is decoded
     * no larger than the wallpaper needs: the display's long edge, at most 4K.
     */
    private suspend fun download(url: String): Bitmap? {
        val metrics = context.resources.displayMetrics
        val longEdge = maxOf(metrics.widthPixels, metrics.heightPixels, manager.desiredMinimumHeight)
            .coerceIn(1080, 3840)
        val request = ImageRequest.Builder(context)
            .data(url)
            .size(longEdge, longEdge)
            .precision(Precision.INEXACT)
            .allowHardware(false)
            .build()
        return (imageLoader.execute(request) as? SuccessResult)?.image?.toBitmap()
    }
}
