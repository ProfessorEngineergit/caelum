package com.professorengineergit.caelum.ui.theme

import android.os.Build
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.tween
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialExpressiveTheme
import androidx.compose.material3.MotionScheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.materialkolor.hct.Hct
import com.materialkolor.scheme.SchemeNeutral
import com.materialkolor.scheme.SchemeVibrant
import com.materialkolor.toColorScheme
import com.professorengineergit.caelum.data.ColorMode

/** The Caelum void, used behind imagery and as the splash background. */
val Obsidian = Color(0xFF06070D)

/** The signature aurora sweep: cyan → violet → magenta. */
val Aurora = listOf(Color(0xFF5EE7FF), Color(0xFF8B7CFF), Color(0xFFFF6AD5))

/**
 * Material 3 Expressive with colours that follow the picture on screen: the scheme
 * is generated from [seed] (the image's most vibrant colour) and glides to each new
 * one, so the interface wears the cosmos like the desktop apps do.
 */
@Composable
fun CaelumTheme(
    seed: Color,
    colorMode: ColorMode,
    content: @Composable () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val target = remember(seed, colorMode, dark) {
        if (colorMode == ColorMode.SYSTEM && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        } else {
            cosmicColorScheme(seed, dark)
        }
    }

    MaterialExpressiveTheme(
        colorScheme = animateColorScheme(target),
        motionScheme = MotionScheme.expressive(),
        shapes = CaelumShapes,
        typography = CaelumTypography,
        content = content,
    )
}

/**
 * Accents from the picture, surfaces in a cool, neutral space grey — never tinted by
 * the picture, so warm photos can't turn the whole app brown.
 */
fun cosmicColorScheme(seed: Color, dark: Boolean): ColorScheme {
    val accents = SchemeVibrant(Hct.fromInt(seed.toArgb()), dark, 0.0).toColorScheme()
    val neutral = SchemeNeutral(Hct.from(255.0, 6.0, 50.0), dark, 0.0).toColorScheme()
    return accents.copy(
        background = neutral.background,
        onBackground = neutral.onBackground,
        surface = neutral.surface,
        onSurface = neutral.onSurface,
        surfaceVariant = neutral.surfaceVariant,
        onSurfaceVariant = neutral.onSurfaceVariant,
        inverseSurface = neutral.inverseSurface,
        inverseOnSurface = neutral.inverseOnSurface,
        outline = neutral.outline,
        outlineVariant = neutral.outlineVariant,
        surfaceBright = neutral.surfaceBright,
        surfaceDim = neutral.surfaceDim,
        surfaceContainer = neutral.surfaceContainer,
        surfaceContainerHigh = neutral.surfaceContainerHigh,
        surfaceContainerHighest = neutral.surfaceContainerHighest,
        surfaceContainerLow = neutral.surfaceContainerLow,
        surfaceContainerLowest = neutral.surfaceContainerLowest,
    )
}

/**
 * Whether a picture's colour is a good accent: grey, beige and brown photos (the Moon,
 * Mars, dust) aren't — the source's own colour stands in for them.
 */
fun isCosmicAccent(color: Color): Boolean {
    val hct = Hct.fromInt(color.toArgb())
    val warm = hct.hue in 20.0..100.0
    return hct.chroma >= 40.0 || (!warm && hct.chroma >= 18.0)
}

private val CaelumShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(20.dp),
    large = RoundedCornerShape(28.dp),
    extraLarge = RoundedCornerShape(40.dp),
)

private val CaelumTypography = Typography().run {
    copy(
        displayLarge = displayLarge.copy(fontWeight = FontWeight.Black, letterSpacing = (-1.5).sp),
        displayMedium = displayMedium.copy(fontWeight = FontWeight.Black, letterSpacing = (-1).sp),
        displaySmall = displaySmall.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.5).sp),
        headlineLarge = headlineLarge.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.5).sp),
        headlineMedium = headlineMedium.copy(fontWeight = FontWeight.Bold),
        headlineSmall = headlineSmall.copy(fontWeight = FontWeight.Bold),
        titleLarge = titleLarge.copy(fontWeight = FontWeight.Bold),
        titleMedium = titleMedium.copy(fontWeight = FontWeight.SemiBold),
        labelLarge = labelLarge.copy(fontWeight = FontWeight.SemiBold),
    )
}

@Composable
private fun animateColorScheme(target: ColorScheme): ColorScheme {
    return target.copy(
        primary = target.primary.animated(),
        onPrimary = target.onPrimary.animated(),
        primaryContainer = target.primaryContainer.animated(),
        onPrimaryContainer = target.onPrimaryContainer.animated(),
        inversePrimary = target.inversePrimary.animated(),
        secondary = target.secondary.animated(),
        onSecondary = target.onSecondary.animated(),
        secondaryContainer = target.secondaryContainer.animated(),
        onSecondaryContainer = target.onSecondaryContainer.animated(),
        tertiary = target.tertiary.animated(),
        onTertiary = target.onTertiary.animated(),
        tertiaryContainer = target.tertiaryContainer.animated(),
        onTertiaryContainer = target.onTertiaryContainer.animated(),
        background = target.background.animated(),
        onBackground = target.onBackground.animated(),
        surface = target.surface.animated(),
        onSurface = target.onSurface.animated(),
        surfaceVariant = target.surfaceVariant.animated(),
        onSurfaceVariant = target.onSurfaceVariant.animated(),
        surfaceTint = target.surfaceTint.animated(),
        outline = target.outline.animated(),
        outlineVariant = target.outlineVariant.animated(),
        surfaceBright = target.surfaceBright.animated(),
        surfaceDim = target.surfaceDim.animated(),
        surfaceContainer = target.surfaceContainer.animated(),
        surfaceContainerHigh = target.surfaceContainerHigh.animated(),
        surfaceContainerHighest = target.surfaceContainerHighest.animated(),
        surfaceContainerLow = target.surfaceContainerLow.animated(),
        surfaceContainerLowest = target.surfaceContainerLowest.animated(),
    )
}

private val SchemeSpec: AnimationSpec<Color> = tween(durationMillis = 700)

@Composable
private fun Color.animated(): Color = animateColorAsState(this, SchemeSpec, label = "scheme").value
