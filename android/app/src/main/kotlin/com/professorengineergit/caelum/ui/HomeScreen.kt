package com.professorengineergit.caelum.ui

import android.content.Intent
import androidx.compose.animation.AnimatedContent
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
import kotlinx.coroutines.flow.Flow
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
    onRetry: () -> Unit,
    onSetWallpaper: (WallpaperTarget) -> Unit,
    onOpenSettings: () -> Unit,
) {
    val snackbar = remember { SnackbarHostState() }
    var showTargets by rememberSaveable { mutableStateOf(false) }

    val setHome = stringResource(R.string.set_done_home)
    val setLock = stringResource(R.string.set_done_lock)
    val setBoth = stringResource(R.string.set_done_both)
    val failed = stringResource(R.string.set_failed)
    LaunchedEffect(messages) {
        messages.collect { message ->
            val text = when (message) {
                is UserMessage.WallpaperSet -> when (message.target) {
                    WallpaperTarget.HOME -> setHome
                    WallpaperTarget.LOCK -> setLock
                    WallpaperTarget.BOTH -> setBoth
                }
                is UserMessage.Failed -> listOfNotNull(failed, message.reason).joinToString(" ")
            }
            snackbar.showSnackbar(text)
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        floatingActionButton = {
            if (state.image != null) {
                SetWallpaperButton(applying = state.applying, onClick = { showTargets = true })
            }
        },
        contentWindowInsets = WindowInsets(0),
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = padding.calculateBottomPadding()),
        ) {
            item(key = "hero") {
                Hero(state = state, onOpenSettings = onOpenSettings)
            }
            item(key = "sources") {
                SectionTitle(stringResource(R.string.section_sources))
                SourcePicker(
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
            onDismiss = { showTargets = false },
            onChoose = { target ->
                showTargets = false
                onSetWallpaper(target)
            },
        )
    }
}

// MARK: - Hero

@Composable
private fun Hero(state: UiState, onOpenSettings: () -> Unit) {
    val height = (LocalConfiguration.current.screenHeightDp * 0.62f).dp
    val shape = RoundedCornerShape(bottomStart = 40.dp, bottomEnd = 40.dp)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(height)
            .clip(shape)
            .background(Obsidian),
    ) {
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
                AsyncImage(
                    model = image.previewUrl,
                    contentDescription = image.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
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
                    containerColor = Color.White.copy(alpha = 0.16f),
                    contentColor = Color.White,
                ),
            ) {
                Icon(Icons.Rounded.Settings, contentDescription = stringResource(R.string.settings))
            }
        }

        state.image?.let { image ->
            Caption(
                image = image,
                source = state.source,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 24.dp, end = 24.dp, bottom = 28.dp),
            )
        }
    }
}

@Composable
private fun Caption(image: CosmicImage, source: ImageSource, modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Badge(text = source.name, dot = Color(source.accent))
            image.date?.let { Badge(text = it) }
            Badge(text = if (image.isVideo) stringResource(R.string.badge_video) else image.resolution.label)
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
private fun Badge(text: String, dot: Color? = null) {
    Surface(shape = CircleShape, color = Color.White.copy(alpha = 0.14f), contentColor = Color.White) {
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
private fun SourcePicker(sources: List<ImageSource>, selectedId: String, onSelect: (String) -> Unit) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        itemsIndexed(sources, key = { _, source -> source.id }) { index, source ->
            SourceTile(
                source = source,
                polygonIndex = index,
                selected = source.id == selectedId,
                onClick = { onSelect(source.id) },
            )
        }
    }
}

@Composable
private fun SourceTile(source: ImageSource, polygonIndex: Int, selected: Boolean, onClick: () -> Unit) {
    val accent = Color(source.accent)
    val scale by animateFloatAsState(
        targetValue = if (selected) 1f else 0.82f,
        animationSpec = MaterialTheme.motionScheme.fastSpatialSpec(),
        label = "tile-scale",
    )
    // The selected source's shape turns slowly, like a body in orbit.
    val spin = rememberInfiniteTransition(label = "spin")
    val angle by spin.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(24_000, easing = LinearEasing)),
        label = "angle",
    )
    val shape = SourceShapes[polygonIndex % SourceShapes.size].toShape()

    Column(
        modifier = Modifier
            .width(84.dp)
            .clip(MaterialTheme.shapes.medium)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.size(68.dp), contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .size(68.dp)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        rotationZ = if (selected) angle else 0f
                    }
                    .clip(shape)
                    .background(
                        if (selected) {
                            Brush.linearGradient(listOf(accent, MaterialTheme.colorScheme.primary))
                        } else {
                            Brush.linearGradient(listOf(accent.copy(alpha = 0.35f), accent.copy(alpha = 0.2f)))
                        },
                    ),
            )
            if (selected) {
                Icon(Icons.Rounded.Check, contentDescription = null, tint = Obsidian)
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
                val carousel = rememberCarouselState { images.size }
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
                            .clickable { onPick(image) },
                    ) {
                        AsyncImage(
                            model = image.previewUrl,
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
            Button(onClick = onRetry) {
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
                    modifier = Modifier.clickable { expanded = !expanded },
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
                        context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
                    }) {
                        Icon(Icons.AutoMirrored.Rounded.OpenInNew, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(R.string.open_page))
                    }
                }
                OutlinedButton(onClick = {
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

@Composable
private fun SetWallpaperButton(applying: Boolean, onClick: () -> Unit) {
    ExtendedFloatingActionButton(
        onClick = { if (!applying) onClick() },
        expanded = true,
        icon = {
            AnimatedContent(targetState = applying, label = "fab-icon") { busy ->
                if (busy) {
                    LoadingIndicator(
                        modifier = Modifier.size(24.dp),
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                } else {
                    Icon(Icons.Rounded.Wallpaper, contentDescription = null)
                }
            }
        },
        text = { Text(stringResource(if (applying) R.string.setting_wallpaper else R.string.set_wallpaper)) },
        modifier = Modifier.padding(bottom = 8.dp),
    )
}

@Composable
private fun TargetSheet(onDismiss: () -> Unit, onChoose: (WallpaperTarget) -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    fun choose(target: WallpaperTarget) {
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
