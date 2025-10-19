package com.example.geowake2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Receives system boot completed and package replaced broadcasts to restore tracking
 * service and notifications if tracking was active before reboot.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val KEY_TRACKING_ACTIVE = "flutter.tracking_active_v1"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "===============================================")
        Log.d(TAG, "onReceive CALLED!")
        Log.d(TAG, "intent: $intent")
        Log.d(TAG, "action: ${intent?.action}")
        Log.d(TAG, "===============================================")

        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d(TAG, "Boot/restart event received: ${intent.action}")
                restoreTrackingIfNeeded(context)
            }
            else -> {
                Log.w(TAG, "Unknown action received: ${intent?.action}")
            }
        }
    }

    private fun restoreTrackingIfNeeded(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val trackingActive = prefs.getBoolean(KEY_TRACKING_ACTIVE, false)
            
            Log.d(TAG, "Tracking active flag: $trackingActive")
            
            if (trackingActive) {
                Log.d(TAG, "Tracking was active, attempting to restore service")
                
                // Reschedule AlarmManager wake-ups
                try {
                    val interval = 10 * 60 * 1000L // 10 minutes
                    ProgressWakeScheduler.schedule(context, interval)
                    Log.d(TAG, "Rescheduled AlarmManager wake-ups")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to reschedule AlarmManager", e)
                }
                
                // Restore progress notification if there's cached data
                try {
                    val payloadKey = "flutter.gw_progress_payload_v1"
                    val payloadJson = prefs.getString(payloadKey, null)
                    if (payloadJson != null) {
                        Log.d(TAG, "Found cached progress notification, will be restored by app")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to check progress payload", e)
                }
                
                // Note: The actual service restart will be handled by the app when it launches
                // We just ensure that the necessary scheduling mechanisms are in place
            } else {
                Log.d(TAG, "Tracking was not active, no restoration needed")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in restoreTrackingIfNeeded", e)
        }
    }
}
