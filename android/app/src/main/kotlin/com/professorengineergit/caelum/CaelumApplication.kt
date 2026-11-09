package com.professorengineergit.caelum

import android.app.Application
import android.content.Context
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.disk.DiskCache
import coil3.disk.directory
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import coil3.request.crossfade
import com.professorengineergit.caelum.core.HttpClient
import com.professorengineergit.caelum.core.SourceRegistry
import com.professorengineergit.caelum.core.USER_AGENT
import com.professorengineergit.caelum.data.SettingsRepository
import com.professorengineergit.caelum.data.WallpaperSetter
import com.professorengineergit.caelum.work.DailyWallpaper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient

/** The app's few long-lived objects, created once. */
class AppContainer(context: Context) {
    val okHttp: OkHttpClient = HttpClient.defaultClient().newBuilder()
        .addInterceptor { chain ->
            chain.proceed(chain.request().newBuilder().header("User-Agent", USER_AGENT).build())
        }
        .build()

    val sources = SourceRegistry(HttpClient(okHttp))
    val settings = SettingsRepository(context)

    val imageLoader: ImageLoader = ImageLoader.Builder(context)
        .components { add(OkHttpNetworkFetcherFactory(okHttp)) }
        .diskCache {
            DiskCache.Builder()
                .directory(context.cacheDir.resolve("images"))
                .maxSizeBytes(256L * 1024 * 1024)
                .build()
        }
        .crossfade(true)
        .build()

    val wallpaper = WallpaperSetter(context, imageLoader)
}

class CaelumApplication : Application(), SingletonImageLoader.Factory {
    lateinit var container: AppContainer
        private set

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)

        // Keep the daily job in step with the settings, wherever they change.
        scope.launch {
            container.settings.settings
                .map { it.dailyEnabled to it.unmeteredOnly }
                .distinctUntilChanged()
                .collect { (enabled, unmetered) -> DailyWallpaper.schedule(this@CaelumApplication, enabled, unmetered) }
        }
    }

    override fun newImageLoader(context: PlatformContext): ImageLoader = container.imageLoader
}

val Context.container: AppContainer
    get() = (applicationContext as CaelumApplication).container
