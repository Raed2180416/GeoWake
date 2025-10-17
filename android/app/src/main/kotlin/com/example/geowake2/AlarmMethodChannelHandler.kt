package com.example.geowake2

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context.NOTIFICATION_SERVICE
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.geowake2.R
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AlarmMethodChannelHandler(private val activity: Activity) : MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.example.geowake2/alarm"
        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val KEY_NATIVE_END_ACK = "flutter.native_end_tracking_ack_v1"
        private var channelRef: MethodChannel? = null

        @JvmStatic
        fun registerWith(engine: FlutterEngine, activity: Activity) {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(AlarmMethodChannelHandler(activity))
            channelRef = channel
        }

        @JvmStatic
        fun notifyFlutterOfEndTracking(context: Context, source: String) {
            val payload = mapOf("source" to source)
            Handler(Looper.getMainLooper()).post {
                try {
                    channelRef?.invokeMethod("nativeEndTrackingTriggered", payload)
                        ?: Log.w("AlarmMethodChannel", "Channel not ready for nativeEndTrackingTriggered")
                } catch (e: Exception) {
                    Log.e("AlarmMethodChannel", "Failed to notify Flutter of end tracking", e)
                }
            }
        }

        @JvmStatic
        fun notifyFlutterOfIgnoreTracking(source: String) {
            val payload = mapOf("source" to source)
            Handler(Looper.getMainLooper()).post {
                try {
                    channelRef?.invokeMethod("nativeIgnoreTrackingTriggered", payload)
                        ?: Log.w("AlarmMethodChannel", "Channel not ready for nativeIgnoreTrackingTriggered")
                } catch (e: Exception) {
                    Log.e("AlarmMethodChannel", "Failed to notify Flutter of ignore tracking", e)
                }
            }
        }

        @JvmStatic
        fun clearEndTrackingAck(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_NATIVE_END_ACK).apply()
        }

        @JvmStatic
        fun markEndTrackingAck(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_NATIVE_END_ACK, true).apply()
        }

        @JvmStatic
        fun isEndTrackingAcknowledged(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_NATIVE_END_ACK, false)
        }
    }

    private val context: Context = activity.applicationContext

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "launchAlarmActivity" -> {
                try {
                    startVibration()

                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val allowContinue = call.argument<Boolean>("allowContinue") ?: true

                    val intent = Intent(context, AlarmActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)

                    val extras = Bundle()
                    extras.putString("title", title ?: "Wake Up!")
                    extras.putString("body", body ?: "Approaching destination")
                    extras.putBoolean("allowContinue", allowContinue)
                    intent.putExtras(extras)

                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("LAUNCH_FAILED", "Failed to launch AlarmActivity", e.message)
                }
            }
            "stopVibration" -> {
                stopVibration()
                result.success(true)
            }
            "endTracking" -> {
                try {
                    // Stop any ongoing vibration
                    stopVibration()

                    NotificationActionReceiver.performEndTracking(context)

                    result.success(true)
                } catch (e: Exception) {
                    result.error("ENDTRACKING_FAILED", "Failed to perform native endTracking fallback", e.message)
                }
            }
            "handleEndTracking" -> {
                try {
                    // Broadcast the END_TRACKING intent to the receiver
                    val intent = Intent(context, NotificationActionReceiver::class.java)
                    intent.action = NotificationActionReceiver.ACTION_END_TRACKING
                    context.sendBroadcast(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("HANDLE_END_TRACKING_FAILED", "Failed to broadcast END_TRACKING", e.message)
                }
            }
            "handleIgnoreTracking" -> {
                try {
                    // Broadcast the IGNORE_TRACKING intent to the receiver
                    val intent = Intent(context, NotificationActionReceiver::class.java)
                    intent.action = NotificationActionReceiver.ACTION_IGNORE_TRACKING
                    context.sendBroadcast(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("HANDLE_IGNORE_TRACKING_FAILED", "Failed to broadcast IGNORE_TRACKING", e.message)
                }
            }
            "scheduleProgressWake" -> {
                val intervalMs = call.argument<Long>("intervalMs") ?: 10 * 60 * 1000L
                ProgressWakeScheduler.schedule(context, intervalMs)
                result.success(true)
            }
            "cancelProgressWake" -> {
                ProgressWakeScheduler.cancel(context)
                result.success(true)
            }
            "shouldPromptBatteryOptimization" -> {
                result.success(shouldPromptBatteryOptimization())
            }
            "requestBatteryOptimizationPrompt" -> {
                result.success(requestBatteryOptimizationPrompt())
            }
            "decorateProgressNotification" -> {
                val title = call.argument<String>("title") ?: "GeoWake journey"
                val subtitle = call.argument<String>("subtitle") ?: ""
                val progress = call.argument<Double>("progress") ?: 0.0
                decorateProgressNotification(title, subtitle, progress)
                result.success(true)
            }
            "cancelProgressNotification" -> {
                cancelProgressNotification()
                result.success(true)
            }
            "acknowledgeNativeEndTracking" -> {
                markEndTrackingAck(context)
                result.success(true)
            }
            "acknowledgeNativeIgnoreTracking" -> {
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun startVibration() {
        try {
            val vibratePattern = longArrayOf(0, 500, 250, 500, 250, 500, 250, 1000, 500)

            val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(VibratorManager::class.java)
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            if (vibrator != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val effect = VibrationEffect.createWaveform(vibratePattern, 0)
                    vibrator.vibrate(effect)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(vibratePattern, 0)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopVibration() {
        try {
            val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(VibratorManager::class.java)
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            vibrator?.cancel()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun shouldPromptBatteryOptimization(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return !powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun requestBatteryOptimizationPrompt(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
            if (intent.resolveActivity(context.packageManager) != null) {
                activity.startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun decorateProgressNotification(title: String, subtitle: String, progress: Double) {
        android.util.Log.d("AlarmMethodChannel", "decorateProgressNotification called: title=$title, progress=$progress")
        val manager = NotificationManagerCompat.from(context)
        ensureTrackingChannel()
        
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
        val contentPending = PendingIntent.getActivity(context, 9300, contentIntent, pendingFlags)
        
        val builder = NotificationCompat.Builder(context, "geowake_tracking_channel_v2")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setContentIntent(contentPending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setProgress(1000, (progress.coerceIn(0.0, 1.0) * 1000).toInt(), false)

        val endIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_END_TRACKING
        }
        val ignoreIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_IGNORE_TRACKING
        }

        val endPending = PendingIntent.getBroadcast(context, 9301, endIntent, pendingFlags)
        val ignorePending = PendingIntent.getBroadcast(context, 9302, ignoreIntent, pendingFlags)

        android.util.Log.d("AlarmMethodChannel", "Adding action buttons with PendingIntents")
        builder.addAction(0, context.getString(R.string.notification_action_end_tracking), endPending)
        builder.addAction(0, context.getString(R.string.notification_action_ignore_tracking), ignorePending)

        android.util.Log.d("AlarmMethodChannel", "Showing notification with ID 888")
        manager.notify(888, builder.build())
    }

    private fun cancelProgressNotification() {
        val manager = NotificationManagerCompat.from(context)
        manager.cancel(888)
    }

    private fun ensureTrackingChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            "geowake_tracking_channel_v2",
            "GeoWake Tracking",
            NotificationManager.IMPORTANCE_DEFAULT
        )
        nm.createNotificationChannel(channel)
    }
}
