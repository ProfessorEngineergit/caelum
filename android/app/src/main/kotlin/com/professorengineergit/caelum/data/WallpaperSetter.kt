package com.professorengineergit.caelum.data

import android.app.WallpaperColors
import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Display
import coil3.ImageLoader
import coil3.request.CachePolicy
import coil3.request.ImageRequest
import coil3.request.SuccessResult
import coil3.request.allowHardware
import coil3.size.Precision
import coil3.size.Scale
import coil3.toBitmap
import com.professorengineergit.caelum.core.CosmicImage
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.selects.select
import kotlinx.coroutines.withContext
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Turns a picture into a wallpaper, quickly.
 *
 * What used to make it slow: the full original was downloaded only after the tap, and
 * `setBitmap` re-compresses the whole bitmap to PNG on the main path — seconds for a
 * 4K photo. Now the picture is prepared ahead ([prepare], started as soon as the user
 * looks at it) into a screen-sized JPEG, and handed over with `setStream`.
 */
class WallpaperSetter(
    private val context: Context,
    private val imageLoader: ImageLoader,
) {
    private val manager: WallpaperManager = WallpaperManager.getInstance(context)

    /** Outlives screens and view models: a wallpaper being written is finished even if the app closes. */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    /** The last few prepared pictures, keyed by image and crop. */
    private val prepared = object : LinkedHashMap<String, Deferred<ByteArray>>(4, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Deferred<ByteArray>>?) = size > 3
    }

    /** Whether this device lets apps change the wallpaper at all (some managed devices don't). */
    val isAllowed: Boolean
        get() = manager.isWallpaperSupported && manager.isSetWallpaperAllowed

    /** Starts downloading and cropping [image] in the background, so a later [apply] is instant. */
    fun prepare(image: CosmicImage, scrolling: Boolean): Deferred<ByteArray> = synchronized(prepared) {
        val key = "${image.id}|$scrolling"
        prepared[key]?.takeUnless { it.isCancelled }
            ?: scope.async { render(image, scrolling) }.also { prepared[key] = it }
    }

    /**
     * Sets [image] as the wallpaper. Returns as soon as the system has it — when its
     * colours change, which on some skins comes well before `setStream` returns — while
     * the write itself always runs to the end.
     */
    suspend fun apply(image: CosmicImage, target: WallpaperTarget, scrolling: Boolean) {
        check(isAllowed) { "This device doesn't allow changing the wallpaper." }
        val jpeg = prepare(image, scrolling).await()
        val which = when (target) {
            WallpaperTarget.HOME -> WallpaperManager.FLAG_SYSTEM
            WallpaperTarget.LOCK -> WallpaperManager.FLAG_LOCK
            WallpaperTarget.BOTH -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
        }

        val colorsChanged = CompletableDeferred<Unit>()
        val listener = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            WallpaperManager.OnColorsChangedListener { _: WallpaperColors?, flags: Int ->
                if (flags and which != 0) colorsChanged.complete(Unit)
            }.also { manager.addOnColorsChangedListener(it, Handler(Looper.getMainLooper())) }
        } else {
            null
        }

        val write = scope.async(Dispatchers.IO) {
            manager.setStream(ByteArrayInputStream(jpeg), null, true, which)
        }
        try {
            select {
                write.onAwait { }
                colorsChanged.onAwait { }
            }
            // Surface a failed write even when the colours changed first.
            if (write.isCompleted) write.await()
        } finally {
            if (listener != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                // Leave the listener until the write ends, then tidy up.
                scope.launch {
                    runCatching { write.await() }
                    manager.removeOnColorsChangedListener(listener)
                }
            }
        }
    }

    // MARK: - Rendering

    private suspend fun render(image: CosmicImage, scrolling: Boolean): ByteArray {
        val (screenW, screenH) = screenSize()
        val source = download(image.imageUrl, screenW, screenH)
            ?: download(image.previewUrl, screenW, screenH)
            ?: error("The image couldn't be downloaded.")
        return withContext(Dispatchers.Default) {
            val fitted = fit(source, screenW, screenH, scrolling)
            ByteArrayOutputStream(fitted.byteCount / 6).use { out ->
                fitted.compress(Bitmap.CompressFormat.JPEG, 94, out)
                if (fitted !== source) fitted.recycle()
                out.toByteArray()
            }
        }
    }

    /**
     * Scales [src] to cover the screen. Without [scrolling] it is centre-cropped to
     * exactly the screen, so the launcher has nothing to scroll; with it, the full
     * width is kept (up to twice the screen) for the parallax effect.
     */
    private fun fit(src: Bitmap, screenW: Int, screenH: Int, scrolling: Boolean): Bitmap {
        val scale = max(screenW.toFloat() / src.width, screenH.toFloat() / src.height)
        val scaledW = (src.width * scale).roundToInt()
        val outW = if (scrolling) scaledW.coerceIn(screenW, screenW * 2) else screenW
        val outH = screenH
        if (src.width == outW && src.height == outH) return src

        val visibleW = outW / scale
        val visibleH = outH / scale
        val left = ((src.width - visibleW) / 2f).roundToInt().coerceAtLeast(0)
        val top = ((src.height - visibleH) / 2f).roundToInt().coerceAtLeast(0)
        val srcRect = Rect(left, top, (left + visibleW.roundToInt()).coerceAtMost(src.width), (top + visibleH.roundToInt()).coerceAtMost(src.height))

        val out = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(src, srcRect, Rect(0, 0, outW, outH), Paint(Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG))
        return out
    }

    /** The physical screen in portrait, system bars included. */
    @Suppress("DEPRECATION")
    private fun screenSize(): Pair<Int, Int> {
        val display = context.getSystemService(DisplayManager::class.java)?.getDisplay(Display.DEFAULT_DISPLAY)
        val metrics = DisplayMetrics()
        if (display != null) display.getRealMetrics(metrics) else metrics.setTo(context.resources.displayMetrics)
        val w = minOf(metrics.widthPixels, metrics.heightPixels).coerceAtLeast(720)
        val h = maxOf(metrics.widthPixels, metrics.heightPixels).coerceAtLeast(1280)
        return w to h
    }

    /**
     * Gigapixel originals (APOD has them) would exhaust memory, so the image is decoded
     * just large enough to cover the screen, never larger than 4K on its long edge.
     */
    private suspend fun download(url: String, screenW: Int, screenH: Int): Bitmap? {
        val request = ImageRequest.Builder(context)
            .data(url)
            .size(screenW.coerceAtMost(3840), screenH.coerceAtMost(3840))
            .scale(Scale.FILL)
            .precision(Precision.INEXACT)
            .allowHardware(false)
            .memoryCachePolicy(CachePolicy.DISABLED)
            .build()
        return (imageLoader.execute(request) as? SuccessResult)?.image?.toBitmap()
    }
}
