package com.professorengineergit.caelum.ui

import android.content.Intent
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsBottomHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.OpenInNew
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material.icons.rounded.Smartphone
import androidx.compose.material.icons.rounded.Wallpaper
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ContainedLoadingIndicator
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.LoadingIndicator
import androidx.compose.material3.MaterialShapes
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.carousel.HorizontalMultiBrowseCarousel
import androidx.compose.material3.carousel.rememberCarouselState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.toShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import coil3.compose.AsyncImage
import com.professorengineergit.caelum.R
import com.professorengineergit.caelum.core.CosmicImage
import com.professorengineergit.caelum.core.ImageSource
import com.professorengineergit.caelum.data.WallpaperTarget
import com.professorengineergit.caelum.ui.theme.Obsidian
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.hazeSource
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

/** One expressive shape per source, in registry order. */
private val SourceShapes = listOf(
    MaterialShapes.Cookie9Sided,
    MaterialShapes.Sunny,
    MaterialShapes.Clover4Leaf,
    MaterialShapes.Pentagon,
    MaterialShapes.Gem,
    MaterialShapes.Flower,
    MaterialShapes.SoftBurst,
    MaterialShapes.Cookie6Sided,
    MaterialShapes.Puffy,
    MaterialShapes.Burst,
)

@Composable
fun HomeScreen(
    state: UiState,
    messages: Flow<UserMessage>,
    onSelectSource: (String) -> Unit,
    onPick: (CosmicImage) -> Unit,
    onStep: (Int) -> Unit,
    onRetry: () -> Unit,
    onPrepare: () -> Unit,
    onSetWallpaper: (WallpaperTarget) -> Unit,
    onOpenPreview: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    val haptics = LocalHaptics.current
    val snackbar = remember { SnackbarHostState() }
    var showTargets by rememberSaveable { mutableStateOf(false) }

    MessageSnackbars(messages, snackbar)

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        floatingActionButton = {
            if (state.image != null) {
                WallpaperActions(
                    applying = state.applying,
                    onPreview = onOpenPreview,
                    onSet = {
                        haptics.open()
                        onPrepare()
                        showTargets = true
                    },
                )
            }
        },
        contentWindowInsets = WindowInsets(0),
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = padding.calculateBottomPadding()),
        ) {
            item(key = "hero") {
                val isCurrent = state.image != null && state.image?.id == state.settings.lastApplied?.id
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Hero(state = state, isCurrent = isCurrent, onStep = onStep, onOpenSettings = onOpenSettings)
                    CurrentLabel(isCurrent)
                }
            }
            item(key = "sources") {
                SectionTitle(stringResource(R.string.section_sources))
                SourcePicker(
                    state = state,
                    sources = state.sources,
                    selectedId = state.source.id,
                    onSelect = onSelectSource,
                )
            }
            item(key = "recent") {
                SectionTitle(stringResource(R.string.section_recent, state.source.name))
                Recent(state = state, onPick = onPick, onRetry = onRetry)
            }
            state.image?.let { image ->
                item(key = "about") {
                    About(image = image)
                }
            }
            item(key = "bottom") {
                Spacer(Modifier.height(96.dp))
                Spacer(Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
            }
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

// MARK: - Hero

@Composable
private fun Hero(state: UiState, isCurrent: Boolean, onStep: (Int) -> Unit, onOpenSettings: () -> Unit) {
    val haptics = LocalHaptics.current
    val accent = MaterialTheme.colorScheme.primary
    // The "chin": an accent line along the rounded bottom, drawn out from the middle
    // when this picture is the wallpaper right now.
    val chin = remember { Animatable(if (isCurrent) 1f else 0f) }
    LaunchedEffect(isCurrent) {
        chin.animateTo(if (isCurrent) 1f else 0f, tween(if (isCurrent) 750 else 250, easing = FastOutSlowInEasing))
    }
    val height = (LocalConfiguration.current.screenHeightDp * 0.62f).dp
    val shape = RoundedCornerShape(bottomStart = 40.dp, bottomEnd = 40.dp)
    val haze = remember { HazeState() }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(height)
            .clip(shape)
            .background(Obsidian)
            .drawWithContent {
                drawContent()
                drawChin(chin.value, accent, cornerRadius = 40.dp.toPx(), stroke = 5.dp.toPx(), rise = 56.dp.toPx())
            },
    ) {
        // Everything the glass badges blur: the picture and its scrims.
        Box(Modifier.fillMaxSize().hazeSource(haze)) {
            AnimatedContent(
                targetState = state.image,
                contentKey = { it?.id },
                transitionSpec = {
                    (fadeIn(tween(600)) + scaleIn(tween(900), initialScale = 1.08f))
                        .togetherWith(fadeOut(tween(400)))
                },
                label = "hero",
                modifier = Modifier.fillMaxSize(),
            ) { image ->
                if (image != null) {
                    ProgressiveImage(image, Modifier.fillMaxSize())
                } else {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        if (state.feed is Feed.Loading) LoadingIndicator(Modifier.size(72.dp))
                    }
                }
            }

            // Scrims keep the status bar and the caption legible over any picture.
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(140.dp)
                    .background(Brush.verticalGradient(listOf(Obsidian.copy(alpha = 0.55f), Color.Transparent))),
            )
            Box(
                Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(height * 0.55f)
                    .background(Brush.verticalGradient(listOf(Color.Transparent, Obsidian.copy(alpha = 0.92f)))),
            )
        }

        Row(
            modifier = Modifier
                .statusBarsPadding()
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.app_name),
                style = MaterialTheme.typography.titleLarge,
                color = Color.White,
                modifier = Modifier.weight(1f),
            )
            FilledTonalIconButton(
                onClick = onOpenSettings,
                colors = IconButtonDefaults.filledTonalIconButtonColors(
                    containerColor = Color.Transparent,
                    contentColor = Color.White,
                ),
                modifier = Modifier.clip(CircleShape).glass(haze),
            ) {
                Icon(Icons.Rounded.Settings, contentDescription = stringResource(R.string.settings))
            }
        }

        // Arrows make it obvious there are more pictures in this source.
        val index = state.images.indexOfFirst { it.id == state.image?.id }
        if (index >= 0 && state.images.size > 1) {
            Row(
                Modifier
                    .align(Alignment.Center)
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                HeroArrow(index > 0, Icons.AutoMirrored.Rounded.ArrowBack, stringResource(R.string.previous_picture), haze) {
                    haptics.select()
                    onStep(-1)
                }
                Spacer(Modifier.weight(1f))
                HeroArrow(index < state.images.lastIndex, Icons.AutoMirrored.Rounded.ArrowForward, stringResource(R.string.next_picture), haze) {
                    haptics.select()
                    onStep(1)
                }
            }
        }

        state.image?.let { image ->
            Caption(
                image = image,
                source = state.source,
                haze = haze,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 24.dp, end = 24.dp, bottom = 28.dp),
            )
        }
    }
}

