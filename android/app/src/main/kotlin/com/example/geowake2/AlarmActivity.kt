package com.example.geowake2

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class AlarmActivity : FlutterActivity() {
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val vibratePattern = longArrayOf(0, 500, 250, 500, 250, 1000, 500)
    
    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d("AlarmActivity", "onCreate called - setting up alarm activity")
        
        // CRITICAL: Set window flags BEFORE super.onCreate() to ensure proper lock screen behavior
        // This is essential for the alarm to show on locked devices
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            // Also add Keep Screen On for continuous visibility
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        
        // Acquire wake lock to ensure device stays awake for alarm
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or 
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "GeoWake::AlarmWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(10 * 60 * 1000L) // 10 minutes max
            }
            Log.d("AlarmActivity", "WakeLock acquired successfully")
        } catch (e: Exception) {
            Log.e("AlarmActivity", "Failed to acquire wake lock", e)
        }
        
        // For API >= 27, request keyguard dismissal
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            try {
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                keyguardManager.requestDismissKeyguard(this, null)
                Log.d("AlarmActivity", "Keyguard dismissal requested")
            } catch (e: Exception) {
                Log.e("AlarmActivity", "Failed to dismiss keyguard", e)
            }
        }
        
        // Set audio to use alarm stream
        volumeControlStream = AudioManager.STREAM_ALARM
        
        // Optionally raise volume for alarm (can be configured)
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            // Only raise if volume is very low
            if (currentVolume < maxVolume * 0.3) {
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, (maxVolume * 0.7).toInt(), 0)
                Log.d("AlarmActivity", "Volume raised for alarm")
            }
        } catch (e: Exception) {
            Log.e("AlarmActivity", "Failed to adjust volume", e)
        }
        
        super.onCreate(savedInstanceState)
        
        Log.d("AlarmActivity", "Starting vibration and sound")
        
        // Initialize and start vibration
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            startVibrating()
        } catch (e: Exception) {
            Log.e("AlarmActivity", "Failed to initialize vibrator", e)
        }
        
        // Broadcast alarm information to Flutter layer
        try {
            if (intent?.extras != null) {
                val extras = intent.extras
                if (extras != null) {
                    val flutterIntent = Intent("com.example.geowake2.ALARM_TRIGGERED")
                    flutterIntent.putExtras(extras)
                    sendBroadcast(flutterIntent)
                    Log.d("AlarmActivity", "Alarm broadcast sent to Flutter")
                }
            }
        } catch (e: Exception) {
            Log.e("AlarmActivity", "Failed to send alarm broadcast", e)
        }
    }
    
    private fun startVibrating() {
        vibrator?.let {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val audioAttributes = AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                    
                    it.vibrate(
                        VibrationEffect.createWaveform(vibratePattern, 0), // Repeat indefinitely
                        audioAttributes
                    )
                } else {
                    @Suppress("DEPRECATION")
                    it.vibrate(vibratePattern, 0) // Repeat indefinitely
                }
                Log.d("AlarmActivity", "Vibration started successfully")
            } catch (e: Exception) {
                Log.e("AlarmActivity", "Failed to start vibration", e)
            }
        } ?: Log.w("AlarmActivity", "Vibrator is null, cannot start vibration")
    }
    
    override fun onDestroy() {
        Log.d("AlarmActivity", "onDestroy called - cleaning up")
        
        // Stop vibration
        try {
            vibrator?.cancel()
            Log.d("AlarmActivity", "Vibration cancelled")
        } catch (e: Exception) {
            Log.e("AlarmActivity", "Failed to cancel vibration", e)
        }
        
        // Release wake lock
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d("AlarmActivity", "WakeLock released")
                }
            }
        } catch (e: Exception) {
            Log.e("AlarmActivity", "Failed to release wake lock", e)
        }
        
        super.onDestroy()
    }
    
    override fun onPause() {
        super.onPause()
        // Keep the activity visible even when paused (for lock screen scenarios)
        Log.d("AlarmActivity", "onPause called")
    }
    
    override fun onResume() {
        super.onResume()
        Log.d("AlarmActivity", "onResume called")
        // Ensure vibration continues if it was stopped
        if (vibrator?.hasVibrator() == true) {
            startVibrating()
        }
    }
}