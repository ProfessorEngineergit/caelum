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
import com.professorengineergit.caelum.data.FeedCache
import com.professorengineergit.caelum.data.SettingsRepository
import com.professorengineergit.caelum.data.WallpaperSetter
import com.professorengineergit.caelum.work.DailyWallpaper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import okhttp3.Dispatcher
import okhttp3.Dns
import okhttp3.OkHttpClient
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.UnknownHostException

/** The app's few long-lived objects, created once. */
class AppContainer(context: Context) {
    val okHttp: OkHttpClient = HttpClient.defaultClient().newBuilder()
        .dns(PublicOnlyDns)
        // Many thumbnails come from the same CDN at once; don't queue them five at a time.
        .dispatcher(Dispatcher().apply { maxRequests = 48; maxRequestsPerHost = 16 })
        .addInterceptor { chain ->
            chain.proceed(chain.request().newBuilder().header("User-Agent", USER_AGENT).build())
        }
        .build()

    val sources = SourceRegistry(HttpClient(okHttp))
    val settings = SettingsRepository(context)
    val feedCache = FeedCache(context)

    val imageLoader: ImageLoader = ImageLoader.Builder(context)
        .components { add(OkHttpNetworkFetcherFactory(okHttp)) }
        .diskCache {
            DiskCache.Builder()
                .directory(context.cacheDir.resolve("images"))
                .maxSizeBytes(256L * 1024 * 1024)
                .build()
        }
        .crossfade(160)
        .build()

    val wallpaper = WallpaperSetter(context, imageLoader)
}

/**
 * Caelum only ever talks to public servers. Should a name resolve to an address in the
 * local network — a DNS ad blocker answering with a router or 0.0.0.0 address, say —
 * the connection is refused instead of made, so Android never has a reason to ask for
 * local network access.
 */
private object PublicOnlyDns : Dns {
    override fun lookup(hostname: String): List<InetAddress> {
        val public = Dns.SYSTEM.lookup(hostname).filterNot { a ->
            a.isAnyLocalAddress || a.isLoopbackAddress || a.isLinkLocalAddress ||
                a.isSiteLocalAddress || a.isMulticastAddress || a.isUniqueLocalV6() || a.isCarrierGradeNat()
        }
        if (public.isEmpty()) throw UnknownHostException("$hostname has no public address")
        return public
    }

    /** fc00::/7 */
    private fun InetAddress.isUniqueLocalV6() = this is Inet6Address && (address[0].toInt() and 0xFE) == 0xFC

    /** 100.64.0.0/10 */
    private fun InetAddress.isCarrierGradeNat() =
        this is Inet4Address && address[0].toInt() and 0xFF == 100 && (address[1].toInt() and 0xC0) == 64
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
