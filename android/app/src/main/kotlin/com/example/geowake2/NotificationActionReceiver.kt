package com.example.geowake2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import java.io.File

class NotificationActionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "NotificationActionRx"
        const val ACTION_END_TRACKING = "com.example.geowake2.ACTION_END_TRACKING"
        const val ACTION_IGNORE_TRACKING = "com.example.geowake2.ACTION_IGNORE_TRACKING"

        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val KEY_PROGRESS_SUPPRESSED = "flutter.gw_progress_suppressed_v1"
        private const val KEY_PROGRESS_PAYLOAD = "flutter.gw_progress_payload_v1"
        private const val KEY_TRACKING_ACTIVE = "flutter.tracking_active_v1"
        private const val KEY_TRACKING_SESSION = "flutter.tracking_session_json_v1"
        private const val KEY_RESUME_PENDING = "flutter.tracking_resume_pending_v1"
        private const val PROGRESS_NOTIFICATION_ID = 888
        private const val ALARM_NOTIFICATION_ID = 0

        @JvmStatic
        fun performEndTracking(context: Context) {
            Log.d(TAG, "performEndTracking: Starting complete tracking shutdown")
            // Set a flag that the Dart heartbeat will check
            setNativeEndTrackingFlag(context, true)
            // Mark progress as suppressed
            markProgressSuppressed(context, true)
            // Clear all tracking state
            clearTrackingState(context)
            // Cancel all notifications
            cancelNotifications(context)
            // Stop any alarm feedback (vibration)
            stopAlarmFeedback(context)
            // Cancel alarm manager wake-ups
            ProgressWakeScheduler.cancel(context)
            AlarmMethodChannelHandler.clearEndTrackingAck(context)
            AlarmMethodChannelHandler.notifyFlutterOfEndTracking(context, "notification_action")
            // Stop the background service - this is critical
            // Give the Dart side a moment to see the flag, then force stop
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (!AlarmMethodChannelHandler.isEndTrackingAcknowledged(context)) {
                    Log.w(TAG, "performEndTracking: No Flutter ack; forcing stop")
                    stopBackgroundService(context)
                } else {
                    Log.d(TAG, "performEndTracking: Flutter ack received; skip forced stop")
                }
            }, 10000)
            Log.d(TAG, "performEndTracking: Complete")
        }

        private fun setNativeEndTrackingFlag(context: Context, value: Boolean) {
            Log.d(TAG, "setNativeEndTrackingFlag: $value")
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("flutter.native_end_tracking_signal_v1", value)
                .apply()
        }

        @JvmStatic
        fun performIgnoreTracking(context: Context) {
            Log.d(TAG, "performIgnoreTracking: Suppressing notifications but keeping tracking active")
            // Set suppression flag to prevent further progress notifications
            markProgressSuppressed(context, true)
            // Clear the progress payload so it doesn't get restored
            clearProgressPayload(context)
            // Cancel only the progress notification, but DO NOT stop tracking
            cancelProgressNotification(context)
            // Cancel the alarm manager wake-ups since we're suppressing notifications
            ProgressWakeScheduler.cancel(context)
            AlarmMethodChannelHandler.notifyFlutterOfIgnoreTracking("notification_action")
            // DO NOT call stopBackgroundService or clearTrackingState - keep tracking running silently
            Log.d(TAG, "performIgnoreTracking: Complete - tracking continues in background")
        }

        private fun markProgressSuppressed(context: Context, suppressed: Boolean) {
            Log.d(TAG, "markProgressSuppressed: $suppressed")
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_PROGRESS_SUPPRESSED, suppressed)
                .apply()
        }

        private fun clearProgressPayload(context: Context) {
            Log.d(TAG, "clearProgressPayload")
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_PROGRESS_PAYLOAD).apply()
        }

        private fun clearTrackingState(context: Context) {
            Log.d(TAG, "clearTrackingState: Clearing all tracking preferences and files")
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_TRACKING_ACTIVE, false)
                .putBoolean(KEY_RESUME_PENDING, false)
                .remove(KEY_TRACKING_SESSION)
                .apply()

            deleteIfExists(File(context.filesDir, "tracking_session.json"))
            try {
                val supportDir = context.getDir("app_flutter", Context.MODE_PRIVATE)
                deleteIfExists(File(supportDir, "tracking_session.json"))
            } catch (_: Exception) {}
            try {
                val docs = context.getExternalFilesDir(null)
                if (docs != null) {
                    deleteIfExists(File(docs, "tracking_session.json"))
                }
            } catch (_: Exception) {}
        }

        private fun deleteIfExists(file: File) {
            try {
                if (file.exists()) {
                    val deleted = file.delete()
                    Log.d(TAG, "deleteIfExists: ${file.name} deleted=$deleted")
                }
            } catch (_: Exception) {}
        }

        private fun cancelNotifications(context: Context) {
            Log.d(TAG, "cancelNotifications: Cancelling progress and alarm notifications")
            val manager = NotificationManagerCompat.from(context)
            manager.cancel(PROGRESS_NOTIFICATION_ID)
            manager.cancel(ALARM_NOTIFICATION_ID)
        }

        private fun cancelProgressNotification(context: Context) {
            Log.d(TAG, "cancelProgressNotification: Cancelling only progress notification")
            val manager = NotificationManagerCompat.from(context)
            manager.cancel(PROGRESS_NOTIFICATION_ID)
        }

        private fun stopAlarmFeedback(context: Context) {
            Log.d(TAG, "stopAlarmFeedback: Stopping vibration")
            try {
                val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val vm = context.getSystemService(VibratorManager::class.java)
                    vm?.defaultVibrator
                } else {
                    @Suppress("DEPRECATION")
                    context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                }
                vibrator?.cancel()
            } catch (_: Exception) {}
        }

        private fun stopBackgroundService(context: Context) {
            Log.d(TAG, "stopBackgroundService: Attempting to stop flutter_background_service")
            try {
                val serviceClass = Class.forName("id.flutter.flutter_background_service.BackgroundService")
                val serviceIntent = Intent(context, serviceClass)
                val stopped = context.stopService(serviceIntent)
                Log.d(TAG, "stopBackgroundService: stopService result=$stopped")
            } catch (e: Exception) {
                Log.e(TAG, "stopBackgroundService: Failed to stop service", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "===============================================")
        Log.d(TAG, "onReceive CALLED!")
        Log.d(TAG, "intent: $intent")
        Log.d(TAG, "action: ${intent?.action}")
        Log.d(TAG, "===============================================")
        when (intent?.action) {
            ACTION_END_TRACKING -> {
                Log.d(TAG, "Matched ACTION_END_TRACKING - calling performEndTracking")
                performEndTracking(context)
            }
            ACTION_IGNORE_TRACKING -> {
                Log.d(TAG, "Matched ACTION_IGNORE_TRACKING - calling performIgnoreTracking")
                performIgnoreTracking(context)
            }
            else -> {
                Log.w(TAG, "Unknown action received: ${intent?.action}")
            }
        }
    }
}
