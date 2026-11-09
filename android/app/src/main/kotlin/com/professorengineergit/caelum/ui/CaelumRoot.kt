package com.professorengineergit.caelum.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.IntOffset
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.palette.graphics.Palette
import coil3.imageLoader
import coil3.request.ImageRequest
import coil3.request.SuccessResult
import coil3.request.allowHardware
import coil3.toBitmap
import com.professorengineergit.caelum.core.CosmicImage
import com.professorengineergit.caelum.ui.theme.CaelumTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private enum class Screen { HOME, SETTINGS }

@Composable
fun CaelumRoot(viewModel: MainViewModel) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val seed by rememberSeedColor(state.image, fallback = Color(state.source.accent))

    CaelumTheme(seed = seed, colorMode = state.settings.colorMode) {
        var screen by rememberSaveable { mutableStateOf(Screen.HOME) }
        BackHandler(enabled = screen != Screen.HOME) { screen = Screen.HOME }

        val spatial = MaterialTheme.motionScheme.defaultSpatialSpec<IntOffset>()
        val effects = MaterialTheme.motionScheme.defaultEffectsSpec<Float>()
        AnimatedContent(
            targetState = screen,
            transitionSpec = {
                val forward = targetState == Screen.SETTINGS
                (slideInHorizontally(spatial) { if (forward) it / 3 else -it / 3 } + fadeIn(effects))
                    .togetherWith(slideOutHorizontally(spatial) { if (forward) -it / 3 else it / 3 } + fadeOut(effects))
            },
            label = "screen",
        ) { current ->
            when (current) {
                Screen.HOME -> HomeScreen(
                    state = state,
                    messages = viewModel.messages,
                    onSelectSource = viewModel::selectSource,
                    onPick = viewModel::pick,
                    onRetry = viewModel::refresh,
                    onSetWallpaper = viewModel::setWallpaper,
                    onOpenSettings = { screen = Screen.SETTINGS },
                )
                Screen.SETTINGS -> SettingsScreen(
                    state = state,
                    onBack = { screen = Screen.HOME },
                    onDailyEnabled = { viewModel.setDailyEnabled(it) },
                    onDailyTarget = { viewModel.setDailyTarget(it) },
                    onUnmeteredOnly = { viewModel.setUnmeteredOnly(it) },
                    onColorMode = { viewModel.setColorMode(it) },
                )
            }
        }
    }
}

/**
 * The most vibrant colour of [image], read from a tiny copy of its preview; the
 * source's accent until it's known.
 */
@Composable
private fun rememberSeedColor(image: CosmicImage?, fallback: Color): State<Color> {
    val context = LocalContext.current
    return produceState(initialValue = fallback, image?.id, fallback) {
        if (image == null) {
            value = fallback
            return@produceState
        }
        val request = ImageRequest.Builder(context)
            .data(image.previewUrl)
            .size(96)
            .allowHardware(false)
            .build()
        val bitmap = (context.imageLoader.execute(request) as? SuccessResult)?.image?.toBitmap()
            ?: return@produceState
        val swatch = withContext(Dispatchers.Default) {
            Palette.from(bitmap).generate().let { it.vibrantSwatch ?: it.lightVibrantSwatch ?: it.dominantSwatch }
        }
        value = swatch?.let { Color(it.rgb) } ?: fallback
    }
}
