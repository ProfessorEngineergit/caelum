package com.professorengineergit.caelum.ui

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.text.format.DateFormat
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CameraAlt
import androidx.compose.material.icons.rounded.FlashlightOn
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Wallpaper
import androidx.compose.material3.Button
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
import com.professorengineergit.caelum.core.ImageSource
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
 * Experimental: the start screen as your home screen. The pictures fill the display
 * behind a mock-up of your own apps (or the lock-screen clock); swipe to try the next
 * one, tap to hide everything, hold to see your current wallpaper for comparison.
 */
@Composable
fun LiveHomeScreen(
    state: UiState,
    messages: Flow<UserMessage>,
    onSelectSource: (String) -> Unit,
    onPick: (CosmicImage) -> Unit,
    onRetry: () -> Unit,
    onPrepare: () -> Unit,
    onSetWallpaper: (WallpaperTarget) -> Unit,
    onOpenSettings: () -> Unit,
    onShowSystemWallpaper: (Boolean) -> Unit,
) {
    val haptics = LocalHaptics.current
    val haze = remember { HazeState() }
    val snackbar = remember { SnackbarHostState() }
    MessageSnackbars(messages, snackbar)

    var chrome by rememberSaveable { mutableStateOf(true) }
    var comparing by remember { mutableStateOf(false) }
    var mode by rememberSaveable { mutableStateOf(PreviewMode.HOME) }
    var showTargets by rememberSaveable { mutableStateOf(false) }

    val pictureAlpha by animateFloatAsState(if (comparing) 0f else 1f, tween(260), label = "picture")

    Box(
        Modifier
            .fillMaxSize()
            .background(Obsidian.copy(alpha = pictureAlpha)),
    ) {
        // The pictures, swipeable, with a little parallax.
        Box(
            Modifier
                .fillMaxSize()
                .graphicsLayer { alpha = pictureAlpha }
                .hazeSource(haze),
        ) {
            val images = state.images
            if (images.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    when (state.feed) {
                        is Feed.Failed -> Button(onClick = {
                            haptics.click()
                            onRetry()
                        }) {
                            Icon(Icons.Rounded.Refresh, contentDescription = null)
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.retry))
                        }
                        else -> ContainedLoadingIndicator()
                    }
                }
            } else {
                key(state.source.id) {
                    val start = images.indexOfFirst { it.id == state.image?.id }.coerceAtLeast(0)
                    val pager = rememberPagerState(initialPage = start) { images.size }
                    LaunchedEffect(pager) {
                        snapshotFlow { pager.currentPage }.drop(1).collect { haptics.tick(0.6f) }
                    }
                    LaunchedEffect(pager) {
                        snapshotFlow { pager.settledPage }.collect { page -> images.getOrNull(page)?.let(onPick) }
                    }
                    HorizontalPager(state = pager, modifier = Modifier.fillMaxSize(), beyondViewportPageCount = 1) { page ->
                        val image = images[page]
                        Box(
                            Modifier
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
                                                // Let the picture fade back in before the window turns opaque again.
                                                delay(280)
                                                onShowSystemWallpaper(false)
                                            }
                                        },
                                    )
                                },
                        ) {
                            AsyncImage(
                                model = image.previewUrl,
                                contentDescription = image.title,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .graphicsLayer {
                                        val offset = (pager.currentPage - page) + pager.currentPageOffsetFraction
                                        translationX = offset * size.width * 0.45f
                                        val s = 1f + 0.08f * offset.absoluteValue.coerceAtMost(1f)
                                        scaleX = s
                                        scaleY = s
                                    },
                            )
                        }
                    }
                }
            }
        }

        // Light scrims, like a launcher's, so the overlay stays readable.
        AnimatedVisibility(chrome && !comparing, enter = fadeIn(), exit = fadeOut()) {
            Box(Modifier.fillMaxSize()) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                        .background(Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.35f), Color.Transparent))),
                )
                Box(
                    Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .height(320.dp)
                        .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.45f)))),
                )
            }
        }

        // The mock home or lock screen.
        AnimatedVisibility(
            visible = chrome && !comparing,
            enter = fadeIn(tween(220)) + slideInVertically { it / 16 },
            exit = fadeOut(tween(160)) + slideOutVertically { it / 16 },
        ) {
            Column(Modifier.fillMaxSize()) {
                TopControls(
                    haze = haze,
                    mode = mode,
                    onMode = {
                        haptics.select()
                        mode = it
                    },
                    onOpenSettings = onOpenSettings,
                )
                AnimatedContent(
                    targetState = mode,
                    transitionSpec = { fadeIn(tween(240)) togetherWith fadeOut(tween(160)) },
                    label = "preview-mode",
                    modifier = Modifier.weight(1f),
                ) { m ->
                    when (m) {
                        PreviewMode.HOME -> MockHome(haze)
                        PreviewMode.LOCK -> MockLock(haze)
                    }
                }
                BottomPanel(
                    state = state,
                    haze = haze,
                    onSelectSource = { id ->
                        if (id != state.source.id) haptics.orbit() else haptics.tick()
                        onSelectSource(id)
                    },
                    onApply = {
                        haptics.open()
                        onPrepare()
                        showTargets = true
                    },
                )
            }
        }

        // The label while comparing.
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
                .padding(bottom = 220.dp),
        )
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

