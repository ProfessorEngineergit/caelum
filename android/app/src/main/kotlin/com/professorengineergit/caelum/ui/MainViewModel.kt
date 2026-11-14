package com.professorengineergit.caelum.ui

import android.app.Application
import android.net.ConnectivityManager
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.professorengineergit.caelum.container
import com.professorengineergit.caelum.core.CosmicImage
import com.professorengineergit.caelum.core.ImageSource
import com.professorengineergit.caelum.data.ColorMode
import com.professorengineergit.caelum.data.Settings
import com.professorengineergit.caelum.data.WallpaperTarget
import com.professorengineergit.caelum.data.toImage
import com.professorengineergit.caelum.work.DailyWallpaper
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** What one source's feed looks like right now. */
sealed interface Feed {
    data object Loading : Feed
    data class Ready(val images: List<CosmicImage>) : Feed
    data class Failed(val message: String?) : Feed
}

data class UiState(
    val sources: List<ImageSource>,
    val settings: Settings = Settings(),
    val feeds: Map<String, Feed> = emptyMap(),
    /** The picture picked in each source's carousel; the newest when absent. */
    val picked: Map<String, String> = emptyMap(),
    /** The wallpaper being set right now (drives the warp animation); null when idle. */
    val apply: ApplyState? = null,
    /** False until the stored settings have been read, so the first frame doesn't flash APOD. */
    val loaded: Boolean = false,
) {
    val source: ImageSource get() = sources.firstOrNull { it.id == settings.sourceId } ?: sources.first()
    val feed: Feed get() = feeds[source.id] ?: Feed.Loading
    val images: List<CosmicImage> get() = (feed as? Feed.Ready)?.images.orEmpty()
    val image: CosmicImage? get() = images.firstOrNull { it.id == picked[source.id] } ?: images.firstOrNull()
    val applying: Boolean get() = apply?.status == ApplyStatus.RUNNING
}

enum class ApplyStatus { RUNNING, DONE, FAILED }

data class ApplyState(
    val image: CosmicImage,
    val target: WallpaperTarget,
    val status: ApplyStatus = ApplyStatus.RUNNING,
    val startedAt: Long = System.currentTimeMillis(),
)

