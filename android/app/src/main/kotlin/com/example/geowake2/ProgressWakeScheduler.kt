package com.example.geowake2

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object ProgressWakeScheduler {
    private const val REQUEST_CODE = 9002
    private const val PREFS_NAME = "geowake_progress_wake"
    private const val KEY_INTERVAL = "interval"

    fun schedule(context: Context, intervalMs: Long) {
    val adjustedInterval = intervalMs.coerceAtLeast(60 * 1000L)
        saveInterval(context, adjustedInterval)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val triggerAt = System.currentTimeMillis() + adjustedInterval
        val pending = buildPendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
        }
    }

    fun cancel(context: Context) {
        clearInterval(context)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmManager.cancel(buildPendingIntent(context))
    }

    fun reschedule(context: Context) {
        val interval = readInterval(context)
        if (interval > 0) {
            schedule(context, interval)
        }
    }

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ProgressWakeReceiver::class.java).apply {
            action = ProgressWakeReceiver.ACTION_PROGRESS_WAKE
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
    }

    private fun saveInterval(context: Context, interval: Long) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putLong(KEY_INTERVAL, interval).apply()
    }

    private fun readInterval(context: Context): Long {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getLong(KEY_INTERVAL, 0L)
    }

    private fun clearInterval(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_INTERVAL).apply()
    }
}
