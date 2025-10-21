import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;
import 'package:geowake2/services/log.dart';

/// Service to ensure tracking continues even if the app is killed.
/// Implements multiple fallback mechanisms:
/// 1. Persistent foreground notification
/// 2. Periodic heartbeat checks
/// 3. Fallback alarm scheduling
/// 
/// This addresses CRITICAL-002: Background Service Kill Without Recovery
class BackgroundServiceRecovery {
  static const MethodChannel _channel = MethodChannel('geowake/background_recovery');
  
  static BackgroundServiceRecovery? _instance;
  static BackgroundServiceRecovery get instance => _instance ??= BackgroundServiceRecovery._();
  BackgroundServiceRecovery._();
  
  Timer? _heartbeatTimer;
  bool _isMonitoring = false;
  
  /// Initialize the background service recovery system
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
      Log.i('BackgroundRecovery', 'Initialized successfully');
    } catch (e) {
      Log.e('BackgroundRecovery', 'Failed to initialize', e);
    }
  }
  
  /// Start monitoring for service death and schedule periodic checks
  Future<void> startMonitoring({
    required String routeId,
    required double destinationLat,
    required double destinationLng,
    required String destinationName,
    required int alarmThresholdSeconds,
  }) async {
    if (_isMonitoring) {
      Log.d('BackgroundRecovery', 'Already monitoring');
      return;
    }
    
    _isMonitoring = true;
    
    try {
      // Schedule a fallback alarm via native AlarmManager
      // This will fire if the app/service is killed
      await _scheduleFallbackAlarm(
        routeId: routeId,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        destinationName: destinationName,
        alarmThresholdSeconds: alarmThresholdSeconds,
      );
      
      // Start heartbeat to detect service death
      _startHeartbeat();
      
      Log.i('BackgroundRecovery', 'Started monitoring for route $routeId');
    } catch (e) {
      Log.e('BackgroundRecovery', 'Failed to start monitoring', e);
      _isMonitoring = false;
    }
  }
  
  /// Stop monitoring and cancel all fallback mechanisms
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _stopHeartbeat();
    
    try {
      await _cancelFallbackAlarm();
      Log.i('BackgroundRecovery', 'Stopped monitoring');
    } catch (e) {
      Log.e('BackgroundRecovery', 'Error stopping monitoring', e);
    }
  }
  
  /// Update the fallback alarm timing (called as we get closer to destination)
  Future<void> updateFallbackAlarm({
    required int alarmThresholdSeconds,
  }) async {
    if (!_isMonitoring) return;
    
    try {
      await _channel.invokeMethod('updateFallbackAlarm', {
        'thresholdSeconds': alarmThresholdSeconds,
      });
      Log.d('BackgroundRecovery', 'Updated fallback alarm: ${alarmThresholdSeconds}s');
    } catch (e) {
      Log.e('BackgroundRecovery', 'Failed to update fallback alarm', e);
    }
  }
  
  /// Schedule a native fallback alarm that survives app death
  Future<void> _scheduleFallbackAlarm({
    required String routeId,
    required double destinationLat,
    required double destinationLng,
    required String destinationName,
    required int alarmThresholdSeconds,
  }) async {
    try {
      final triggerTime = DateTime.now()
          .add(Duration(seconds: alarmThresholdSeconds))
          .millisecondsSinceEpoch;
      
      await _channel.invokeMethod('scheduleFallbackAlarm', {
        'routeId': routeId,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'destinationName': destinationName,
        'triggerTimeMs': triggerTime,
      });
      
      Log.i('BackgroundRecovery', 'Scheduled fallback alarm for ${DateTime.fromMillisecondsSinceEpoch(triggerTime)}');
    } catch (e) {
      Log.e('BackgroundRecovery', 'Failed to schedule fallback alarm', e);
      rethrow;
    }
  }
  
  /// Cancel the fallback alarm
  Future<void> _cancelFallbackAlarm() async {
    try {
      await _channel.invokeMethod('cancelFallbackAlarm');
      Log.d('BackgroundRecovery', 'Cancelled fallback alarm');
    } catch (e) {
      Log.e('BackgroundRecovery', 'Failed to cancel fallback alarm', e);
    }
  }
  
  /// Start a periodic heartbeat to detect if the service is still running
  void _startHeartbeat() {
    _stopHeartbeat(); // Ensure no duplicate timers
    
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performHeartbeatCheck(),
    );
    
    Log.d('BackgroundRecovery', 'Started heartbeat monitoring');
  }
  
  /// Stop the heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  /// Perform a heartbeat check to ensure service is alive
  Future<void> _performHeartbeatCheck() async {
    try {
      final isAlive = await _channel.invokeMethod<bool>('checkServiceAlive');
      
      if (isAlive == null || !isAlive) {
        Log.w('BackgroundRecovery', 'Service appears dead, attempting recovery');
        await _attemptServiceRecovery();
      } else {
        Log.d('BackgroundRecovery', 'Service heartbeat OK');
      }
    } catch (e) {
      Log.e('BackgroundRecovery', 'Heartbeat check failed', e);
      // Service might be dead if we can't communicate with it
      try {
        await _attemptServiceRecovery();
      } catch (e2) {
        Log.e('BackgroundRecovery', 'Recovery attempt failed', e2);
      }
    }
  }
  
  /// Attempt to restart the background service
  Future<void> _attemptServiceRecovery() async {
    try {
      await _channel.invokeMethod('restartService');
      Log.i('BackgroundRecovery', 'Service restart initiated');
    } catch (e) {
      Log.e('BackgroundRecovery', 'Failed to restart service', e);
    }
  }
  
  /// Check if the device will reliably run background services
  /// Returns a reliability score (0.0 to 1.0)
  Future<double> checkBackgroundReliability() async {
    try {
      final result = await _channel.invokeMethod<Map>('checkReliability');
      
      if (result == null) return 0.5;
      
      double score = 1.0;
      
      // Check battery optimization
      if (result['batteryOptimized'] == true) {
        score -= 0.3;
      }
      
      // Check if device is known to aggressively kill apps
      final manufacturer = result['manufacturer'] as String?;
      if (_isAggressiveManufacturer(manufacturer)) {
        score -= 0.2;
      }
      
      // Check if background restrictions are enabled
      if (result['backgroundRestricted'] == true) {
        score -= 0.3;
      }
      
      return score.clamp(0.0, 1.0);
    } catch (e) {
      Log.e('BackgroundRecovery', 'Failed to check reliability', e);
      return 0.5; // Unknown reliability
    }
  }
  
  /// Check if manufacturer is known to aggressively kill apps
  bool _isAggressiveManufacturer(String? manufacturer) {
    if (manufacturer == null) return false;
    
    final aggressive = ['xiaomi', 'miui', 'oppo', 'vivo', 'huawei', 'samsung', 'oneplus'];
    return aggressive.any((brand) => 
      manufacturer.toLowerCase().contains(brand)
    );
  }
  
  /// Get recommendations for the user to improve reliability
  Future<List<String>> getReliabilityRecommendations() async {
    try {
      final result = await _channel.invokeMethod<Map>('checkReliability');
      if (result == null) return [];
      
      final recommendations = <String>[];
      
      if (result['batteryOptimized'] == true) {
        recommendations.add('Disable battery optimization for GeoWake to prevent the app from being killed in the background.');
      }
      
      if (result['backgroundRestricted'] == true) {
        recommendations.add('Allow GeoWake to run in the background without restrictions in your device settings.');
      }
      
      final manufacturer = result['manufacturer'] as String?;
      if (_isAggressiveManufacturer(manufacturer)) {
        recommendations.add('Your device may aggressively kill background apps. Please check manufacturer-specific settings to allow GeoWake to run continuously.');
      }
      
      if (result['exactAlarmPermission'] == false) {
        recommendations.add('Grant exact alarm permission to ensure wake-up alarms fire at the right time.');
      }
      
      return recommendations;
    } catch (e) {
      Log.e('BackgroundRecovery', 'Failed to get recommendations', e);
      return [];
    }
  }
}
