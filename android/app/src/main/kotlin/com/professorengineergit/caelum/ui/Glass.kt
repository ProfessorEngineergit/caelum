package com.professorengineergit.caelum.ui

import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.professorengineergit.caelum.ui.theme.Obsidian
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.HazeStyle
import dev.chrisbanes.haze.HazeTint
import dev.chrisbanes.haze.hazeEffect

/** Frosted glass over the picture: the image behind is blurred, then lightly tinted. */
val CosmicGlass = HazeStyle(
    backgroundColor = Obsidian,
    tint = HazeTint(Color.White.copy(alpha = 0.10f)),
    blurRadius = 18.dp,
    noiseFactor = 0.08f,
    // Below Android 12 there's no blur; a darker tint keeps text legible.
    fallbackTint = HazeTint(Obsidian.copy(alpha = 0.55f)),
)

/** A darker pane for panels that carry more text. */
val CosmicGlassDeep = HazeStyle(
    backgroundColor = Obsidian,
    tint = HazeTint(Obsidian.copy(alpha = 0.45f)),
    blurRadius = 28.dp,
    noiseFactor = 0.06f,
    fallbackTint = HazeTint(Obsidian.copy(alpha = 0.8f)),
)

fun Modifier.glass(state: HazeState, deep: Boolean = false): Modifier =
    hazeEffect(state = state, style = if (deep) CosmicGlassDeep else CosmicGlass)
