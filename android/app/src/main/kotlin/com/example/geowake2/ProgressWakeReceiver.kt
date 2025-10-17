package com.example.geowake2

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.geowake2.R

import org.json.JSONObject

class ProgressWakeReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PROGRESS_WAKE = "com.example.geowake2.PROGRESS_WAKE"
        private const val PROGRESS_NOTIFICATION_ID = 888
        private const val PROGRESS_PREF_KEY = "flutter.gw_progress_payload_v1"
        private const val SUPPRESS_PREF_KEY = "flutter.gw_progress_suppressed_v1"
        private const val CHANNEL_ID = "geowake_tracking_channel_v2"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_PROGRESS_WAKE) return
        showCachedNotification(context)
        ProgressWakeScheduler.reschedule(context)
    }

    private fun showCachedNotification(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val suppressed = prefs.getBoolean(SUPPRESS_PREF_KEY, false)
        if (suppressed) {
            return
        }
        val payloadJson = prefs.getString(PROGRESS_PREF_KEY, null) ?: return
        val payload = try {
            JSONObject(payloadJson)
        } catch (_: Exception) {
            return
        }
        val title = payload.optString("title", "GeoWake journey")
        val subtitle = payload.optString("subtitle", "")
        val progress = payload.optDouble("progress", 0.0)
        val manager = NotificationManagerCompat.from(context)
        ensureChannel(context)
        
        // Create content intent to open the app when notification is tapped
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("open_tracking", true)
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentPending = PendingIntent.getActivity(context, 9200, contentIntent, pendingFlags)
        
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setContentIntent(contentPending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setColor(Color.parseColor("#2C7BE5"))
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setProgress(1000, (progress.coerceIn(0.0, 1.0) * 1000).toInt(), false)

        val endIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_END_TRACKING
        }
        val ignoreIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_IGNORE_TRACKING
        }

        val endPending = PendingIntent.getBroadcast(context, 9201, endIntent, pendingFlags)
        val ignorePending = PendingIntent.getBroadcast(context, 9202, ignoreIntent, pendingFlags)

        builder.addAction(0, context.getString(R.string.notification_action_end_tracking), endPending)
        builder.addAction(0, context.getString(R.string.notification_action_ignore_tracking), ignorePending)

        manager.notify(PROGRESS_NOTIFICATION_ID, builder.build())
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "GeoWake Tracking",
            NotificationManager.IMPORTANCE_DEFAULT
        )
        nm.createNotificationChannel(channel)
    }
}
