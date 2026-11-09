package com.professorengineergit.caelum.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.professorengineergit.caelum.container
import com.professorengineergit.caelum.core.CosmicImage
import com.professorengineergit.caelum.core.ImageSource
import com.professorengineergit.caelum.data.ColorMode
import com.professorengineergit.caelum.data.Settings
import com.professorengineergit.caelum.data.WallpaperTarget
import com.professorengineergit.caelum.work.DailyWallpaper
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
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
    val applying: Boolean = false,
    /** False until the stored settings have been read, so the first frame doesn't flash APOD. */
    val loaded: Boolean = false,
) {
    val source: ImageSource get() = sources.firstOrNull { it.id == settings.sourceId } ?: sources.first()
    val feed: Feed get() = feeds[source.id] ?: Feed.Loading
    val images: List<CosmicImage> get() = (feed as? Feed.Ready)?.images.orEmpty()
    val image: CosmicImage? get() = images.firstOrNull { it.id == picked[source.id] } ?: images.firstOrNull()
}

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

    fun refresh() = load(state.value.source.id, force = true)

    private fun load(sourceId: String, force: Boolean = false) {
        val current = local.value.feeds[sourceId]
        if (!force && current != null && current !is Feed.Failed) return
        local.update { it.copy(feeds = it.feeds + (sourceId to Feed.Loading)) }
        viewModelScope.launch {
            val feed = try {
                Feed.Ready(container.sources.byId(sourceId).fetchRecent(12))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Feed.Failed(e.message)
            }
            local.update { it.copy(feeds = it.feeds + (sourceId to feed)) }
        }
    }

    fun setWallpaper(target: WallpaperTarget) {
        val image = state.value.image ?: return
        if (state.value.applying) return
        local.update { it.copy(applying = true) }
        viewModelScope.launch {
            val message = try {
                container.wallpaper.apply(image, target)
                UserMessage.WallpaperSet(target)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                UserMessage.Failed(e.message)
            }
            local.update { it.copy(applying = false) }
            _messages.send(message)
        }
    }

    fun setDailyEnabled(enabled: Boolean) = viewModelScope.launch {
        settingsRepo.setDailyEnabled(enabled)
        if (enabled) DailyWallpaper.runNow(getApplication())
    }

    fun setDailyTarget(target: WallpaperTarget) = viewModelScope.launch { settingsRepo.setDailyTarget(target) }
    fun setUnmeteredOnly(value: Boolean) = viewModelScope.launch { settingsRepo.setUnmeteredOnly(value) }
    fun setColorMode(mode: ColorMode) = viewModelScope.launch { settingsRepo.setColorMode(mode) }
}
