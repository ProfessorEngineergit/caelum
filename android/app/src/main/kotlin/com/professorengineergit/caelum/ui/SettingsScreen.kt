package com.professorengineergit.caelum.ui

import android.content.Intent
import android.os.Build
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsBottomHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Code
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Wallpaper
import androidx.compose.material.icons.rounded.Wifi
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialShapes
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.material3.toShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import androidx.graphics.shapes.RoundedPolygon
import com.professorengineergit.caelum.BuildConfig
import com.professorengineergit.caelum.R
import com.professorengineergit.caelum.data.ColorMode
import com.professorengineergit.caelum.data.WallpaperTarget

@Composable
fun SettingsScreen(
    state: UiState,
    onBack: () -> Unit,
    onDailyEnabled: (Boolean) -> Unit,
    onDailyTarget: (WallpaperTarget) -> Unit,
    onUnmeteredOnly: (Boolean) -> Unit,
    onColorMode: (ColorMode) -> Unit,
) {
    val settings = state.settings
    val context = LocalContext.current
    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(rememberTopAppBarState())

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            LargeTopAppBar(
                title = { Text(stringResource(R.string.settings)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                scrollBehavior = scrollBehavior,
            )
        },
        contentWindowInsets = WindowInsets(0),
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(top = padding.calculateTopPadding())
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
        ) {
            Group(stringResource(R.string.group_daily)) {
                SettingRow(
                    icon = Icons.Rounded.Schedule,
                    polygon = MaterialShapes.Cookie9Sided,
                    title = stringResource(R.string.daily_title),
                    subtitle = stringResource(R.string.daily_subtitle, state.source.name),
                    position = Position.FIRST,
                    onClick = { onDailyEnabled(!settings.dailyEnabled) },
                    trailing = { Switch(checked = settings.dailyEnabled, onCheckedChange = onDailyEnabled) },
                )
                SettingRow(
                    icon = Icons.Rounded.Wifi,
                    polygon = MaterialShapes.Sunny,
                    title = stringResource(R.string.unmetered_title),
                    subtitle = stringResource(R.string.unmetered_subtitle),
                    position = Position.MIDDLE,
                    enabled = settings.dailyEnabled,
                    onClick = { onUnmeteredOnly(!settings.unmeteredOnly) },
                    trailing = {
                        Switch(
                            checked = settings.unmeteredOnly,
                            onCheckedChange = onUnmeteredOnly,
                            enabled = settings.dailyEnabled,
                        )
                    },
                )
                SettingRow(
                    icon = Icons.Rounded.Wallpaper,
                    polygon = MaterialShapes.Clover4Leaf,
                    title = stringResource(R.string.daily_target_title),
                    position = Position.LAST,
                    enabled = settings.dailyEnabled,
                    below = {
                        Choice(
                            options = WallpaperTarget.entries,
                            selected = settings.dailyTarget,
                            enabled = settings.dailyEnabled,
                            label = { target ->
                                stringResource(
                                    when (target) {
                                        WallpaperTarget.HOME -> R.string.target_home_short
                                        WallpaperTarget.LOCK -> R.string.target_lock_short
                                        WallpaperTarget.BOTH -> R.string.target_both_short
                                    },
                                )
                            },
                            onSelect = onDailyTarget,
                        )
                    },
                )
            }

            Group(stringResource(R.string.group_appearance)) {
                val systemColors = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                SettingRow(
                    icon = if (settings.colorMode == ColorMode.COSMIC) Icons.Rounded.AutoAwesome else Icons.Rounded.Palette,
                    polygon = MaterialShapes.Flower,
                    title = stringResource(R.string.colors_title),
                    subtitle = stringResource(
                        if (settings.colorMode == ColorMode.COSMIC) R.string.colors_cosmic_subtitle else R.string.colors_system_subtitle,
                    ),
                    position = Position.ONLY,
                    below = {
                        Choice(
                            options = if (systemColors) ColorMode.entries else listOf(ColorMode.COSMIC),
                            selected = settings.colorMode,
                            label = { mode ->
                                stringResource(if (mode == ColorMode.COSMIC) R.string.colors_cosmic else R.string.colors_system)
                            },
                            onSelect = onColorMode,
                        )
                    },
                )
            }

            Group(stringResource(R.string.group_about)) {
                SettingRow(
                    icon = Icons.Rounded.Code,
                    polygon = MaterialShapes.Gem,
                    title = stringResource(R.string.about_app, BuildConfig.VERSION_NAME),
                    subtitle = stringResource(R.string.about_app_subtitle),
                    position = Position.ONLY,
                    onClick = {
                        context.startActivity(
                            Intent(Intent.ACTION_VIEW, "https://github.com/ProfessorEngineergit/caelum".toUri()),
                        )
                    },
                )
            }

            Spacer(Modifier.height(24.dp))
            Spacer(Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
        }
    }
}

private enum class Position { FIRST, MIDDLE, LAST, ONLY }

@Composable
private fun Group(title: String, content: @Composable () -> Unit) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 12.dp, top = 24.dp, bottom = 10.dp),
    )
    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) { content() }
}

/** A row of an expressive segmented list: rounded group ends, tight seams between rows. */
@Composable
private fun SettingRow(
    icon: ImageVector,
    polygon: RoundedPolygon,
    title: String,
    position: Position,
    subtitle: String? = null,
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    below: (@Composable () -> Unit)? = null,
) {
    val outer = 28.dp
    val inner = 6.dp
    val top = if (position == Position.FIRST || position == Position.ONLY) outer else inner
    val bottom = if (position == Position.LAST || position == Position.ONLY) outer else inner
    val shape = RoundedCornerShape(topStart = top, topEnd = top, bottomStart = bottom, bottomEnd = bottom)
    val iconShape = remember(polygon) { polygon.toShape() }
    val alpha = if (enabled) 1f else 0.5f

    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .then(if (onClick != null && enabled) Modifier.clickable(onClick = onClick) else Modifier),
    ) {
        ListItem(
            headlineContent = { Text(title, style = MaterialTheme.typography.titleMedium) },
            supportingContent = subtitle?.let { { Text(it) } },
            leadingContent = {
                Box(
                    Modifier
                        .size(40.dp)
                        .clip(iconShape)
                        .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = alpha)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        icon,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = alpha),
                    )
                }
            },
            trailingContent = trailing,
            colors = ListItemDefaults.colors(
                containerColor = Color.Transparent,
                headlineColor = MaterialTheme.colorScheme.onSurface.copy(alpha = alpha),
                supportingColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = alpha),
            ),
        )
        below?.let {
            Box(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp)) { it() }
        }
    }
}

@Composable
private fun <T> Choice(
    options: List<T>,
    selected: T,
    label: @Composable (T) -> String,
    onSelect: (T) -> Unit,
    enabled: Boolean = true,
) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        options.forEachIndexed { index, option ->
            SegmentedButton(
                selected = option == selected,
                onClick = { onSelect(option) },
                shape = SegmentedButtonDefaults.itemShape(index, options.size),
                enabled = enabled,
            ) {
                Text(label(option))
            }
        }
    }
}
