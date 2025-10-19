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

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool isDarkMode = false;
  Timer? _hbTimer;
  int _hbCount = 0;
  StreamSubscription? _bootstrapSub;

  @override
  void initState() {
    super.initState();
    // Start listening for app lifecycle events (pause, resume, etc.).
    WidgetsBinding.instance.addObserver(this);
    
    // =======================================================================
    // FIX: Call the permission check function here.
    // =======================================================================
    _checkNotificationPermission();
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
      dev.log("App paused, flushing Hive box to disk.", name: "main");
      // `flush()` is a direct command to write all in-memory changes to disk.
      // This prevents the OS from killing the app before data is saved.
      if (Hive.isBoxOpen(RecentLocationsService.boxName)) {
        Hive.box(RecentLocationsService.boxName).flush();
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

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Periodic heartbeat (debug only) – once every 10s for first minute
    // (Uses a simple timer started on first build.)
    _heartbeatInitOnce();
    return MaterialApp(
      title: 'GeoWake',
      navigatorKey: NavigationService.navigatorKey,
      theme: isDarkMode ? AppThemes.darkTheme : AppThemes.lightTheme,
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