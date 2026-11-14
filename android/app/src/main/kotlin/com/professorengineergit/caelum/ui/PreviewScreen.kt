package com.professorengineergit.caelum.ui

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.text.format.DateFormat
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.CameraAlt
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.FlashlightOn
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Wallpaper
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ContainedLoadingIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LoadingIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.graphics.drawable.toBitmap
import coil3.compose.AsyncImage
import com.professorengineergit.caelum.R
import com.professorengineergit.caelum.core.CosmicImage
import com.professorengineergit.caelum.data.WallpaperTarget
import com.professorengineergit.caelum.ui.theme.Obsidian
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.hazeSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Date
import java.util.Locale
import kotlin.math.absoluteValue

private enum class PreviewMode { HOME, LOCK }

/**
 * Full-screen preview of the current source's pictures as they'd look on your phone.
 * Swipe (or use the arrows) to go through them; one toggle switches between the home
 * and the lock screen. Tap hides everything, holding shows your current wallpaper.
 */
@Composable
fun PreviewScreen(
    state: UiState,
    messages: Flow<UserMessage>,
    onPick: (CosmicImage) -> Unit,
    onPrepare: () -> Unit,
    onSetWallpaper: (WallpaperTarget) -> Unit,
    onClose: () -> Unit,
    onShowSystemWallpaper: (Boolean) -> Unit,
) {
    val haptics = LocalHaptics.current
    val haze = remember { HazeState() }
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    MessageSnackbars(messages, snackbar)

    var chrome by rememberSaveable { mutableStateOf(true) }
    var comparing by remember { mutableStateOf(false) }
    var mode by rememberSaveable { mutableStateOf(PreviewMode.HOME) }
    var showTargets by rememberSaveable { mutableStateOf(false) }
    val pictureAlpha by animateFloatAsState(if (comparing) 0f else 1f, tween(260), label = "picture")
    val images = state.images

    key(state.source.id) {
        val start = images.indexOfFirst { it.id == state.image?.id }.coerceAtLeast(0)
        val pager = rememberPagerState(initialPage = start) { images.size }
        LaunchedEffect(pager) {
            snapshotFlow { pager.currentPage }.drop(1).collect { haptics.tick(0.6f) }
        }
        LaunchedEffect(pager, images) {
            snapshotFlow { pager.settledPage }.collect { page -> images.getOrNull(page)?.let(onPick) }
        }
        fun go(step: Int) {
            val target = pager.currentPage + step
            if (target !in images.indices) return
            haptics.select()
            scope.launch { pager.animateScrollToPage(target) }
        }

        Box(Modifier.fillMaxSize().background(Obsidian.copy(alpha = pictureAlpha))) {
            // The pictures.
            Box(
                Modifier
                    .fillMaxSize()
                    .graphicsLayer { alpha = pictureAlpha }
                    .hazeSource(haze),
            ) {
                if (images.isEmpty()) {
                    ContainedLoadingIndicator(Modifier.align(Alignment.Center))
                } else {
                    HorizontalPager(state = pager, modifier = Modifier.fillMaxSize(), beyondViewportPageCount = 1) { page ->
                        val image = images[page]
                        ProgressiveImage(
                            image = image,
                            modifier = Modifier
                                .fillMaxSize()
                                .pointerInput(image.id) {
                                    detectTapGestures(
                                        onTap = {
                                            haptics.tick()
                                            chrome = !chrome
                                        },
                                        onLongPress = {
                                            haptics.longPress()
                                            onShowSystemWallpaper(true)
                                            comparing = true
                                        },
                                        onPress = {
                                            tryAwaitRelease()
                                            if (comparing) {
                                                haptics.close()
                                                comparing = false
                                                delay(280)
                                                onShowSystemWallpaper(false)
                                            }
                                        },
                                    )
                                }
                                .graphicsLayer {
                                    // A little depth while swiping.
                                    val offset = (pager.currentPage - page) + pager.currentPageOffsetFraction
                                    translationX = offset * size.width * 0.4f
                                    val s = 1f + 0.06f * offset.absoluteValue.coerceAtMost(1f)
                                    scaleX = s
                                    scaleY = s
                                },
                        )
                    }
                }
            }

            AnimatedVisibility(chrome && !comparing, enter = fadeIn(tween(200)), exit = fadeOut(tween(160))) {
                Box(Modifier.fillMaxSize()) {
                    // Soft scrims so the overlay reads on any picture.
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(160.dp)
                            .background(Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.4f), Color.Transparent))),
                    )
                    Box(
                        Modifier
                            .align(Alignment.BottomCenter)
                            .fillMaxWidth()
                            .height(280.dp)
                            .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.55f)))),
                    )

                    // What the phone would show on top of the wallpaper.
                    AnimatedContent(
                        targetState = mode,
                        transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(140)) },
                        label = "mode",
                        modifier = Modifier
                            .fillMaxSize()
                            .statusBarsPadding()
                            .navigationBarsPadding()
                            .padding(top = 64.dp, bottom = 132.dp),
                    ) { m ->
                        if (m == PreviewMode.HOME) MockHome(haze) else MockLock(haze)
                    }

                    // Top: close, and where we are.
                    Row(
                        Modifier
                            .statusBarsPadding()
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        GlassCircle(Icons.Rounded.Close, stringResource(R.string.close), haze) {
                            haptics.close()
                            onClose()
                        }
                        Spacer(Modifier.weight(1f))
                        Row(
                            Modifier
                                .clip(CircleShape)
                                .glass(haze)
                                .padding(horizontal = 16.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Box(Modifier.size(8.dp).clip(CircleShape).background(Color(state.source.accent)))
                            Text(state.source.name, color = Color.White, style = MaterialTheme.typography.labelLarge)
                            val shownIsCurrent = images.getOrNull(pager.currentPage)?.id == state.settings.lastApplied?.id
                            AnimatedVisibility(shownIsCurrent) {
                                Text(
                                    "· " + stringResource(R.string.current),
                                    color = Color.White.copy(alpha = 0.75f),
                                    style = MaterialTheme.typography.labelLarge,
                                )
                            }
                        }
                        Spacer(Modifier.weight(1f))
                        Spacer(Modifier.size(48.dp))
                    }

                    // Arrows: unmistakably "there's more this way".
                    val canBack = pager.currentPage > 0
                    val canForward = pager.currentPage < images.lastIndex
                    ArrowButton(canBack, Icons.AutoMirrored.Rounded.ArrowBack, stringResource(R.string.previous_picture), haze, Modifier.align(Alignment.CenterStart)) { go(-1) }
                    ArrowButton(canForward, Icons.AutoMirrored.Rounded.ArrowForward, stringResource(R.string.next_picture), haze, Modifier.align(Alignment.CenterEnd)) { go(1) }

                    // Bottom: dots, the one toggle, and the action.
                    Column(
                        Modifier
                            .align(Alignment.BottomCenter)
                            .navigationBarsPadding()
                            .padding(start = 16.dp, end = 16.dp, bottom = 16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        PageDots(pager, images.size)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            ModeToggle(mode, haze) {
                                haptics.select()
                                mode = it
                            }
                            Spacer(Modifier.weight(1f))
                            Button(
                                onClick = {
                                    if (!state.applying && state.image != null) {
                                        haptics.open()
                                        onPrepare()
                                        showTargets = true
                                    }
                                },
                                contentPadding = ButtonDefaults.ButtonWithIconContentPadding,
                                modifier = Modifier.height(52.dp),
                            ) {
                                if (state.applying) {
                                    LoadingIndicator(Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary)
                                } else {
                                    Icon(Icons.Rounded.Wallpaper, contentDescription = null, modifier = Modifier.size(20.dp))
                                }
                                Spacer(Modifier.width(8.dp))
                                Text(stringResource(R.string.set_wallpaper_short), style = MaterialTheme.typography.titleSmall)
                            }
                        }
                    }
                }
            }

            AnimatedVisibility(
                visible = comparing,
                enter = fadeIn(),
                exit = fadeOut(),
                modifier = Modifier.align(Alignment.TopCenter),
            ) {
                Surface(
                    shape = CircleShape,
                    color = Obsidian.copy(alpha = 0.6f),
                    contentColor = Color.White,
                    modifier = Modifier.statusBarsPadding().padding(top = 16.dp),
                ) {
                    Text(
                        stringResource(R.string.live_current),
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(horizontal = 18.dp, vertical = 10.dp),
                    )
                }
            }

            SnackbarHost(
                snackbar,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
                    .padding(bottom = 140.dp),
            )
        }
    }

    if (showTargets) {
        TargetSheet(
            onDismiss = {
                haptics.close()
                showTargets = false
            },
            onChoose = { target ->
                showTargets = false
                onSetWallpaper(target)
            },
        )
    }
}