// MARK: - Top

@Composable
private fun TopControls(haze: HazeState, mode: PreviewMode, onMode: (PreviewMode) -> Unit, onOpenSettings: () -> Unit) {
    Row(
        Modifier
            .statusBarsPadding()
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            Modifier
                .clip(CircleShape)
                .glass(haze)
                .padding(4.dp),
        ) {
            for (option in PreviewMode.entries) {
                val selected = option == mode
                Box(
                    Modifier
                        .clip(CircleShape)
                        .background(if (selected) Color.White.copy(alpha = 0.9f) else Color.Transparent)
                        .clickable { if (!selected) onMode(option) }
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                ) {
                    Text(
                        stringResource(if (option == PreviewMode.HOME) R.string.live_home else R.string.live_lock),
                        style = MaterialTheme.typography.labelLarge,
                        color = if (selected) Obsidian else Color.White,
                    )
                }
            }
        }
        Spacer(Modifier.weight(1f))
        Box(
            Modifier
                .size(44.dp)
                .clip(CircleShape)
                .glass(haze)
                .clickable(onClick = onOpenSettings),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.Settings, contentDescription = stringResource(R.string.settings), tint = Color.White)
        }
    }
}

// MARK: - Mock screens

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

@Composable
private fun MockHome(haze: HazeState) {
    val context = LocalContext.current
    val now = rememberNow()
    val apps by produceState(HomeApps(emptyList(), emptyList())) {
        value = withContext(Dispatchers.IO) { loadHomeApps(context) }
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp)) {
        // A clock widget, like most launchers have.
        Spacer(Modifier.height(24.dp))
        Text(
            DateFormat.getTimeFormat(context).format(now),
            color = Color.White,
            fontSize = 64.sp,
            fontWeight = FontWeight.Light,
            letterSpacing = (-2).sp,
        )
        Text(
            DateFormat.format(DateFormat.getBestDateTimePattern(Locale.getDefault(), "EEEEdMMMM"), now).toString(),
            color = Color.White.copy(alpha = 0.85f),
            style = MaterialTheme.typography.titleMedium,
        )
        Spacer(Modifier.weight(1f))
        AppGrid(apps.grid, columns = 4)
        Spacer(Modifier.height(16.dp))
        if (apps.dock.isNotEmpty()) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(28.dp))
                    .glass(haze)
                    .padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                apps.dock.forEach { AppIcon(it, showLabel = false) }
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun MockLock(haze: HazeState) {
    val context = LocalContext.current
    val now = rememberNow()
    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(20.dp))
        Icon(Icons.Rounded.Lock, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
        Spacer(Modifier.height(12.dp))
        Text(
            DateFormat.format(DateFormat.getBestDateTimePattern(Locale.getDefault(), "EEEEdMMMM"), now).toString(),
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
        )
        Text(
            DateFormat.getTimeFormat(context).format(now),
            color = Color.White,
            fontSize = 96.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = (-3).sp,
        )
        Spacer(Modifier.weight(1f))
        Row(Modifier.fillMaxWidth().padding(bottom = 16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            for (icon in listOf(Icons.Rounded.FlashlightOn, Icons.Rounded.CameraAlt)) {
                Box(
                    Modifier.size(52.dp).clip(CircleShape).glass(haze),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(icon, contentDescription = null, tint = Color.White)
                }
            }
        }
    }
}

