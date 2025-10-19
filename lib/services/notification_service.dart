// lib/services/notification_service.dart

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // For MethodChannel
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/services/navigation_service.dart';
import 'package:geowake2/screens/alarm_fullscreen.dart';
import 'package:geowake2/services/alarm_player.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as dev;

class NotificationService {
  // Singleton pattern to ensure only one instance of this service
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Allows tests to disable platform/plugin calls.
  static bool isTestMode = false;
  // Optional hook for tests to observe alarms without invoking plugins.
  // Signature: (title, body, allowContinueTracking)
  static Future<void> Function(String, String, bool)? testOnShowWakeUpAlarm;
  // Recorded alarm events for assertions in tests (title/body/allow)
  static final List<Map<String, dynamic>> testRecordedAlarms = [];

  static void clearTestRecordedAlarms() => testRecordedAlarms.clear();

  // Method channel to communicate with native Android code
  static const _alarmMethodChannel = MethodChannel('com.example.geowake2/alarm');
  static bool _nativeCallbacksRegistered = false;

  @visibleForTesting
  static Future<dynamic> Function(String method, Map<String, dynamic>? arguments)?
      debugMethodChannelInvoker;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const int _alarmNotificationId = 0;
  static const int _progressNotificationId = 888;
  static const String _progressPrefsKey = 'gw_progress_payload_v1';
  static const String _batteryPromptKey = 'gw_battery_prompt_v1';
  static Map<String, dynamic>? _lastProgressPayload;

  Map<String, dynamic>? get lastProgressPayload => _lastProgressPayload;

