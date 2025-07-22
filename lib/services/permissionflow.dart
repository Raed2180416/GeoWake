import 'dart:developer' as dev;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:app_settings/app_settings.dart';

/// Handles the multi-step permission flow for location and notification permissions.
class PermissionFlow {
  final BuildContext context;

  PermissionFlow(this.context);

  /// The main entry point. Returns true if all needed permissions are granted.
  Future<bool> initiatePermissionFlow() async {
    try {
      // Request foreground location permission.
      PermissionStatus locationWhenInUseStatus = await Permission.locationWhenInUse.request();
      if (!locationWhenInUseStatus.isGranted) {
        dev.log("Foreground location not granted", name: "PermissionFlow");
        return false;
      }

      // Request background location permission.
      PermissionStatus backgroundStatus = await Permission.locationAlways.request();
      if (!backgroundStatus.isGranted) {
        dev.log("Background location not granted", name: "PermissionFlow");
        // Depending on your app's design, you might allow proceeding with limited functionality.
      }

      // Request POST_NOTIFICATIONS for Android 13+
      if (Platform.isAndroid) {
        PermissionStatus notifStatus = await Permission.notification.request();
        if (!notifStatus.isGranted) {
          dev.log("Notification permission not granted", name: "PermissionFlow");
          // Optionally, inform the user that notifications are required.
          return false;
        }
      }

      // For Android 14+ require FOREGROUND_SERVICE_LOCATION permission
      if (Platform.isAndroid) {
        PermissionStatus fgServiceLocationStatus = await checkForegroundServiceLocation();
        if (!fgServiceLocationStatus.isGranted) {
          // Custom helper method to request FOREGROUND_SERVICE_LOCATION permission.
          fgServiceLocationStatus = await requestForegroundServiceLocation();
          if (!fgServiceLocationStatus.isGranted) {
            dev.log("Foreground service location permission not granted", name: "PermissionFlow");
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      dev.log("Error in permission flow: $e", name: "PermissionFlow");
      _showErrorDialog("Error", "Could not set up permissions, please try again.");
      return false;
    }
  }

  /// Example helper methods for handling FOREGROUND_SERVICE_LOCATION.
  /// Since permission_handler may not support it directly, you might need to implement your own.
  Future<PermissionStatus> checkForegroundServiceLocation() async {
    // For illustration; in your actual implementation, check if the OS version >= Android 14.
    return PermissionStatus.granted;
  }

  Future<PermissionStatus> requestForegroundServiceLocation() async {
    // If using permission_handler 10+, this might be available.
    // Otherwise, show a dialog guiding the user to the settings.
    bool proceed = await _showUpgradeToAlwaysDialog();
    if (proceed) {
      await redirectToLocationPermissionSettings();
      // After returning, re-check permission.
      return await Permission.locationAlways.status;
    }
    return PermissionStatus.denied;
  }

  /// Opens system location settings.
  Future<void> redirectToLocationPermissionSettings() async {
    try {
      if (Platform.isAndroid) {
        final packageInfo = await PackageInfo.fromPlatform();
        final packageName = packageInfo.packageName;
        final intent = AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:$packageName',
        );
        await intent.launch();
      } else if (Platform.isIOS) {
        await AppSettings.openAppSettings(type: AppSettingsType.location);
      }
    } catch (e) {
      dev.log("Error opening location settings: $e", name: "PermissionFlow");
      _showGenericOpenSettingsError();
    }
  }

  void _showGenericOpenSettingsError() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Unable to open settings'),
          content: const Text(
            'Please manually go to Settings and update location permissions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog prompting user to upgrade to always-on location.
  Future<bool> _showUpgradeToAlwaysDialog() async {
    return (await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Upgrade to Always-On?"),
          content: const Text(
            "GeoWake works best with 'Always' location permission. "
            "Do you want to open settings to enable it?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Yes"),
            ),
          ],
        );
      },
    )) ?? false;
  }

  /// Displays an error dialog.
  Future<void> _showErrorDialog(String title, String message) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
}

/// Helper extension to simulate checking/requesting FOREGROUND_SERVICE_LOCATION.
/// You may need to implement this with platform channels if permission_handler doesn't support it yet.
extension PermissionHandler on PermissionFlow {
  Future<PermissionStatus> checkForegroundServiceLocation() async {
    // For illustration, always return granted.
    // Replace with actual platform-specific implementation if available.
    return PermissionStatus.granted;
  }

  Future<PermissionStatus> requestForegroundServiceLocation() async {
    // Guide the user to settings.
    bool proceed = await _showUpgradeToAlwaysDialog();
    if (proceed) {
      await redirectToLocationPermissionSettings();
      return await Permission.locationAlways.status;
    }
    return PermissionStatus.denied;
  }
}
