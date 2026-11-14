package com.professorengineergit.caelum.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

/** Which screens get the wallpaper. */
enum class WallpaperTarget { HOME, LOCK, BOTH }

/** Where the interface takes its colours from. */
enum class ColorMode {
    /** From the picture on screen — "the UI wears the cosmos". */
    COSMIC,
    /** From the system wallpaper (Material You), on Android 12 and later. */
    SYSTEM,
}

data class Settings(
    val sourceId: String = "apod",
    val dailyEnabled: Boolean = false,
    val dailyTarget: WallpaperTarget = WallpaperTarget.BOTH,
    val unmeteredOnly: Boolean = true,
    val colorMode: ColorMode = ColorMode.COSMIC,
    /** The id of the image the daily job last applied, so it doesn't set it twice. */
    val lastDailyImageId: String? = null,
    /**
     * Whether the home wallpaper may be wider than the screen so it scrolls with the
     * launcher pages. Off crops it to exactly the screen, so nothing can scroll —
     * whatever the launcher (or ColorOS after a wallpaper change) is set to.
     */
    val wallpaperScrolling: Boolean = false,
    val hapticsEnabled: Boolean = true,
    /** Experimental: the start screen becomes a live home-screen preview. */
    val liveMode: Boolean = false,
    /** When the daily job last ran, and what came of it. */
    val lastDailyCheck: Long? = null,
    val lastDailyResult: DailyResult? = null,
)

/** The outcome of the daily job's latest run, shown in the settings. */
enum class DailyResult { APPLIED, UP_TO_DATE, FAILED }

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

class SettingsRepository(private val context: Context) {
    private object Keys {
        val source = stringPreferencesKey("source")
        val dailyEnabled = booleanPreferencesKey("daily_enabled")
        val dailyTarget = stringPreferencesKey("daily_target")
        val unmeteredOnly = booleanPreferencesKey("unmetered_only")
        val colorMode = stringPreferencesKey("color_mode")
        val lastDaily = stringPreferencesKey("last_daily_image")
        val scrolling = booleanPreferencesKey("wallpaper_scrolling")
        val haptics = booleanPreferencesKey("haptics")
        val liveMode = booleanPreferencesKey("live_mode")
        val lastCheck = longPreferencesKey("last_daily_check")
        val lastResult = stringPreferencesKey("last_daily_result")
    }

    val settings: Flow<Settings> = context.dataStore.data.map { p ->
        val defaults = Settings()
        Settings(
            sourceId = p[Keys.source] ?: defaults.sourceId,
            dailyEnabled = p[Keys.dailyEnabled] ?: defaults.dailyEnabled,
            dailyTarget = p[Keys.dailyTarget].toEnum(defaults.dailyTarget),
            unmeteredOnly = p[Keys.unmeteredOnly] ?: defaults.unmeteredOnly,
            colorMode = p[Keys.colorMode].toEnum(defaults.colorMode),
            lastDailyImageId = p[Keys.lastDaily],
            wallpaperScrolling = p[Keys.scrolling] ?: defaults.wallpaperScrolling,
            hapticsEnabled = p[Keys.haptics] ?: defaults.hapticsEnabled,
            liveMode = p[Keys.liveMode] ?: defaults.liveMode,
            lastDailyCheck = p[Keys.lastCheck],
            lastDailyResult = p[Keys.lastResult]?.let { name -> DailyResult.entries.firstOrNull { it.name == name } },
        )
    }.distinctUntilChanged()

    suspend fun current(): Settings = settings.first()

    suspend fun setSource(id: String) = edit { it[Keys.source] = id }
    suspend fun setDailyEnabled(enabled: Boolean) = edit { it[Keys.dailyEnabled] = enabled }
    suspend fun setDailyTarget(target: WallpaperTarget) = edit { it[Keys.dailyTarget] = target.name }
    suspend fun setUnmeteredOnly(value: Boolean) = edit { it[Keys.unmeteredOnly] = value }
    suspend fun setColorMode(mode: ColorMode) = edit { it[Keys.colorMode] = mode.name }
    suspend fun setLastDailyImage(id: String) = edit { it[Keys.lastDaily] = id }
    suspend fun setWallpaperScrolling(value: Boolean) = edit { it[Keys.scrolling] = value }
    suspend fun setHaptics(value: Boolean) = edit { it[Keys.haptics] = value }
    suspend fun setLiveMode(value: Boolean) = edit { it[Keys.liveMode] = value }
    suspend fun recordDailyRun(result: DailyResult, at: Long = System.currentTimeMillis()) = edit {
        it[Keys.lastCheck] = at
        it[Keys.lastResult] = result.name
    }

    private suspend fun edit(block: (MutablePreferences) -> Unit) {
        context.dataStore.edit { block(it) }
    }

    private inline fun <reified E : Enum<E>> String?.toEnum(default: E): E =
        this?.let { name -> enumValues<E>().firstOrNull { it.name == name } } ?: default
}