// MARK: - Controls

@Composable
private fun GlassCircle(icon: ImageVector, description: String, haze: HazeState, onClick: () -> Unit) {
    Box(
        Modifier
            .size(48.dp)
            .clip(CircleShape)
            .glass(haze)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = description, tint = Color.White)
    }
}

@Composable
private fun ArrowButton(
    visible: Boolean,
    icon: ImageVector,
    description: String,
    haze: HazeState,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn() + scaleIn(initialScale = 0.6f),
        exit = fadeOut() + scaleOut(targetScale = 0.6f),
        modifier = modifier.padding(horizontal = 12.dp),
    ) {
        GlassCircle(icon, description, haze, onClick)
    }
}

/** The position in the source, as dots; the current one stretches into a pill. */
@Composable
private fun PageDots(pager: PagerState, count: Int) {
    if (count <= 1) return
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        repeat(count) { i ->
            val selected = i == pager.currentPage
            val width by animateDpAsState(if (selected) 22.dp else 7.dp, label = "dot")
            Box(
                Modifier
                    .height(7.dp)
                    .width(width)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = if (selected) 0.95f else 0.45f)),
            )
        }
    }
}

/** The one toggle: home screen or lock screen. */
@Composable
private fun ModeToggle(mode: PreviewMode, haze: HazeState, onMode: (PreviewMode) -> Unit) {
    Row(
        Modifier
            .height(52.dp)
            .clip(CircleShape)
            .glass(haze)
            .padding(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        for (option in PreviewMode.entries) {
            val selected = option == mode
            Row(
                Modifier
                    .fillMaxHeight()
                    .clip(CircleShape)
                    .background(if (selected) Color.White else Color.Transparent)
                    .clickable { if (!selected) onMode(option) }
                    .padding(horizontal = 14.dp)
                    .animateContentSize(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                val tint = if (selected) Obsidian else Color.White
                Icon(
                    if (option == PreviewMode.HOME) Icons.Rounded.Home else Icons.Rounded.Lock,
                    contentDescription = null,
                    tint = tint,
                    modifier = Modifier.size(18.dp),
                )
                if (selected) {
                    Text(
                        stringResource(if (option == PreviewMode.HOME) R.string.live_home else R.string.live_lock),
                        style = MaterialTheme.typography.labelLarge,
                        color = tint,
                    )
                }
            }
        }
    }
}

// MARK: - The phone's own screens, mocked

@Composable
private fun rememberNow(): Date {
    val now by produceState(Date()) {
        while (true) {
            value = Date()
            delay(60_000L - System.currentTimeMillis() % 60_000L)
        }
    }
    return now
}

private fun longDate(now: Date): String =
    DateFormat.format(DateFormat.getBestDateTimePattern(Locale.getDefault(), "EEEEdMMMM"), now).toString()

@Composable
private fun MockHome(haze: HazeState) {
    val context = LocalContext.current
    val now = rememberNow()
    val apps by produceState(HomeApps(emptyList(), emptyList())) {
        value = withContext(Dispatchers.IO) { loadHomeApps(context) }
    }
    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp)) {
        Text(
            DateFormat.getTimeFormat(context).format(now),
            color = Color.White,
            fontSize = 56.sp,
            fontWeight = FontWeight.Light,
            letterSpacing = (-1.5).sp,
        )
        Text(longDate(now), color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.titleSmall)
        Spacer(Modifier.weight(1f))
        Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
            apps.grid.chunked(4).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    row.forEach { AppIcon(it, showLabel = true) }
                    repeat(4 - row.size) { Spacer(Modifier.width(60.dp)) }
                }
            }
        }
        if (apps.dock.isNotEmpty()) {
            Spacer(Modifier.height(20.dp))
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(30.dp))
                    .glass(haze)
                    .padding(horizontal = 8.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                apps.dock.forEach { AppIcon(it, showLabel = false) }
            }
        }
    }
}