@Composable
private fun Caption(image: CosmicImage, source: ImageSource, haze: HazeState, modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Badge(text = source.name, haze = haze, dot = Color(source.accent))
            image.date?.let { Badge(text = it, haze = haze) }
            Badge(text = if (image.isVideo) stringResource(R.string.badge_video) else image.resolution.label, haze = haze)
        }
        Text(
            text = image.title,
            style = MaterialTheme.typography.displaySmall,
            color = Color.White,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = image.credit,
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.72f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
fun Badge(text: String, haze: HazeState, dot: Color? = null) {
    Surface(
        shape = CircleShape,
        color = Color.Transparent,
        contentColor = Color.White,
        border = BorderStroke(0.5.dp, Color.White.copy(alpha = 0.18f)),
        modifier = Modifier.clip(CircleShape).glass(haze),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            dot?.let { Box(Modifier.size(8.dp).clip(CircleShape).background(it)) }
            Text(text, style = MaterialTheme.typography.labelMedium)
        }
    }
}

// MARK: - Sources

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 24.dp, end = 24.dp, top = 28.dp, bottom = 12.dp),
    )
}

@Composable
private fun SourcePicker(state: UiState, sources: List<ImageSource>, selectedId: String, onSelect: (String) -> Unit) {
    val haptics = LocalHaptics.current
    val listState = rememberLazyListState()
    TickOnScroll(listState)
    LazyRow(
        state = listState,
        contentPadding = PaddingValues(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        itemsIndexed(sources, key = { _, source -> source.id }) { index, source ->
            SourceTile(
                source = source,
                cover = (state.feeds[source.id] as? Feed.Ready)?.images?.firstOrNull { !it.isVideo }?.thumbnailUrl(small = true),
                polygonIndex = index,
                selected = source.id == selectedId,
                onClick = {
                    if (source.id != selectedId) haptics.orbit() else haptics.tick()
                    onSelect(source.id)
                },
            )
        }
    }
}

/** A source, shown by its newest real picture. */
@Composable
private fun SourceTile(source: ImageSource, cover: String?, polygonIndex: Int, selected: Boolean, onClick: () -> Unit) {
    val accent = Color(source.accent)
    val scale by animateFloatAsState(
        targetValue = if (selected) 1f else 0.86f,
        animationSpec = MaterialTheme.motionScheme.fastSpatialSpec(),
        label = "tile-scale",
    )
    val ring by animateFloatAsState(
        targetValue = if (selected) 1f else 0f,
        animationSpec = MaterialTheme.motionScheme.defaultEffectsSpec(),
        label = "tile-ring",
    )
    // Selected, the picture morphs from a rounded square into an expressive shape.
    val shape = if (selected) SourceShapes[polygonIndex % SourceShapes.size].toShape() else RoundedCornerShape(24.dp)

    Column(
        modifier = Modifier
            .width(88.dp)
            .clip(MaterialTheme.shapes.medium)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier
                .size(76.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                Modifier
                    .fillMaxSize()
                    .clip(shape)
                    .background(Brush.linearGradient(listOf(accent, MaterialTheme.colorScheme.primary)))
                    .padding((3 * ring).dp)
                    .clip(shape)
                    .background(Brush.linearGradient(listOf(accent.copy(alpha = 0.5f), Obsidian))),
            ) {
                if (cover != null) {
                    AsyncImage(
                        model = cover,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxSize()
                            .graphicsLayer { alpha = if (selected) 1f else 0.85f },
                    )
                }
            }
            if (selected) {
                Box(
                    Modifier
                        .align(Alignment.BottomEnd)
                        .size(24.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Rounded.Check, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(15.dp))
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = source.name,
            style = MaterialTheme.typography.labelLarge,
            color = if (selected) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = source.subtitle,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun HeroArrow(visible: Boolean, icon: ImageVector, description: String, haze: HazeState, onClick: () -> Unit) {
    Box(Modifier.size(48.dp)) {
        AnimatedVisibility(visible, enter = fadeIn() + scaleIn(initialScale = 0.6f), exit = fadeOut() + scaleOut(targetScale = 0.6f)) {
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
    }
}

// MARK: - Recent pictures

@Composable
private fun Recent(state: UiState, onPick: (CosmicImage) -> Unit, onRetry: () -> Unit) {
    AnimatedContent(
        targetState = state.feed,
        contentKey = { feed -> feed::class to state.source.id },
        label = "feed",
    ) { feed ->
        when (feed) {
            Feed.Loading -> Box(
                Modifier.fillMaxWidth().height(200.dp),
                contentAlignment = Alignment.Center,
            ) {
                ContainedLoadingIndicator()
            }

            is Feed.Failed -> FeedError(onRetry)

            is Feed.Ready -> {
                val images = feed.images
                val haptics = LocalHaptics.current
                val carousel = rememberCarouselState { images.size }
                LaunchedEffect(carousel) {
                    snapshotFlow { carousel.currentItem }.drop(1).collect { haptics.tick(0.45f) }
                }
                HorizontalMultiBrowseCarousel(
                    state = carousel,
                    preferredItemWidth = 200.dp,
                    itemSpacing = 8.dp,
                    contentPadding = PaddingValues(horizontal = 20.dp),
                    modifier = Modifier.fillMaxWidth().height(220.dp),
                ) { index ->
                    val image = images[index]
                    val picked = image.id == state.image?.id
                    Box(
                        Modifier
                            .fillMaxSize()
                            .maskClip(MaterialTheme.shapes.extraLarge)
                            .clickable {
                                if (!picked) haptics.select() else haptics.tick()
                                onPick(image)
                            },
                    ) {
                        AsyncImage(
                            model = image.thumbnailUrl(),
                            contentDescription = image.title,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize(),
                        )
                        if (picked) {
                            Box(
                                Modifier
                                    .align(Alignment.TopEnd)
                                    .padding(12.dp)
                                    .size(32.dp)
                                    .clip(MaterialShapes.Cookie9Sided.toShape())
                                    .background(MaterialTheme.colorScheme.primary),
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    Icons.Rounded.Check,
                                    contentDescription = stringResource(R.string.selected),
                                    tint = MaterialTheme.colorScheme.onPrimary,
                                    modifier = Modifier.size(18.dp),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FeedError(onRetry: () -> Unit) {
    Card(
        modifier = Modifier.padding(horizontal = 20.dp).fillMaxWidth(),
        shape = MaterialTheme.shapes.extraLarge,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                stringResource(R.string.feed_error_title),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
            Text(
                stringResource(R.string.feed_error_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
            val haptics = LocalHaptics.current
            Button(onClick = {
                haptics.click()
                onRetry()
            }) {
                Icon(Icons.Rounded.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.retry))
            }
        }
    }
}

// MARK: - About

@Composable
private fun About(image: CosmicImage) {
    val context = LocalContext.current
    val haptics = LocalHaptics.current
    var expanded by rememberSaveable(image.id) { mutableStateOf(false) }

    Card(
        modifier = Modifier
            .padding(start = 20.dp, end = 20.dp, top = 28.dp)
            .fillMaxWidth(),
        shape = MaterialTheme.shapes.extraLarge,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) {
        Column(
            Modifier
                .padding(24.dp)
                .animateContentSize(MaterialTheme.motionScheme.defaultSpatialSpec()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(stringResource(R.string.about_title), style = MaterialTheme.typography.titleLarge)
            image.explanation?.let { text ->
                Text(
                    text = text,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = if (expanded) Int.MAX_VALUE else 5,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.clickable {
                        if (expanded) haptics.close() else haptics.open()
                        expanded = !expanded
                    },
                )
            }
            Text(
                text = stringResource(R.string.credit, image.credit),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                image.pageUrl?.let { url ->
                    FilledTonalButton(onClick = {
                        haptics.click()
                        context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
                    }) {
                        Icon(Icons.AutoMirrored.Rounded.OpenInNew, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(R.string.open_page))
                    }
                }
                OutlinedButton(onClick = {
                    haptics.click()
                    val send = Intent(Intent.ACTION_SEND)
                        .setType("text/plain")
                        .putExtra(Intent.EXTRA_SUBJECT, image.title)
                        .putExtra(Intent.EXTRA_TEXT, listOfNotNull(image.title, image.pageUrl ?: image.imageUrl).joinToString("\n"))
                    context.startActivity(Intent.createChooser(send, null))
                }) {
                    Icon(Icons.Rounded.Share, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.share))
                }
            }
        }
    }
}

// MARK: - Setting the wallpaper

/**
 * One button, two parts: "Preview" on top, "Set as wallpaper" below — together half
 * again as tall as a normal button, so both are clearly one action family.
 */
@Composable
private fun WallpaperActions(applying: Boolean, onPreview: () -> Unit, onSet: () -> Unit) {
    val outer = 28.dp
    val inner = 6.dp
    Column(
        Modifier.padding(bottom = 8.dp).width(IntrinsicSize.Max),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Surface(
            onClick = onPreview,
            shape = RoundedCornerShape(topStart = outer, topEnd = outer, bottomStart = inner, bottomEnd = inner),
            color = MaterialTheme.colorScheme.secondaryContainer,
            contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
            shadowElevation = 6.dp,
            modifier = Modifier.fillMaxWidth().height(34.dp),
        ) {
            Row(
                Modifier.padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.Visibility, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.preview), style = MaterialTheme.typography.labelLarge)
            }
        }
        Surface(
            onClick = { if (!applying) onSet() },
            shape = RoundedCornerShape(topStart = inner, topEnd = inner, bottomStart = outer, bottomEnd = outer),
            color = MaterialTheme.colorScheme.primaryContainer,
            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            shadowElevation = 6.dp,
            modifier = Modifier.fillMaxWidth().height(50.dp),
        ) {
            Row(
                Modifier.padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                AnimatedContent(targetState = applying, label = "fab-icon") { busy ->
                    if (busy) {
                        LoadingIndicator(Modifier.size(22.dp), color = MaterialTheme.colorScheme.onPrimaryContainer)
                    } else {
                        Icon(Icons.Rounded.Wallpaper, contentDescription = null, modifier = Modifier.size(22.dp))
                    }
                }
                Spacer(Modifier.width(10.dp))
                Text(
                    stringResource(if (applying) R.string.setting_wallpaper else R.string.set_wallpaper),
                    style = MaterialTheme.typography.titleSmall,
                )
            }
        }
    }
}

@Composable
fun TargetSheet(onDismiss: () -> Unit, onChoose: (WallpaperTarget) -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    val haptics = LocalHaptics.current
    fun choose(target: WallpaperTarget) {
        haptics.select()
        scope.launch { sheetState.hide() }.invokeOnCompletion { onChoose(target) }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Text(
            text = stringResource(R.string.set_wallpaper_on),
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
        )
        Column(
            Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            TargetOption(Icons.Rounded.Home, stringResource(R.string.target_home), first = true) {
                choose(WallpaperTarget.HOME)
            }
            TargetOption(Icons.Rounded.Lock, stringResource(R.string.target_lock)) {
                choose(WallpaperTarget.LOCK)
            }
            TargetOption(Icons.Rounded.Smartphone, stringResource(R.string.target_both), last = true) {
                choose(WallpaperTarget.BOTH)
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

/** A row of an expressive segmented list: big outer corners, tight inner ones. */
@Composable
private fun TargetOption(
    icon: ImageVector,
    label: String,
    first: Boolean = false,
    last: Boolean = false,
    onClick: () -> Unit,
) {
    val outer = 28.dp
    val inner = 6.dp
    val shape = RoundedCornerShape(
        topStart = if (first) outer else inner,
        topEnd = if (first) outer else inner,
        bottomStart = if (last) outer else inner,
        bottomEnd = if (last) outer else inner,
    )
    ListItem(
        headlineContent = { Text(label, style = MaterialTheme.typography.titleMedium) },
        leadingContent = {
            Box(
                Modifier
                    .size(40.dp)
                    .clip(MaterialShapes.Cookie6Sided.toShape())
                    .background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimaryContainer)
            }
        },
        colors = ListItemDefaults.colors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
        modifier = Modifier
            .clip(shape)
            .clickable(onClick = onClick),
    )
}

/** Failures as snackbars; success is celebrated by the warp animation instead. */
@Composable
fun MessageSnackbars(messages: Flow<UserMessage>, snackbar: SnackbarHostState) {
    val failed = stringResource(R.string.set_failed)
    LaunchedEffect(messages) {
        messages.collect { message ->
            if (message is UserMessage.Failed) {
                snackbar.showSnackbar(listOfNotNull(failed, message.reason).joinToString(" "))
            }
        }
    }
}

/** A light tick each time a new item scrolls into the first slot of a row. */
@Composable
fun TickOnScroll(state: LazyListState) {
    val haptics = LocalHaptics.current
    LaunchedEffect(state) {
        snapshotFlow { state.firstVisibleItemIndex }.drop(1).collect { haptics.tick(0.35f) }
    }
}

/**
 * The chin outline: up the left rounded corner, along the bottom, up the right one —
 * growing from the bottom centre as [progress] goes 0 → 1, fading out as it rises.
 */
private fun DrawScope.drawChin(progress: Float, color: Color, cornerRadius: Float, stroke: Float, rise: Float) {
    if (progress <= 0f) return
    val inset = stroke / 2
    val w = size.width
    val h = size.height
    val r = cornerRadius - inset
    val top = h - cornerRadius - rise
    fun half(left: Boolean): Path = Path().apply {
        val x = if (left) inset else w - inset
        moveTo(w / 2, h - inset)
        lineTo(if (left) cornerRadius else w - cornerRadius, h - inset)
        val oval = if (left) {
            Rect(inset, h - inset - 2 * r, inset + 2 * r, h - inset)
        } else {
            Rect(w - inset - 2 * r, h - inset - 2 * r, w - inset, h - inset)
        }
        arcTo(oval, 90f, if (left) 90f else -90f, false)
        lineTo(x, top)
    }
    val brush = Brush.verticalGradient(
        0f to color.copy(alpha = 0f),
        0.45f to color,
        1f to color,
        startY = top,
        endY = h,
    )
    for (left in listOf(true, false)) {
        val full = half(left)
        val measure = PathMeasure().apply { setPath(full, false) }
        val part = Path()
        measure.getSegment(0f, measure.length * progress, part, true)
        drawPath(part, brush, style = Stroke(width = stroke, cap = StrokeCap.Round))
    }
}

/** "Current", under the picture that is the wallpaper right now. */
@Composable
private fun CurrentLabel(visible: Boolean) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(300, delayMillis = 450)) + expandVertically(),
        exit = fadeOut() + shrinkVertically(),
    ) {
        Row(
            Modifier.padding(top = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(Modifier.size(6.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primary))
            Text(
                stringResource(R.string.current),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}
