package com.professorengineergit.caelum.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.util.lerp
import coil3.compose.AsyncImage
import com.professorengineergit.caelum.R
import com.professorengineergit.caelum.data.WallpaperTarget
import com.professorengineergit.caelum.ui.theme.Obsidian
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * The jump to hyperspace that plays while a wallpaper is set (about two seconds once
 * the system has it):
 *
 *  1. the picture shrinks into a phone-shaped portal while stars streak past, the
 *     engine's haptic pulse speeding up for as long as the system needs;
 *  2. on arrival the portal bursts to full screen with a shockwave and a deep thud;
 *  3. for the home screen the app then turns see-through for a moment, showing your
 *     real, new wallpaper behind it — the system's own, not a copy.
 *
 * @param onShowSystemWallpaper asks the window to draw the system wallpaper behind the app.
 * @param onHideContent hides (true) or restores the app's own content.
 */
@Composable
fun WarpOverlay(
    apply: ApplyState?,
    onShowSystemWallpaper: (Boolean) -> Unit,
    onHideContent: (Boolean) -> Unit,
    onFinished: () -> Unit,
) {
    if (apply == null) return
    val haptics = LocalHaptics.current
    // Whatever happens, never leave the app see-through.
    DisposableEffect(apply.startedAt) {
        onDispose {
            onHideContent(false)
            onShowSystemWallpaper(false)
        }
    }
    val current by rememberUpdatedState(apply)

    val backdrop = remember(apply.startedAt) { Animatable(0f) }
    val portalIn = remember(apply.startedAt) { Animatable(0f) }
    val expand = remember(apply.startedAt) { Animatable(0f) }
    val warp = remember(apply.startedAt) { Animatable(0f) }
    val shock = remember(apply.startedAt) { Animatable(0f) }
    val portalAlpha = remember(apply.startedAt) { Animatable(1f) }
    val shake = remember(apply.startedAt) { Animatable(0f) }
    var time by remember(apply.startedAt) { mutableFloatStateOf(0f) }
    var showLabel by remember(apply.startedAt) { mutableStateOf(false) }

    // The clock that drives the starfield.
    LaunchedEffect(apply.startedAt) {
        val start = withFrameNanos { it }
        while (isActive) {
            withFrameNanos { now -> time = (now - start) / 1_000_000_000f }
        }
    }

    LaunchedEffect(apply.startedAt) {
        val revealsHome = apply.target != WallpaperTarget.LOCK
        if (revealsHome) onShowSystemWallpaper(true)

        // 1. Into the portal.
        haptics.ignite()
        launch { backdrop.animateTo(1f, tween(260)) }
        launch { warp.animateTo(1f, tween(1100, easing = FastOutSlowInEasing)) }
        portalIn.animateTo(1f, spring(dampingRatio = 0.62f, stiffness = Spring.StiffnessMediumLow))

        // The engine hums, faster and stronger, until the system has the wallpaper.
        val engine = launch {
            var beat = 0
            while (isActive) {
                haptics.warpPulse(min(1f, beat / 12f))
                delay(max(55L, 150L - beat * 9L))
                beat++
            }
        }
        snapshotFlow { current.status }.first { it != ApplyStatus.RUNNING }
        val elapsed = System.currentTimeMillis() - apply.startedAt
        if (elapsed < 750) delay(750 - elapsed)
        engine.cancel()

        if (current.status == ApplyStatus.FAILED) {
            // A sputter: the portal shakes, then fades.
            haptics.error()
            launch { warp.animateTo(0f, tween(400)) }
            for (x in listOf(18f, -16f, 12f, -8f, 4f, 0f)) shake.animateTo(x, tween(45, easing = LinearEasing))
            launch { portalAlpha.animateTo(0f, tween(250)) }
            backdrop.animateTo(0f, tween(320))
            onShowSystemWallpaper(false)
            onFinished()
            return@LaunchedEffect
        }

        // 2. Arrival.
        haptics.land()
        launch { shock.animateTo(1f, tween(700, easing = FastOutSlowInEasing)) }
        launch { warp.animateTo(0f, tween(450)) }
        expand.animateTo(1f, spring(dampingRatio = 0.78f, stiffness = Spring.StiffnessMediumLow))
        showLabel = true
        haptics.tick(0.7f)

        if (revealsHome) {
            // 3. The app steps aside: the real home wallpaper shows through.
            onHideContent(true)
            launch { backdrop.animateTo(0f, tween(420)) }
            portalAlpha.animateTo(0f, tween(420))
            delay(1100)
            onHideContent(false)
            showLabel = false
            delay(380)
            onShowSystemWallpaper(false)
        } else {
            delay(900)
            showLabel = false
            launch { portalAlpha.animateTo(0f, tween(320)) }
            backdrop.animateTo(0f, tween(320))
        }
        onFinished()
    }

    val starSeeds = remember { List(120) { Star(Random(it)) } }
    val accent = MaterialTheme.colorScheme.primary

    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            // Swallow touches while the animation plays.
            .pointerInput(Unit) { detectTapGestures { } },
    ) {
        val full = maxWidth to maxHeight
        // Backdrop and starfield.
        Canvas(Modifier.fillMaxSize().graphicsLayer { alpha = backdrop.value }) {
            drawRect(Obsidian)
            val c = center
            val reach = size.maxDimension * 0.75f
            val speed = warp.value
            for (star in starSeeds) {
                val travel = ((star.offset + time * (0.15f + 1.4f * speed) * star.speed) % 1f)
                val d = travel * travel
                val r1 = reach * d
                val r0 = max(0f, r1 - reach * (0.01f + 0.22f * speed) * d)
                val dir = Offset(cos(star.angle), sin(star.angle))
                val color = if (star.tinted) accent else Color.White
                drawLine(
                    color.copy(alpha = (0.25f + 0.75f * d).coerceAtMost(1f)),
                    c + dir * r0,
                    c + dir * r1,
                    strokeWidth = 1.5f + 3.5f * d,
                    cap = StrokeCap.Round,
                )
            }
            // Shockwave on arrival.
            if (shock.value > 0f && shock.value < 1f) {
                drawCircle(
                    Color.White.copy(alpha = (1f - shock.value) * 0.9f),
                    radius = size.maxDimension * 0.75f * shock.value,
                    center = c,
                    style = Stroke(width = 28f * (1f - shock.value) + 2f),
                )
            }
        }

        // The portal: a phone-shaped window onto the picture that becomes the whole screen.
        val e = expand.value
        val portalW = lerp(full.first.value * 0.5f, full.first.value, e).dp
        val portalH = lerp(min(full.first.value * 0.5f * 2.1f, full.second.value * 0.66f), full.second.value, e).dp
        val corner = lerp(32f, 0f, e).dp
        val enter = portalIn.value
        Box(
            Modifier
                .align(Alignment.Center)
                .size(portalW, portalH)
                .graphicsLayer {
                    val s = lerp(1.35f, 1f, enter)
                    scaleX = s
                    scaleY = s
                    alpha = min(1f, enter * 1.5f) * portalAlpha.value
                    translationX = shake.value * density
                    // A gentle bob while in warp.
                    translationY = (1f - e) * sin(time * 5f) * 6f * density
                    rotationZ = (1f - e) * sin(time * 2.6f) * 1.6f
                }
                .clip(RoundedCornerShape(corner))
                .background(Obsidian),
        ) {
            AsyncImage(
                model = apply.image.previewUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }

        if (showLabel) {
            Surface(
                shape = CircleShape,
                color = Obsidian.copy(alpha = 0.55f),
                contentColor = Color.White,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
                    .padding(bottom = 40.dp, start = 24.dp, end = 24.dp),
            ) {
                Row(
                    Modifier.padding(horizontal = 18.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Rounded.Check, contentDescription = null, modifier = Modifier.size(20.dp))
                    Text(
                        stringResource(
                            when (apply.target) {
                                WallpaperTarget.HOME -> R.string.set_done_home
                                WallpaperTarget.LOCK -> R.string.set_done_lock
                                WallpaperTarget.BOTH -> R.string.set_done_both
                            },
                        ),
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}

private class Star(random: Random) {
    val angle = random.nextFloat() * 2f * Math.PI.toFloat()
    val offset = random.nextFloat()
    val speed = 0.6f + random.nextFloat() * 0.8f
    val tinted = random.nextFloat() < 0.25f
}