@Composable
private fun MockLock(haze: HazeState) {
    val context = LocalContext.current
    val now = rememberNow()
    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.height(24.dp))
        Text(longDate(now), color = Color.White, style = MaterialTheme.typography.titleMedium)
        Text(
            DateFormat.getTimeFormat(context).format(now),
            color = Color.White,
            fontSize = 92.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = (-3).sp,
        )
        Spacer(Modifier.weight(1f))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            for (icon in listOf(Icons.Rounded.FlashlightOn, Icons.Rounded.CameraAlt)) {
                Box(Modifier.size(52.dp).clip(CircleShape).glass(haze), contentAlignment = Alignment.Center) {
                    Icon(icon, contentDescription = null, tint = Color.White)
                }
            }
        }
    }
}

/** One of your apps — just a picture of it: nothing on the mock screens can be tapped. */
@Composable
private fun AppIcon(app: HomeApp, showLabel: Boolean) {
    Column(Modifier.width(60.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Image(app.icon, contentDescription = null, modifier = Modifier.size(50.dp))
        if (showLabel) {
            Text(
                app.label,
                color = Color.White,
                style = MaterialTheme.typography.labelSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

// MARK: - Your apps

private data class HomeApp(val label: String, val icon: ImageBitmap)
private data class HomeApps(val dock: List<HomeApp>, val grid: List<HomeApp>)

/**
 * A plausible home screen from the apps actually installed: the default phone,
 * messages, browser and camera in the dock, a few others above. Apps can't read the
 * launcher's real layout, so this is an approximation.
 */
private fun loadHomeApps(context: Context): HomeApps = runCatching {
    val pm = context.packageManager
    val launchable = pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
        .filter { it.activityInfo.packageName != context.packageName }
        .distinctBy { it.activityInfo.packageName }
    val byPackage = launchable.associateBy { it.activityInfo.packageName }

    val defaults = listOf(
        Intent(Intent.ACTION_DIAL),
        Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:")),
        Intent(Intent.ACTION_VIEW, Uri.parse("https://example.org")),
        Intent(MediaStore.ACTION_IMAGE_CAPTURE),
    ).mapNotNull { pm.resolveActivity(it, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName }
        .filter { it != "android" && it in byPackage }
        .distinct()

    val iconPx = (50 * context.resources.displayMetrics.density).toInt()
    fun load(pkg: String): HomeApp? = byPackage[pkg]?.let { info ->
        runCatching { HomeApp(info.loadLabel(pm).toString(), info.loadIcon(pm).toBitmap(iconPx, iconPx).asImageBitmap()) }.getOrNull()
    }

    HomeApps(
        dock = defaults.take(4).mapNotNull(::load),
        grid = launchable
            .filter { it.activityInfo.packageName !in defaults }
            .sortedBy { it.loadLabel(pm).toString().lowercase() }
            .take(8)
            .mapNotNull { load(it.activityInfo.packageName) },
    )
}.getOrDefault(HomeApps(emptyList(), emptyList()))