  void _openTrackingScreen() {
    final nav = NavigationService.navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamed('/mapTracking');
    } else {
      // Persist flag for bootstrap to consume on next launch
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('pending_tracking_launch', true);
      }).catchError((_) {});
    }
  }
  
  // Native method to directly launch the AlarmActivity
  Future<void> _launchNativeAlarmActivity({
    required String title,
    required String body,
    required bool allowContinueTracking,
  }) async {
    try {
      await _alarmMethodChannel.invokeMethod('launchAlarmActivity', {
        'title': title,
        'body': body,
        'allowContinue': allowContinueTracking,
      });
    } catch (e) {
      dev.log('Failed to launch native alarm activity: $e', name: 'NotificationService');
      throw e;
    }
  }
  
  // Stop native vibration
  Future<void> stopVibration() async {
    try {
      await _alarmMethodChannel.invokeMethod('stopVibration');
    } catch (e) {
      dev.log('Failed to stop vibration: $e', name: 'NotificationService');
    }
  }

  // Native endTracking fallback
  Future<void> endTrackingNativeFallback() async {
    try {
      await _alarmMethodChannel.invokeMethod('endTracking');
    } catch (e) {
      dev.log('Failed to invoke native endTracking: $e', name: 'NotificationService');
    }
  }

  // Public helper to cancel active alarm: stop sound, vibration, and clear notification
  Future<void> cancelAlarm() async {
    try { await AlarmPlayer.stop(); } catch (e) {
      dev.log('AlarmPlayer.stop failed: $e', name: 'NotificationService');
    }
    try { await stopVibration(); } catch (_) {}
    try { await _notificationsPlugin.cancel(_alarmNotificationId); } catch (e) {
      dev.log('Cancel alarm notification failed: $e', name: 'NotificationService');
    }
  }

  // Initialize the notification service
  Future<void> initialize() async {
    dev.log('NotificationService.initialize() start', name: 'NotificationService');
    // Settings for Android initialization
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Settings for iOS initialization
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Request full-screen intent permission on Android 14+ (API 34+)
    // This is critical for alarms to work on locked screens
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          // Request permission to show full-screen intents (Android 14+)
          final granted = await androidImpl.requestFullScreenIntentPermission();
          dev.log('Full screen intent permission: ${granted ?? false}', name: 'NotificationService');
        }
      } catch (e) {
        dev.log('Failed to request full screen intent permission: $e', name: 'NotificationService');
      }
    }

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        dev.log('Notification response: actionId=${response.actionId}, payload=${response.payload}', name: 'NotificationService');
        if (response.actionId == 'STOP_ALARM') {
          try { await AlarmPlayer.stop(); } catch (_) {}
          try { FlutterBackgroundService().invoke('stopAlarm'); } catch (_) {}
          return;
        }
        if (response.actionId == 'END_TRACKING') {
          // Delegate to native Android handler for reliability
          dev.log('END_TRACKING action - delegating to native handler', name: 'NotificationService');
          try { await _alarmMethodChannel.invokeMethod('handleEndTracking'); } catch (_) {}
          return;
        }
        if (response.actionId == 'IGNORE_TRACKING') {
          // Delegate to native Android handler for reliability
          dev.log('IGNORE_TRACKING action - delegating to native handler', name: 'NotificationService');
          try { await _alarmMethodChannel.invokeMethod('handleIgnoreTracking'); } catch (_) {}
          return;
        }
        if ((response.actionId == null || response.actionId!.isEmpty) && response.payload == 'open_tracking') {
          _openTrackingScreen();
          return;
        }
        if (response.payload != null && response.payload!.startsWith('open_alarm')) {
          bool allow = true;
          final parts = response.payload!.split(':');
          if (parts.length > 1) {
            allow = parts[1] == '1';
          }
          final nav = NavigationService.navigatorKey.currentState;
          if (nav != null) {
            nav.push(MaterialPageRoute(
              builder: (_) => AlarmFullscreen(
                title: 'Wake Up!',
                body: 'Approaching your target',
                allowContinueTracking: allow,
              ),
            ));
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Explicitly request Android notification permission (Android 13+)
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    } catch (e) {
      dev.log('Android notification permission request failed: $e', name: 'NotificationService');
    }

    // Create/ensure channels exist (alarm + tracking + bg service channel used by flutter_background_service)
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          'geowake_alarm_channel_v2',
          'GeoWake Alarms',
          description: 'Channel for GeoWake wake-up alarms',
          importance: Importance.max,
        ));
        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          'geowake_tracking_channel_v2',
          'GeoWake Tracking',
          description: 'Ongoing tracking status',
          importance: Importance.defaultImportance,
        ));
        // Also ensure legacy/background service channel exists as configured in TrackingService
        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          'geowake_tracking_channel',
          'GeoWake Tracking (Service)',
          description: 'Foreground service notifications',
          importance: Importance.defaultImportance,
        ));
      }
    } catch (e) {
      dev.log('Creating notification channels failed: $e', name: 'NotificationService');
    }

    dev.log('NotificationService.initialize() done', name: 'NotificationService');

    if (!_nativeCallbacksRegistered) {
      _alarmMethodChannel.setMethodCallHandler(_handleNativeMethodCall);
      _nativeCallbacksRegistered = true;
    }
  }

  // This is the main function to trigger the alarm
  Future<void> showWakeUpAlarm({
    required String title,
    required String body,
    bool allowContinueTracking = true,
  }) async {
    // Test-mode observability: always record, and call optional hook when present
    if (isTestMode || testOnShowWakeUpAlarm != null) {
      if (testOnShowWakeUpAlarm != null) {
        try { await testOnShowWakeUpAlarm!(title, body, allowContinueTracking); } catch (_) {}
      }
      try {
        testRecordedAlarms.add({
          'title': title,
          'body': body,
          'allow': allowContinueTracking,
          'ts': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    // If tests explicitly disabled platform behavior, skip showing.
    if (isTestMode) {
      return;
    }
    dev.log('ALARM TRIGGER: Showing wake-up alarm with title: "$title", body: "$body"', name: 'NotificationService');
    
    // 1. Store alarm info in SharedPreferences to recover if needed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_alarm_flag', true);
    await prefs.setString('pending_alarm_title', title);
    await prefs.setString('pending_alarm_body', body);
    await prefs.setBool('pending_alarm_allow', allowContinueTracking);

    // 2. Create high-priority alarm notification channel with vibration pattern
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        // A strong vibration pattern for alarm-like feel
        // Format: [delay, vibrate, sleep, vibrate, sleep, ...]
        // Enhanced vibration pattern that more closely matches Android's native alarm pattern
      // This includes varying vibration durations to create a more attention-grabbing pattern
      final vibrationPattern = Int64List.fromList([0, 500, 250, 500, 250, 1000, 500]);
        
        await androidImpl.createNotificationChannel(AndroidNotificationChannel(
          'geowake_alarm_channel_v3',
          'GeoWake Alarms (High Priority)',
          description: 'Channel for urgent GeoWake wake-up alarms',
          importance: Importance.max,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          playSound: false, // We'll use our AlarmPlayer instead
        ));
        
        // Request permission to show notifications on Android 13+
        try {
          await androidImpl.requestNotificationsPermission();
        } catch (e) {
          dev.log('Failed to request notification permission: $e', name: 'NotificationService');
        }
      }
    } catch (e) {
      dev.log('Failed to create/update alarm channel: $e', name: 'NotificationService');
    }

    // 3. Define the Android notification details, including vibration pattern
    // Enhanced vibration pattern that more closely matches Android's native alarm pattern
    // This includes varying vibration durations to create a more attention-grabbing pattern
    final vibrationPattern = Int64List.fromList([0, 500, 250, 500, 250, 1000, 500]);
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'geowake_alarm_channel_v3',
      'GeoWake Alarms (High Priority)',
      channelDescription: 'Channel for GeoWake wake-up alarms',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false, // Use AlarmPlayer for the custom sound
      fullScreenIntent: true,  // This is critical for lockscreen appearance
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      ongoing: true, // Make it ongoing so it can't be dismissed
      autoCancel: false,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      ticker: 'Destination alarm active',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('STOP_ALARM', 'Stop Alarm', showsUserInterface: false),
        AndroidNotificationAction('END_TRACKING', 'End Tracking', showsUserInterface: true),
      ],
    );

    // Define iOS notification details (sound name should be included in the app bundle)
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: false,
    );

    // Full-screen intent to bring app UI to foreground (lockscreen included).
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // 3. Show the notification and trigger alarm UI, sound, and vibration
    try {
      dev.log('Showing alarm notification with fullScreenIntent: "$title" - "$body"', name: 'NotificationService');
      
      // First show the notification
      await _notificationsPlugin.show(
        _alarmNotificationId,
        title,
        body,
        details,
        payload: 'open_alarm:${allowContinueTracking ? '1' : '0'}',
      );
      
      // Also directly launch the AlarmActivity via our native method channel
      try {
        await _launchNativeAlarmActivity(
          title: title,
          body: body,
          allowContinueTracking: allowContinueTracking,
        );
      } catch (e) {
        dev.log('Failed to launch native AlarmActivity: $e', name: 'NotificationService');
        
        // Fallback: Present the UI directly if we're in the foreground
        final nav = NavigationService.navigatorKey.currentState;
        if (nav != null) {
          dev.log('Fallback: presenting AlarmFullscreen UI directly', name: 'NotificationService');
          nav.push(MaterialPageRoute(
            builder: (_) => AlarmFullscreen(
              title: title,
              body: body,
              allowContinueTracking: allowContinueTracking,
            ),
          ));
        }
      }
      
      // Start playing the ringtone
      try {
        await AlarmPlayer.playSelected();
      } catch (e) {
        dev.log('Failed to play alarm sound: $e', name: 'NotificationService');
      }
      
    } catch (e) {
      dev.log('Failed to show alarm notification: $e', name: 'NotificationService');
    }
  }

  // Ongoing journey progress notification (non-dismissible)
  Future<void> showJourneyProgress({
    required String title,
    required String subtitle,
    required double progress0to1,
  }) async {
    final suppressed = TrackingService.suppressProgressNotifications || await TrackingService.isProgressSuppressed();
    if (suppressed) {
      // If user chose ignore, ensure any existing notification is cancelled so it slides away.
      try { await cancelJourneyProgress(); } catch (_) {}
      return;
    }
    
    // First, ensure we have the Android notification actions properly configured
    // by calling the native decorateProgressNotification which includes the action buttons
    try {
      await _alarmMethodChannel.invokeMethod('decorateProgressNotification', {
        'title': title,
        'subtitle': subtitle,
        'progress': progress0to1,
      });
      unawaited(scheduleProgressWakeFallback());
    } catch (e) {
      dev.log('Native decorateProgressNotification failed: $e', name: 'NotificationService');
    }
    
    // Persist the payload for recovery after process death or app backgrounding
    final payload = <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'progress': progress0to1,
      'ts': DateTime.now().toIso8601String(),
    };
    _lastProgressPayload = payload;
    if (!isTestMode) {
      await _persistProgressPayload(payload);
    }
  }

  Future<dynamic> _invokeAlarmChannel(String method, Map<String, dynamic>? arguments) async {
    if (debugMethodChannelInvoker != null) {
      return debugMethodChannelInvoker!(method, arguments);
    }
    return _alarmMethodChannel.invokeMethod(method, arguments);
  }

  Future<bool> _handleNativeMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'nativeEndTrackingTriggered':
          await _handleNativeEndTracking(call.arguments);
          return true;
        case 'nativeIgnoreTrackingTriggered':
          await _handleNativeIgnoreTracking(call.arguments);
          return true;
        default:
          dev.log('Unknown native callback: ${call.method}', name: 'NotificationService');
          return false;
      }
    } catch (e, st) {
      dev.log('Error handling native method ${call.method}: $e', name: 'NotificationService', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> _handleNativeEndTracking(dynamic arguments) async {
    final source = (arguments is Map) ? (arguments['source'] as String? ?? 'unknown') : 'unknown';
    dev.log('Native END_TRACKING received (source=$source)', name: 'NotificationService');
    try {
      await TrackingService().handleNativeEndTrackingFromNotification(source: source);
      await _navigateHomeAfterEndTracking();
    } finally {
      try {
        await _invokeAlarmChannel('acknowledgeNativeEndTracking', {'source': source});
      } catch (e) {
        dev.log('End tracking ack failed: $e', name: 'NotificationService');
      }
    }
  }

  Future<void> _handleNativeIgnoreTracking(dynamic arguments) async {
    final source = (arguments is Map) ? (arguments['source'] as String? ?? 'unknown') : 'unknown';
    dev.log('Native IGNORE_TRACKING received (source=$source)', name: 'NotificationService');
    try {
      await TrackingService.handleNativeIgnoreTrackingFromNotification(source: source);
    } finally {
      try {
        await _invokeAlarmChannel('acknowledgeNativeIgnoreTracking', {'source': source});
      } catch (e) {
        dev.log('Ignore tracking ack failed: $e', name: 'NotificationService');
      }
    }
  }

  Future<void> _navigateHomeAfterEndTracking() async {
    final nav = NavigationService.navigatorKey.currentState;
    if (nav == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_home_after_stop', true);
      } catch (_) {}
      return;
    }
    if (!nav.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateHomeAfterEndTracking());
      return;
    }
    final currentRoute = ModalRoute.of(nav.context)?.settings.name;
    if (currentRoute != null && currentRoute != '/mapTracking') {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navState = NavigationService.navigatorKey.currentState;
      if (navState == null || !navState.mounted) {
        return;
      }
      final routeName = ModalRoute.of(navState.context)?.settings.name;
      if (routeName != null && routeName != '/mapTracking') {
        return;
      }
      navState.pushNamedAndRemoveUntil('/', (route) => false);
    });
  }

  @visibleForTesting
  Future<void> debugHandleNativeCallback(String method, dynamic arguments) async {
    await _handleNativeMethodCall(MethodCall(method, arguments));
  }

  Future<void> cancelJourneyProgress() async {
    if (isTestMode) return;
    // Cancel both the flutter_local_notifications version and the native version
    try {
      await _notificationsPlugin.cancel(_progressNotificationId);
    } catch (e) {
      dev.log('Flutter plugin cancel failed: $e', name: 'NotificationService');
    }
    // Also cancel via native method channel to ensure the native notification is cleared
    try {
      await _alarmMethodChannel.invokeMethod('cancelProgressNotification');
    } catch (e) {
      dev.log('Native cancel failed: $e', name: 'NotificationService');
    }
    _lastProgressPayload = null;
    await _clearPersistedProgressPayload();
  }

  Future<void> restoreJourneyProgressIfNeeded() async {
    final suppressed = TrackingService.suppressProgressNotifications || await TrackingService.isProgressSuppressed();
    if (suppressed) {
      return;
    }
    Map<String, dynamic>? payload = _lastProgressPayload;
    if (payload == null) {
      payload = await _loadPersistedProgressPayload();
      if (payload != null) {
        _lastProgressPayload = payload;
      }
    }
    if (payload == null) {
      return;
    }
    final title = payload['title'] as String?;
    final subtitle = payload['subtitle'] as String?;
    final progress = payload['progress'] as num?;
    if (title == null || subtitle == null || progress == null) {
      return;
    }
    await showJourneyProgress(
      title: title,
      subtitle: subtitle,
      progress0to1: progress.toDouble(),
    );
  }

  Future<void> persistProgressSnapshot({
    required String title,
    required String subtitle,
    required double progress,
    DateTime? timestamp,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'progress': progress,
      'ts': (timestamp ?? DateTime.now()).toIso8601String(),
    };
    _lastProgressPayload = payload;
    if (!isTestMode) {
      await _persistProgressPayload(payload);
    }
  }

  Future<bool> ensureProgressNotificationPresent() async {
    if (isTestMode) return true;
    final suppressed = TrackingService.suppressProgressNotifications || await TrackingService.isProgressSuppressed();
    if (suppressed) {
      return true;
    }
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final active = await androidImpl?.getActiveNotifications();
      final exists = active?.any((n) => n.id == _progressNotificationId) ?? false;
      if (!exists && _lastProgressPayload != null) {
        final payload = _lastProgressPayload!;
        final title = payload['title'] as String? ?? 'GeoWake journey';
        final subtitle = payload['subtitle'] as String? ?? '';
        final progress = (payload['progress'] as num?)?.toDouble() ?? 0.0;
        await showJourneyProgress(title: title, subtitle: subtitle, progress0to1: progress);
        return false;
      }
      return exists;
    } catch (e) {
      dev.log('ensureProgressNotificationPresent failed: $e', name: 'NotificationService');
      return false;
    }
  }

  Future<void> scheduleProgressWakeFallback({Duration interval = const Duration(seconds: 45)}) async {
    if (isTestMode) return;
    try {
      // Use a shorter interval (45 seconds) to ensure notification persistence
      // This ensures the notification will be restored quickly even if the app is swiped away
      await _alarmMethodChannel.invokeMethod('scheduleProgressWake', {
        'intervalMs': interval.inMilliseconds,
      });
      dev.log('Scheduled progress wake fallback with interval: ${interval.inSeconds}s', name: 'NotificationService');
    } catch (e) {
      dev.log('Failed to schedule progress wake: $e', name: 'NotificationService');
    }
  }

  Future<void> cancelProgressWakeFallback() async {
    if (isTestMode) return;
    try {
      await _alarmMethodChannel.invokeMethod('cancelProgressWake');
    } catch (e) {
      dev.log('Failed to cancel progress wake: $e', name: 'NotificationService');
    }
  }

  Future<void> maybePromptBatteryOptimization() async {
    if (isTestMode) return;
    try {
      // Check if we should prompt for battery optimization
      final shouldPrompt = await _alarmMethodChannel.invokeMethod<bool>('shouldPromptBatteryOptimization') ?? false;
      if (!shouldPrompt) {
        // Battery optimization is already disabled, nothing to do
        dev.log('Battery optimization already disabled', name: 'NotificationService');
        return;
      }
      
      // Prompt the user every time tracking starts to ensure they know about the requirement
      // This is critical for Android 15 where background restrictions are stricter
      final prefs = await SharedPreferences.getInstance();
      final lastPromptTime = prefs.getInt('${_batteryPromptKey}_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final daysSinceLastPrompt = (now - lastPromptTime) / (1000 * 60 * 60 * 24);
      
      // Prompt if never prompted, or if it's been more than 7 days since last prompt
      if (lastPromptTime == 0 || daysSinceLastPrompt > 7) {
        dev.log('Prompting for battery optimization (days since last prompt: $daysSinceLastPrompt)', name: 'NotificationService');
        final didPrompt = await _alarmMethodChannel.invokeMethod<bool>('requestBatteryOptimizationPrompt') ?? false;
        if (didPrompt) {
          await prefs.setInt('${_batteryPromptKey}_timestamp', now);
        }
      } else {
        dev.log('Skipping battery optimization prompt (last prompted ${daysSinceLastPrompt.toStringAsFixed(1)} days ago)', name: 'NotificationService');
      }
    } catch (e) {
      dev.log('Battery optimization prompt failed: $e', name: 'NotificationService');
    }
  }

  Future<void> _persistProgressPayload(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_progressPrefsKey, jsonEncode(payload));
    } catch (e) {
      dev.log('Persist progress payload failed: $e', name: 'NotificationService');
    }
  }

  Future<Map<String, dynamic>?> _loadPersistedProgressPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_progressPrefsKey);
      if (raw == null) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return decoded is Map ? decoded.map((key, value) => MapEntry(key.toString(), value)) : null;
    } catch (e) {
      dev.log('Load progress payload failed: $e', name: 'NotificationService');
      return null;
    }
  }

  Future<void> _clearPersistedProgressPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_progressPrefsKey);
    } catch (e) {
      dev.log('Clear progress payload failed: $e', name: 'NotificationService');
    }
  }

  // When app comes to foreground via full-screen intent, ensure the alarm screen shows
  Future<void> showPendingAlarmScreenIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingHome = prefs.getBool('pending_home_after_stop') ?? false;
      if (pendingHome) {
        await prefs.remove('pending_home_after_stop');
        await _navigateHomeAfterEndTracking();
      }
      final launchTracking = prefs.getBool('pending_tracking_launch') ?? false;
      if (launchTracking) {
        await prefs.remove('pending_tracking_launch');
        _openTrackingScreen();
      }
      final has = prefs.getBool('pending_alarm_flag') ?? false;
      if (!has) return;
      final title = prefs.getString('pending_alarm_title') ?? 'Wake Up!';
      final body = prefs.getString('pending_alarm_body') ?? 'Approaching your target';
      final allow = prefs.getBool('pending_alarm_allow') ?? true;
      await prefs.remove('pending_alarm_flag');
      await prefs.remove('pending_alarm_title');
      await prefs.remove('pending_alarm_body');
      await prefs.remove('pending_alarm_allow');
      final nav = NavigationService.navigatorKey.currentState;
      if (nav != null) {
        nav.push(MaterialPageRoute(
          builder: (_) => AlarmFullscreen(title: title, body: body, allowContinueTracking: allow),
        ));
      }
    } catch (e) {
      dev.log('Failed to present pending alarm screen: $e', name: 'NotificationService');
    }
  }
}

