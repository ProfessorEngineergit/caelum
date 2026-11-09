package com.professorengineergit.caelum.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
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
)

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

class SettingsRepository(private val context: Context) {
    private object Keys {
        val source = stringPreferencesKey("source")
        val dailyEnabled = booleanPreferencesKey("daily_enabled")
        val dailyTarget = stringPreferencesKey("daily_target")
        val unmeteredOnly = booleanPreferencesKey("unmetered_only")
        val colorMode = stringPreferencesKey("color_mode")
        val lastDaily = stringPreferencesKey("last_daily_image")
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
        )
    }.distinctUntilChanged()

    suspend fun current(): Settings = settings.first()

    suspend fun setSource(id: String) = edit { it[Keys.source] = id }
    suspend fun setDailyEnabled(enabled: Boolean) = edit { it[Keys.dailyEnabled] = enabled }
    suspend fun setDailyTarget(target: WallpaperTarget) = edit { it[Keys.dailyTarget] = target.name }
    suspend fun setUnmeteredOnly(value: Boolean) = edit { it[Keys.unmeteredOnly] = value }
    suspend fun setColorMode(mode: ColorMode) = edit { it[Keys.colorMode] = mode.name }
    suspend fun setLastDailyImage(id: String) = edit { it[Keys.lastDaily] = id }

    private suspend fun edit(block: (MutablePreferences) -> Unit) {
        context.dataStore.edit { block(it) }
    }

    private inline fun <reified E : Enum<E>> String?.toEnum(default: E): E =
        this?.let { name -> enumValues<E>().firstOrNull { it.name == name } } ?: default
}
