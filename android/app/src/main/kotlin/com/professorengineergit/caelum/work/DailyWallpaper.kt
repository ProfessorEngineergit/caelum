package com.professorengineergit.caelum.work

import android.content.Context
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
import java.util.concurrent.TimeUnit

/**
 * Sets the newest picture of the chosen source as the wallpaper, a few times a day
 * so a new APOD shows up soon after NASA publishes it — but only when it changed.
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
                ?: return Result.success()
            if (newest.id != settings.lastDailyImageId) {
                container.wallpaper.apply(newest, settings.dailyTarget)
                container.settings.setLastDailyImage(newest.id)
            }
            Result.success()
        } catch (e: Exception) {
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }
}

object DailyWallpaper {
    private const val WORK_NAME = "daily-wallpaper"

    fun schedule(context: Context, enabled: Boolean, unmeteredOnly: Boolean) {
        val work = WorkManager.getInstance(context)
        if (!enabled) {
            work.cancelUniqueWork(WORK_NAME)
            return
        }
        val request = PeriodicWorkRequestBuilder<DailyWallpaperWorker>(6, TimeUnit.HOURS)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(if (unmeteredOnly) NetworkType.UNMETERED else NetworkType.CONNECTED)
                    .setRequiresBatteryNotLow(true)
                    .build(),
            )
            .build()
        work.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request)
    }

    /** Runs the job once soon, e.g. right after it was switched on or the source changed. */
    fun runNow(context: Context) {
        val request = OneTimeWorkRequestBuilder<DailyWallpaperWorker>()
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork("$WORK_NAME-now", ExistingWorkPolicy.REPLACE, request)
    }
}
