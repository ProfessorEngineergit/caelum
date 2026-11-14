package com.professorengineergit.caelum.work

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.professorengineergit.caelum.container
import com.professorengineergit.caelum.data.DailyResult
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit

/**
 * Sets the newest picture of the chosen source as the wallpaper — but only when it changed.
 *
 * Three things wake it, because phone makers (ColorOS especially) defer background
 * work of apps that are rarely opened, sometimes for a whole day:
 *  1. an alarm a few minutes after NASA publishes the new APOD (midnight in New York),
 *  2. a periodic job every three hours as a safety net,
 *  3. opening the app.
 */
class DailyWallpaperWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val container = applicationContext.container
        val settings = container.settings.current()
        if (!settings.dailyEnabled) return Result.success()

        return try {
            val source = container.sources.byId(settings.sourceId)
            val newest = source.fetchRecent(4).firstOrNull { !it.isVideo }
            if (newest != null && newest.id != settings.lastDailyImageId) {
                container.wallpaper.apply(newest, settings.dailyTarget, settings.wallpaperScrolling)
                container.settings.setLastDailyImage(newest.id)
                container.settings.recordApplied(newest, settings.dailyTarget)
                container.settings.recordDailyRun(DailyResult.APPLIED)
            } else {
                container.settings.recordDailyRun(DailyResult.UP_TO_DATE)
            }
            Result.success()
        } catch (e: Exception) {
            if (runAttemptCount < 4) {
                Result.retry()
            } else {
                container.settings.recordDailyRun(DailyResult.FAILED)
                Result.failure()
            }
        }
    }
}

/** Fired by the publish-time alarm and after a reboot: runs the job and sets the next alarm. */
class DailyAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            try {
                if (context.container.settings.current().dailyEnabled) {
                    DailyWallpaper.runNow(context)
                    DailyWallpaper.scheduleAlarm(context)
                }
            } finally {
                pending.finish()
            }
        }
    }
}

object DailyWallpaper {
    private const val WORK_NAME = "daily-wallpaper"

    fun schedule(context: Context, enabled: Boolean, unmeteredOnly: Boolean) {
        val work = WorkManager.getInstance(context)
        if (!enabled) {
            work.cancelUniqueWork(WORK_NAME)
            cancelAlarm(context)
            return
        }
        val request = PeriodicWorkRequestBuilder<DailyWallpaperWorker>(3, TimeUnit.HOURS, 1, TimeUnit.HOURS)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(if (unmeteredOnly) NetworkType.UNMETERED else NetworkType.CONNECTED)
                    .build(),
            )
            .setBackoffCriteria(androidx.work.BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
            .build()
        work.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request)
        scheduleAlarm(context)
    }

    /** Runs the job once soon, e.g. right after it was switched on, the source changed, or the app opened. */
    fun runNow(context: Context) {
        val request = OneTimeWorkRequestBuilder<DailyWallpaperWorker>()
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setBackoffCriteria(androidx.work.BackoffPolicy.EXPONENTIAL, 10, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork("$WORK_NAME-now", ExistingWorkPolicy.REPLACE, request)
    }

    /**
     * An alarm for ten minutes after the next APOD goes up (00:00 America/New_York),
     * allowed to fire in Doze. Inexact by a few minutes, which needs no special permission.
     */
    fun scheduleAlarm(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val newYork = ZoneId.of("America/New_York")
        val now = ZonedDateTime.now(newYork)
        var next = now.toLocalDate().atTime(LocalTime.of(0, 10)).atZone(newYork)
        if (!next.isAfter(now)) next = next.plusDays(1)
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.toInstant().toEpochMilli(), alarmIntent(context))
    }

    private fun cancelAlarm(context: Context) {
        context.getSystemService(AlarmManager::class.java)?.cancel(alarmIntent(context))
    }

    private fun alarmIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, DailyAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /** Whether the system leaves Caelum's background work alone (battery optimisation off). */
    fun isUnrestricted(context: Context): Boolean =
        context.getSystemService(PowerManager::class.java)?.isIgnoringBatteryOptimizations(context.packageName) == true
}