@Composable
private fun AppGrid(apps: List<HomeApp>, columns: Int) {
    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        apps.chunked(columns).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                row.forEach { AppIcon(it, showLabel = true) }
                repeat(columns - row.size) { Spacer(Modifier.width(64.dp)) }
            }
        }
    }
}

/** One of your apps. Tapping it doesn't open it — it wobbles, because this is only a preview. */
@Composable
private fun AppIcon(app: HomeApp, showLabel: Boolean) {
    val haptics = LocalHaptics.current
    val scope = rememberCoroutineScope()
    val wobble = remember { Animatable(0f) }
    Column(
        Modifier
            .width(64.dp)
            .graphicsLayer { rotationZ = wobble.value }
            .clickable(interactionSource = null, indication = null) {
                haptics.tick(0.8f)
                scope.launch {
                    for (angle in listOf(-9f, 8f, -6f, 4f, -2f, 0f)) wobble.animateTo(angle, tween(55))
                }
            },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Image(app.icon, contentDescription = app.label, modifier = Modifier.size(52.dp))
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

// MARK: - Bottom panel

@Composable
private fun BottomPanel(state: UiState, haze: HazeState, onSelectSource: (String) -> Unit, onApply: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp))
            .glass(haze, deep = true)
            .navigationBarsPadding()
            .padding(top = 14.dp, bottom = 10.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        val listState = rememberLazyListState()
        TickOnScroll(listState)
        LazyRow(
            state = listState,
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(state.sources, key = { it.id }) { source ->
                SourceChip(source, selected = source.id == state.source.id) { onSelectSource(source.id) }
            }
        }
        Row(
            Modifier.padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    state.image?.title.orEmpty(),
                    color = Color.White,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    stringResource(R.string.live_hint),
                    color = Color.White.copy(alpha = 0.6f),
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.width(12.dp))
            Button(onClick = { if (!state.applying && state.image != null) onApply() }) {
                if (state.applying) {
                    LoadingIndicator(Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary)
                } else {
                    Icon(Icons.Rounded.Wallpaper, contentDescription = null, modifier = Modifier.size(18.dp))
                }
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.set_wallpaper_short))
            }
        }
    }
}

@Composable
private fun SourceChip(source: ImageSource, selected: Boolean, onClick: () -> Unit) {
    val accent = Color(source.accent)
    Row(
        Modifier
            .clip(CircleShape)
            .background(if (selected) Color.White.copy(alpha = 0.92f) else Color.White.copy(alpha = 0.08f))
            .clickable(onClick = onClick)
            .padding(start = 4.dp, end = 12.dp, top = 4.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SourceEmblem(source.id, accent, Modifier.size(28.dp))
        Text(
            source.name,
            style = MaterialTheme.typography.labelLarge,
            color = if (selected) Obsidian else Color.White,
        )
    }
}

// MARK: - Your apps

private data class HomeApp(val label: String, val icon: ImageBitmap)
private data class HomeApps(val dock: List<HomeApp>, val grid: List<HomeApp>)

/**
 * A plausible home screen from the apps actually installed: the default phone,
 * messages, browser and camera in the dock, a few others above. The real layout
 * of the launcher isn't available to apps, so this is an approximation.
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

    val iconPx = (52 * context.resources.displayMetrics.density).toInt()
    fun load(pkg: String): HomeApp? = byPackage[pkg]?.let { info ->
        runCatching {
            HomeApp(info.loadLabel(pm).toString(), info.loadIcon(pm).toBitmap(iconPx, iconPx).asImageBitmap())
        }.getOrNull()
    }

    val dock = defaults.take(4).mapNotNull(::load)
    val grid = launchable
        .filter { it.activityInfo.packageName !in defaults }
        .sortedBy { it.loadLabel(pm).toString().lowercase() }
        .take(8)
        .mapNotNull { load(it.activityInfo.packageName) }
    HomeApps(dock, grid)
}.getOrDefault(HomeApps(emptyList(), emptyList()))
