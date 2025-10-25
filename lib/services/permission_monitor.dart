import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:synchronized/synchronized.dart';
import 'dart:developer' as dev;
import 'navigation_service.dart';
import 'trackingservice.dart';
import '../config/tweakables.dart';

/// Monitors runtime permissions and handles revocation gracefully.
/// Provides battery optimization guidance for reliable background operation.
class PermissionMonitor {
  Timer? _monitorTimer;
  bool _hasShownLocationWarning = false;
  bool _hasShownNotificationWarning = false;
  bool _isMonitoring = false;
  final _lock = Lock();
  
  /// Start monitoring critical permissions at regular intervals.
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    dev.log('Starting permission monitoring', name: 'PermissionMonitor');
    
    _monitorTimer = Timer.periodic(
      Duration(seconds: GeoWakeTweakables.permissionCheckIntervalSeconds),
      (_) => _checkCriticalPermissions(),
    );
    
    // Also check immediately
    _checkCriticalPermissions();
  }
  
  /// Stop monitoring permissions.
  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    
    dev.log('Stopping permission monitoring', name: 'PermissionMonitor');
    
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }
  
  /// Check all critical permissions and handle revocations.
  Future<void> _checkCriticalPermissions() async {
    await _lock.synchronized(() async {
      try {
        // Check location permission
        final locationStatus = await Permission.location.status;
        if (!locationStatus.isGranted) {
          await _handleLocationRevoked();
        } else {
          _hasShownLocationWarning = false;
        }
        
        // Check notification permission
        final notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
          await _handleNotificationRevoked();
        } else {
          _hasShownNotificationWarning = false;
        }
      } catch (e) {
        dev.log('Error checking permissions: $e', name: 'PermissionMonitor');
      }
    });
  }
  
  /// Handle location permission revocation.
  Future<void> _handleLocationRevoked() async {
    dev.log('Location permission revoked', name: 'PermissionMonitor');
    
    // Critical: Stop tracking immediately if active
    if (TrackingService.trackingActive) {
      dev.log('Stopping tracking due to location permission revocation', 
              name: 'PermissionMonitor');
      try {
        await TrackingService().stopTracking();
      } catch (e) {
        dev.log('Error stopping tracking: $e', name: 'PermissionMonitor');
      }
    }
    
    // Show warning dialog (only once per revocation)
    if (!_hasShownLocationWarning) {
      _hasShownLocationWarning = true;
      _showPermissionRevokedDialog(
        'Location Permission Required',
        'Location access was disabled. GeoWake needs location permission to track your journey and wake you at the right stop.\n\nPlease enable location access in Settings.',
      );
    }
  }
  
  /// Handle notification permission revocation.
  Future<void> _handleNotificationRevoked() async {
    dev.log('Notification permission revoked', name: 'PermissionMonitor');
    
    // Show warning dialog (only once per revocation)
    if (!_hasShownNotificationWarning) {
      _hasShownNotificationWarning = true;
      _showPermissionRevokedDialog(
        'Notification Permission Required',
        'Notification access was disabled. GeoWake needs notifications to show alarm alerts when you approach your destination.\n\nPlease enable notifications in Settings.',
      );
    }
  }
  
  /// Show dialog to user about permission revocation.
  void _showPermissionRevokedDialog(String title, String message) {
    final nav = NavigationService.navigatorKey.currentContext;
    if (nav == null) return;
    
    showDialog(
      context: nav,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('Later'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              AppSettings.openAppSettings();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  
  /// Check if battery optimization is enabled for the app.
  /// Returns true if optimization is enabled (which may kill the app).
  static Future<bool> isBatteryOptimizationEnabled() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return !status.isGranted;
    } catch (e) {
      dev.log('Error checking battery optimization: $e', name: 'PermissionMonitor');
      return false;
    }
  }
  
  /// Request battery optimization whitelist with user guidance.
  static Future<void> requestBatteryOptimizationWhitelist(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    final isOptimized = await isBatteryOptimizationEnabled();
    if (!isOptimized) {
      dev.log('Battery optimization already disabled', name: 'PermissionMonitor');
      return; // Already whitelisted
    }
    
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reliable Background Tracking'),
        content: const Text(
          'For reliable wake-up alarms, GeoWake needs to be excluded from battery optimization.\n\n'
          'This ensures the app can:\n'
          '• Track your location accurately in the background\n'
          '• Wake you at the right stop even when your phone is locked\n'
          '• Continue running when other apps are active\n\n'
          'Battery usage will still be optimized using smart tracking algorithms.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            child: const Text('Skip'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Enable Reliable Tracking'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    
    if (shouldRequest == true) {
      dev.log('Requesting battery optimization exemption', name: 'PermissionMonitor');
      try {
        final status = await Permission.ignoreBatteryOptimizations.request();
        if (status.isGranted) {
          dev.log('Battery optimization exemption granted', name: 'PermissionMonitor');
        } else {
          dev.log('Battery optimization exemption denied', name: 'PermissionMonitor');
        }
      } catch (e) {
        dev.log('Error requesting battery optimization exemption: $e', 
                name: 'PermissionMonitor');
      }
    }
  }
  
  /// Check and request exact alarm permission (Android 12+).
  static Future<bool> checkAndRequestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 31) {
        // Android 11 and below don't need this permission
        return true;
      }
      
      dev.log('Checking exact alarm permission (Android ${androidInfo.version.sdkInt})', 
              name: 'PermissionMonitor');
      
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isGranted) {
        dev.log('Exact alarm permission already granted', name: 'PermissionMonitor');
        return true;
      }
      
      dev.log('Requesting exact alarm permission', name: 'PermissionMonitor');
      final result = await Permission.scheduleExactAlarm.request();
      
      if (result.isGranted) {
        dev.log('Exact alarm permission granted', name: 'PermissionMonitor');
        return true;
      } else {
        dev.log('Exact alarm permission denied', name: 'PermissionMonitor');
        return false;
      }
    } catch (e) {
      dev.log('Error checking exact alarm permission: $e', name: 'PermissionMonitor');
      return false;
    }
  }
  
  /// Show battery optimization guidance dialog.
  /// Should be called before first tracking session.
  static Future<void> showBatteryOptimizationGuidance(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    final isOptimized = await isBatteryOptimizationEnabled();
    if (!isOptimized) return; // Already whitelisted
    
    await requestBatteryOptimizationWhitelist(context);
  }
}