sealed interface UserMessage {
    data class WallpaperSet(val target: WallpaperTarget) : UserMessage
    data class Failed(val reason: String?) : UserMessage
}

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val container = application.container
    private val settingsRepo = container.settings

    private val local = MutableStateFlow(UiState(sources = container.sources.all))

    val state: StateFlow<UiState> = combine(local, settingsRepo.settings) { state, settings ->
        state.copy(settings = settings, loaded = true)
    }.stateIn(viewModelScope, SharingStarted.Eagerly, local.value)

    private val _messages = Channel<UserMessage>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()

    init {
        viewModelScope.launch {
            settingsRepo.settings.collect { load(it.sourceId) }
        }
        // Every source's newest picture becomes its tile in the picker.
        viewModelScope.launch {
            container.sources.all.forEach { load(it.id) }
        }
        // Catch up on a night the system skipped, whenever the app is opened.
        viewModelScope.launch {
            if (settingsRepo.current().dailyEnabled) DailyWallpaper.runNow(getApplication())
        }
        // Get the picture on screen ready to be a wallpaper while the user looks at it,
        // so "Set as wallpaper" is near-instant. Only on Wi-Fi: originals can be large.
        viewModelScope.launch {
            state
                .map { it.image to it.settings.wallpaperScrolling }
                .distinctUntilChanged()
                .collectLatest { (image, scrolling) ->
                    if (image == null || image.isVideo) return@collectLatest
                    // Wait until the user lingers, so thumbnails get the bandwidth first.
                    delay(3500)
                    if (isUnmetered()) container.wallpaper.prepare(image, scrolling)
                }
        }
    }

    private fun isUnmetered(): Boolean {
        val cm = getApplication<Application>().getSystemService(ConnectivityManager::class.java) ?: return false
        return !cm.isActiveNetworkMetered
    }

    /** The user is about to choose a target: start preparing the picture regardless of network. */
    fun prepareCurrent() {
        val s = state.value
        val image = s.image ?: return
        if (!image.isVideo) container.wallpaper.prepare(image, s.settings.wallpaperScrolling)
    }

    fun selectSource(id: String) {
        viewModelScope.launch {
            settingsRepo.setSource(id)
            if (settingsRepo.current().dailyEnabled) DailyWallpaper.runNow(getApplication())
        }
    }

    fun pick(image: CosmicImage) {
        local.update { it.copy(picked = it.picked + (image.sourceId to image.id)) }
    }

    /** Steps to the next ([step] = 1) or previous (-1) picture of the current source. */
    fun step(step: Int) {
        val s = state.value
        val index = s.images.indexOfFirst { it.id == s.image?.id }
        s.images.getOrNull(index + step)?.let(::pick)
    }

    fun refresh() = load(state.value.source.id, force = true)

    /**
     * Shows the cached list at once (if there is one), then replaces it with a fresh one.
     * A failed refresh keeps what's on screen; only an empty screen shows the error.
     */
    private fun load(sourceId: String, force: Boolean = false) {
        val current = local.value.feeds[sourceId]
        if (!force && current != null && current !is Feed.Failed) return
        if (current !is Feed.Ready) local.update { it.copy(feeds = it.feeds + (sourceId to Feed.Loading)) }
        viewModelScope.launch {
            if (current == null) {
                container.feedCache.read(sourceId)?.let { cached ->
                    local.update { s ->
                        if (s.feeds[sourceId] is Feed.Ready) s else s.copy(feeds = s.feeds + (sourceId to Feed.Ready(cached)))
                    }
                }
            }
            val fresh = try {
                container.sources.byId(sourceId).fetchRecent(12)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                local.update { s ->
                    if (s.feeds[sourceId] is Feed.Ready) s else s.copy(feeds = s.feeds + (sourceId to Feed.Failed(e.message)))
                }
                return@launch
            }
            local.update { it.copy(feeds = it.feeds + (sourceId to Feed.Ready(fresh))) }
            container.feedCache.write(sourceId, fresh)
        }
    }

    fun setWallpaper(target: WallpaperTarget) = setWallpaper(state.value.image, target)

    fun setWallpaper(image: CosmicImage?, target: WallpaperTarget) {
        image ?: return
        if (state.value.applying) return
        local.update { it.copy(apply = ApplyState(image, target)) }
        viewModelScope.launch {
            val failure = try {
                container.wallpaper.apply(image, target, settingsRepo.current().wallpaperScrolling)
                settingsRepo.recordApplied(image, target)
                null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                UserMessage.Failed(e.message)
            }
            local.update { s ->
                s.copy(apply = s.apply?.copy(status = if (failure == null) ApplyStatus.DONE else ApplyStatus.FAILED))
            }
            failure?.let { _messages.send(it) }
        }
    }

    /** The warp animation has played out. */
    fun finishApply() {
        local.update { if (it.apply?.status != ApplyStatus.RUNNING) it.copy(apply = null) else it }
    }

    fun setDailyEnabled(enabled: Boolean) = viewModelScope.launch {
        settingsRepo.setDailyEnabled(enabled)
        if (enabled) DailyWallpaper.runNow(getApplication())
    }

    fun setDailyTarget(target: WallpaperTarget) = viewModelScope.launch { settingsRepo.setDailyTarget(target) }
    fun setUnmeteredOnly(value: Boolean) = viewModelScope.launch { settingsRepo.setUnmeteredOnly(value) }
    fun setColorMode(mode: ColorMode) = viewModelScope.launch { settingsRepo.setColorMode(mode) }
    /**
     * Changing the crop only matters for a wallpaper set afterwards — so the current one
     * is set again right away, with the new crop, and the change is visible at once.
     */
    fun setWallpaperScrolling(value: Boolean) = viewModelScope.launch {
        settingsRepo.setWallpaperScrolling(value)
        val last = settingsRepo.current().lastApplied ?: return@launch
        setWallpaper(last.toImage(), last.target)
    }
    fun setHaptics(value: Boolean) = viewModelScope.launch { settingsRepo.setHaptics(value) }

}