@pragma('vm:entry-point')
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}
  dev.log('BG notification response: actionId=${response.actionId}, payload=${response.payload}', name: 'NotificationService');
  if (response.actionId == 'STOP_ALARM') {
    try { await AlarmPlayer.stop(); } catch (_) {}
    try { FlutterBackgroundService().invoke('stopAlarm'); } catch (_) {}
    return;
  }
  if (response.actionId == 'END_TRACKING') {
    // Delegate to native Android handler for reliability
    dev.log('BG: END_TRACKING action - delegating to native handler', name: 'NotificationService');
    try { 
      const channel = MethodChannel('com.example.geowake2/alarm');
      await channel.invokeMethod('handleEndTracking'); 
    } catch (_) {}
    return;
  }
  if (response.actionId == 'IGNORE_TRACKING') {
    // Delegate to native Android handler for reliability
    dev.log('BG: IGNORE_TRACKING action - delegating to native handler', name: 'NotificationService');
    try { 
      const channel = MethodChannel('com.example.geowake2/alarm');
      await channel.invokeMethod('handleIgnoreTracking'); 
    } catch (_) {}
    return;
  }
  if ((response.actionId == null || response.actionId!.isEmpty) && response.payload == 'open_tracking') {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_tracking_launch', true);
    } catch (_) {}
    return;
  }
}