package com.example.geowake2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Receives fallback alarms when the app has been killed.
 * This is the safety net that ensures users are woken up even if 
 * the background service has been terminated.
 * 
 * Part of CRITICAL-002 fix: Background Service Kill Without Recovery
 */
class FallbackAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "FallbackAlarmReceiver"
        private const val CHANNEL_ID = "geowake_fallback_alarm"
        private const val NOTIFICATION_ID = 9001
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "Fallback alarm received - app was likely killed")
        
        val routeId = intent.getStringExtra("routeId")
        val destinationLat = intent.getDoubleExtra("destinationLat", 0.0)
        val destinationLng = intent.getDoubleExtra("destinationLng", 0.0)
        val destinationName = intent.getStringExtra("destinationName") ?: "your destination"
        
        Log.i(TAG, "Fallback alarm for: $destinationName (route: $routeId)")
        
        // Create notification channel if needed
        createNotificationChannel(context)
        
        // Show critical alarm notification
        showFallbackAlarmNotification(context, destinationName)
        
        // Try to restart the app to the alarm screen
        tryRestartApp(context, destinationName)
    }
    
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Fallback Alarms"
            val descriptionText = "Critical fallback alarms when app is killed"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                setShowBadge(true)
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun showFallbackAlarmNotification(context: Context, destinationName: String) {
        // Create intent to launch the app
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("showAlarm", true)
            putExtra("fallbackAlarm", true)
            putExtra("destinationName", destinationName)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm) // Use a built-in alarm icon
            .setContentTitle("⚠️ Wake Up!")
            .setContentText("Approaching: $destinationName")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("You're approaching $destinationName.\n\nThis is a fallback alarm because the app was closed."))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000))
            .setSound(android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI)
            .build()
        
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        Log.i(TAG, "Fallback alarm notification shown")
    }
    
    private fun tryRestartApp(context: Context, destinationName: String) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("showAlarm", true)
                putExtra("fallbackAlarm", true)
                putExtra("destinationName", destinationName)
            }
            context.startActivity(intent)
            Log.i(TAG, "Attempted to restart app to alarm screen")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart app", e)
        }
    }
}
