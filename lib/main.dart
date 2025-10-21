import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/bootstrap_service.dart';
import 'services/trackingservice.dart';
import 'screens/homescreen.dart';
import 'screens/maptracking.dart';
import 'screens/splash_screen.dart';
import 'themes/appthemes.dart';
import 'screens/otherimpservices/recent_locations_service.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'services/permission_monitor.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/persistence/tracking_session_state.dart';
import 'dart:developer' as dev;
import 'dart:async';
// Screen imports
import 'screens/otherimpservices/preload_map_screen.dart';

// With refactored bootstrap this remains splash; navigation happens after phase ready.
String _initialRoute = '/splash';
Map<String, dynamic>? _initialMapTrackingArgs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('GW_ARES_MAIN_ENTER_REFAC');
  runApp(const MyApp());
  // Defer heavy work until after first frame for faster perceived launch
  WidgetsBinding.instance.addPostFrameCallback((_) {
    BootstrapService.I.start();
  });
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  MyAppState createState() => MyAppState();
}

// Theme mode enum for system/light/dark selection
enum AppThemeMode { system, light, dark }

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  AppThemeMode _themeMode = AppThemeMode.system;
  Timer? _hbTimer;
  int _hbCount = 0;
  StreamSubscription? _bootstrapSub;
  final PermissionMonitor _permissionMonitor = PermissionMonitor();

  @override
  void initState() {
    super.initState();
    // Start listening for app lifecycle events (pause, resume, etc.).
    WidgetsBinding.instance.addObserver(this);
    
    // Load theme preference from storage
    _loadThemePreference();
    
    // =======================================================================
    // FIX: Call the permission check function here.
    // =======================================================================
    _checkNotificationPermission();
    
    // Check and request exact alarm permission (Android 12+)
    PermissionMonitor.checkAndRequestExactAlarmPermission();
    
    // Start monitoring permissions for revocation
    _permissionMonitor.startMonitoring();
  // If an alarm was fired while app was backgrounded, present it now.
    NotificationService().showPendingAlarmScreenIfAny();
  // Attempt to restore the ongoing journey notification if tracking is active and not suppressed
  NotificationService().restoreJourneyProgressIfNeeded();

    // Bridge background 'fireAlarm' events to foreground UI/audio
    try {
      final service = FlutterBackgroundService();
      service.on('fireAlarm').listen((event) async {
        if (event == null) return;
        final title = (event['title'] as String?) ?? 'Wake Up!';
        final body = (event['body'] as String?) ?? 'Approaching your target';
        final allow = (event['allowContinueTracking'] as bool?) ?? true;
        // Show full-screen alarm notification + native activity and play sound
        await NotificationService().showWakeUpAlarm(
          title: title,
          body: body,
          allowContinueTracking: allow,
        );
      });
      
      // Listen for tracking stopped from notification button
      service.on('trackingStopped').listen((event) async {
        dev.log('Received trackingStopped event from background isolate', name: 'main');
        try {
          // Stop tracking in foreground isolate
          await TrackingService().stopTracking();
          
          // Navigate away from map tracking screen if currently there
          final nav = NavigationService.navigatorKey.currentState;
          if (nav != null && nav.mounted) {
            final currentRoute = ModalRoute.of(nav.context)?.settings.name;
            if (currentRoute == '/mapTracking') {
              dev.log('Navigating away from map tracking screen', name: 'main');
              nav.pushNamedAndRemoveUntil('/', (r) => false);
            }
          }
        } catch (e) {
          dev.log('Error handling trackingStopped event: $e', name: 'main');
        }
      });
    } catch (e) {
      dev.log('Failed to subscribe to fireAlarm: $e', name: 'main');
    }

    // Subscribe to bootstrap phases
    _bootstrapSub = BootstrapService.I.states.listen((s) {
      if (s.phase == BootstrapPhase.ready) {
        // Navigate away from splash if still there
        final nav = NavigationService.navigatorKey.currentState;
        if (nav != null) {
          final route = s.targetRoute ?? '/';
            if (route == '/mapTracking') {
              _initialMapTrackingArgs = s.mapTrackingArgs;
            }
          nav.pushNamedAndRemoveUntil(route == '/mapTracking' ? '/mapTracking' : '/', (r) => false, arguments: _initialMapTrackingArgs);
        }
      }
    });
  }

  @override
  void dispose() {
    // Stop listening to prevent memory leaks.
    WidgetsBinding.instance.removeObserver(this);
    // Stop permission monitoring
    _permissionMonitor.stopMonitoring();
    // As a final cleanup when the app is truly closing, close Hive.
    try { Hive.close(); } catch (_) {}
    try { _bootstrapSub?.cancel(); } catch (_) {}
    super.dispose();
  }

  // This is the definitive fix for saving data before the app closes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // This is called when the user backgrounds the app (e.g., presses home).
    if (state == AppLifecycleState.paused) {
      dev.log("App paused, flushing all Hive boxes to disk.", name: "main");
      // CRITICAL-008 FIX: Flush all open boxes to prevent data corruption
      // `flush()` is a direct command to write all in-memory changes to disk.
      // This prevents the OS from killing the app before data is saved.
      try {
        // Flush all open boxes
        for (var box in Hive.box.values) {
          try {
            if (box.isOpen) {
              box.flush();
            }
          } catch (e) {
            dev.log('Error flushing box: $e', name: 'main');
          }
        }
      } catch (e) {
        dev.log('Error flushing Hive boxes: $e', name: 'main');
      }
      
      // If no active tracking session, schedule process close to avoid a dormant process lingering.
      Future.delayed(const Duration(seconds: 1), () async {
        if (!TrackingService.trackingActive) {
          dev.log('No active tracking; process may be reclaimed by OS (no explicit foreground service).', name: 'main');
          // NOTE: We deliberately do not call SystemNavigator.pop() because doing so
          // can interfere with background service detach semantics on some OEM builds.
          // Leaving the app paused lets the foreground Activity finish naturally while
          // the background service (if started) keeps running; if no tracking was active
          // the service is not started and the process becomes a candidate for reclaim.
        }
      });
    }
    if (state == AppLifecycleState.detached) {
      // App is about to be terminated - close all boxes properly
      dev.log("App detached, closing all Hive boxes.", name: "main");
      try {
        Hive.close();
      } catch (e) {
        dev.log('Error closing Hive on app detached: $e', name: 'main');
      }
    }
    if (state == AppLifecycleState.resumed) {
      // On resume, auto-present any pending full-screen alarm.
      NotificationService().showPendingAlarmScreenIfAny();
      // Also restore progress notification if needed
      NotificationService().restoreJourneyProgressIfNeeded();
    }
  }

  /// Check and request notification permission on Android 13+ or iOS.
  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Load theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString('themeMode') ?? 'system';
      if (mounted) {
        setState(() {
          _themeMode = AppThemeMode.values.firstWhere(
            (mode) => mode.name == themeModeString,
            orElse: () => AppThemeMode.system,
          );
        });
      }
    } catch (e) {
      dev.log('Failed to load theme preference: $e', name: 'main');
    }
  }

  /// Save theme preference to SharedPreferences
  Future<void> _saveThemePreference(AppThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', mode.name);
    } catch (e) {
      dev.log('Failed to save theme preference: $e', name: 'main');
    }
  }

  /// Set theme mode and persist it
  void setThemeMode(AppThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    _saveThemePreference(mode);
  }

  /// Toggle between light and dark mode (for compatibility with existing UI)
  void toggleTheme() {
    final newMode = _themeMode == AppThemeMode.dark 
        ? AppThemeMode.light 
        : AppThemeMode.dark;
    setThemeMode(newMode);
  }

  /// Get current theme mode for compatibility
  bool get isDarkMode {
    if (_themeMode == AppThemeMode.system) {
      // Detect system brightness
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == AppThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    // Periodic heartbeat (debug only) – once every 10s for first minute
    // (Uses a simple timer started on first build.)
    _heartbeatInitOnce();
    
    // Determine effective theme based on mode and system brightness
    final ThemeData effectiveTheme;
    if (_themeMode == AppThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      effectiveTheme = brightness == Brightness.dark 
          ? AppThemes.darkTheme 
          : AppThemes.lightTheme;
    } else {
      effectiveTheme = _themeMode == AppThemeMode.dark
          ? AppThemes.darkTheme
          : AppThemes.lightTheme;
    }
    
    return MaterialApp(
      title: 'GeoWake',
      navigatorKey: NavigationService.navigatorKey,
      theme: effectiveTheme,
      initialRoute: _initialRoute,
      onGenerateRoute: (settings) {
        if (settings.name == '/splash') {
          return MaterialPageRoute(
            builder: (_) => const SplashScreen(),
            settings: settings,
          );
        }
        if (settings.name == '/mapTracking') {
          final passArgs = settings.arguments ?? _initialMapTrackingArgs;
          return MaterialPageRoute(
            builder: (_) => MapTrackingScreen(),
            settings: RouteSettings(name: settings.name, arguments: passArgs),
          );
        }
        if (settings.name == '/preloadMap') {
          final args = (settings.arguments is Map<String, dynamic>)
              ? settings.arguments as Map<String, dynamic>
              : (_initialMapTrackingArgs ?? <String, dynamic>{});
          return MaterialPageRoute(
            builder: (_) => PreloadMapScreen(arguments: args),
            settings: RouteSettings(name: settings.name, arguments: args),
          );
        }
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
        return null;
      },
    );
  }

  void _heartbeatInitOnce() {
    if (_hbTimer != null) return;
    _hbTimer = Timer.periodic(const Duration(seconds: 10), (t) async {
      _hbCount++;
      if (_hbCount > 6) { t.cancel(); return; }
      try {
        final prefs = await SharedPreferences.getInstance();
        final fast = prefs.getBool(TrackingSessionStateFile.trackingActiveFlagKey);
        print('GW_ARES_MAIN_HB tick=$_hbCount fastFlag=$fast trackingActive=${TrackingService.trackingActive} autoResumed=${TrackingService.autoResumed} route=$_initialRoute');
      } catch (e) { print('GW_ARES_MAIN_HB_FAIL tick=$_hbCount err=$e'); }
    });
  }
}