// Annotated copy of lib/main.dart
// Purpose: Document application entry point, initialization sequence, lifecycle management, and routing setup.

import 'package:flutter/material.dart'; // Core Flutter widgets and UI
import 'package:permission_handler/permission_handler.dart'; // Runtime permission requests
import 'package:hive_flutter/hive_flutter.dart'; // Local NoSQL database for offline storage
import 'services/trackingservice.dart'; // Background location tracking service
import 'services/api_client.dart'; // Secure API client for server communication
import 'screens/homescreen.dart'; // Main app screen after splash
import 'screens/maptracking.dart'; // Active tracking/navigation screen
import 'screens/otherimpservices/preload_map_screen.dart'; // Pre-cache map tiles
import 'screens/splash_screen.dart'; // Initial loading screen
import 'themes/appthemes.dart'; // Light and dark theme definitions
import 'screens/otherimpservices/recent_locations_service.dart'; // Recent location history
import 'services/notification_service.dart'; // Push notifications and alarm UI
import 'services/navigation_service.dart'; // Global navigation key for routing
import 'dart:developer' as dev; // Structured logging
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode; // Build mode flags
import 'debug/dev_server.dart'; // Development HTTP server for remote testing
import 'package:flutter_background_service/flutter_background_service.dart'; // Background isolate management

Future<void> main() async { // Application entry point
  // Ensure Flutter framework is fully initialized before using plugins
  // This is critical for any async work done before runApp()
  WidgetsFlutterBinding.ensureInitialized(); // Initialize Flutter bindings synchronously
  
  // Initialize Hive database engine
  // Hive is a lightweight NoSQL database for storing recent locations and user preferences
  try {
    await Hive.initFlutter(); // Sets up Hive with Flutter's default storage directory
    dev.log("Hive engine initialized successfully.", name: "main"); // Log successful init
  } catch (e) { // Catch any initialization errors
    dev.log("FATAL: Hive initialization failed: $e", name: "main"); // Critical error - app may not function properly
  }
  
  // Initialize essential services before launching the UI
  await _initializeServices(); // Async initialization of API client, notifications, tracking
  
  runApp(const MyApp()); // Launch the Flutter widget tree
} // End main

// Separate initialization function for cleaner organization and testability
Future<void> _initializeServices() async { // Initialize all critical services
  // Initialize API client FIRST - this ensures all Google Maps API calls are proxied through secure server
  // This prevents API key exposure in the client app
  try {
    await ApiClient.instance.initialize(); // Singleton init with server connection validation
    dev.log("API Client initialized successfully.", name: "main"); // Confirms secure server connection
  } catch (e) { // If server unreachable, API calls may fail
    dev.log("API Client initialization failed: $e", name: "main"); // Non-fatal but limits functionality
  }

  // Initialize notification service for alarms, progress updates, and system notifications
  try {
    await NotificationService().initialize(); // Sets up notification channels and permissions
  } catch (e) { // Notification failures should not crash the app
    dev.log("Notification Service initialization failed: $e", name: "main"); // User may not receive alarms
  }

  // Initialize background tracking service for location monitoring
  try {
    await TrackingService().initializeService(); // Configures background isolate and foreground service
  } catch (e) { // Tracking service init failure is critical but shouldn't crash
    dev.log("Tracking Service initialization failed: $e", name: "main"); // Core functionality impaired
  }

  // Start development HTTP server in debug/profile builds for remote testing
  // This allows triggering demo journeys and alarms from external tools (curl, Postman, etc.)
  if (kDebugMode || kProfileMode) { // Only in non-release builds
    // ignore: unawaited_futures - Fire and forget, server runs independently
    DevServer.start(); // Starts HTTP server on port 8765 by default
  }
} // End _initializeServices

class MyApp extends StatefulWidget { // Root application widget with state for theme toggling
  const MyApp({super.key}); // Constructor with optional key

  @override
  MyAppState createState() => MyAppState(); // Create mutable state
} // End MyApp

class MyAppState extends State<MyApp> with WidgetsBindingObserver { // State class with lifecycle observer
  bool isDarkMode = false; // Theme toggle state (light by default)

  @override
  void initState() { // Called once when widget is inserted into the tree
    super.initState(); // Call parent implementation
    // Register as lifecycle observer to handle app backgrounding/foregrounding
    WidgetsBinding.instance.addObserver(this); // Enables didChangeAppLifecycleState callbacks
    
    // Check and request notification permission immediately on app start
    // Required for Android 13+ and iOS to show alarm notifications
    _checkNotificationPermission(); // Async call, doesn't block UI
    
    // If an alarm was triggered while app was in background, present it now
    NotificationService().showPendingAlarmScreenIfAny(); // Check for pending full-screen alarm
    
    // Bridge background service 'fireAlarm' events to foreground UI
    // This ensures alarms triggered in background isolate are shown in foreground
    try {
      final service = FlutterBackgroundService(); // Get service instance
      service.on('fireAlarm').listen((event) async { // Subscribe to fireAlarm event stream
        if (event == null) return; // Ignore null events
        // Extract alarm parameters from event data
        final title = (event['title'] as String?) ?? 'Wake Up!'; // Alarm title
        final body = (event['body'] as String?) ?? 'Approaching your target'; // Alarm message
        final allow = (event['allowContinueTracking'] as bool?) ?? true; // Whether to allow tracking continuation
        // Show full-screen alarm notification with native activity and play alarm sound
        await NotificationService().showWakeUpAlarm(
          title: title, // Alarm title
          body: body, // Alarm body
          allowContinueTracking: allow, // Show "Continue" button if true
        ); // Triggers native Android/iOS full-screen alarm activity
      }); // End listen
    } catch (e) { // Event subscription may fail in test environments
      dev.log('Failed to subscribe to fireAlarm: $e', name: 'main'); // Non-fatal error
    }
  } // End initState

  @override
  void dispose() { // Called when widget is removed from the tree
    // Unregister lifecycle observer to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this); // Stop receiving lifecycle callbacks
    // Close Hive database when app is truly closing
    Hive.close(); // Flushes all data to disk and releases resources
    super.dispose(); // Call parent implementation
  } // End dispose

  // Critical fix for data persistence when app is backgrounded
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { // Called when app lifecycle changes
    super.didChangeAppLifecycleState(state); // Call parent implementation
    // Handle app paused event (user pressed home button or switched apps)
    if (state == AppLifecycleState.paused) { // App going to background
      dev.log("App paused, flushing Hive box to disk.", name: "main"); // Log for debugging
      // Force Hive to write all in-memory changes to disk
      // This prevents data loss if OS kills the app while backgrounded
      if (Hive.isBoxOpen(RecentLocationsService.boxName)) { // Check if box is open
        Hive.box(RecentLocationsService.boxName).flush(); // Synchronously write to disk
      } // End if box open
    } // End if paused
    if (state == AppLifecycleState.resumed) { // App returning to foreground
      // Auto-present any pending full-screen alarm when user returns to app
      NotificationService().showPendingAlarmScreenIfAny(); // Check and show pending alarm
    } // End if resumed
  } // End didChangeAppLifecycleState

  /// Check and request notification permission on Android 13+ or iOS
  /// Required for showing alarm notifications and progress updates
  Future<void> _checkNotificationPermission() async { // Async permission check
    final status = await Permission.notification.status; // Get current permission status
    if (status.isDenied) { // If permission not yet granted
      await Permission.notification.request(); // Request permission from user
    } // End if denied
  } // End _checkNotificationPermission

  void toggleTheme() { // Public method to toggle between light and dark themes
    setState(() { // Trigger UI rebuild
      isDarkMode = !isDarkMode; // Flip theme state
    }); // End setState
  } // End toggleTheme

  @override
  Widget build(BuildContext context) { // Build UI tree
    return MaterialApp( // Root application widget
      title: 'GeoWake', // App title (shown in task switcher)
      navigatorKey: NavigationService.navigatorKey, // Global navigation key for programmatic routing
      theme: isDarkMode ? AppThemes.darkTheme : AppThemes.lightTheme, // Apply current theme
      initialRoute: '/splash', // Start at splash screen
      onGenerateRoute: (settings) { // Custom route generator for named routes
        // Handle splash screen route
        if (settings.name == '/splash') { // Splash screen route
          return MaterialPageRoute( // Standard page transition
            builder: (_) => const SplashScreen(), // Build splash screen widget
            settings: settings, // Pass route settings
          ); // End MaterialPageRoute
        } // End if splash
        
        // Handle preload map route (pre-caches map tiles for offline use)
        if (settings.name == '/preloadMap') { // Preload map route
          final args = settings.arguments as Map<String, dynamic>; // Extract route arguments
          return MaterialPageRoute( // Standard page transition
            builder: (_) => PreloadMapScreen(arguments: args), // Build preload screen with args
            settings: settings, // Pass route settings
          ); // End MaterialPageRoute
        } // End if preloadMap
        
        // Handle map tracking route (active navigation screen)
        if (settings.name == '/mapTracking') { // Map tracking route
          return MaterialPageRoute( // Standard page transition
            builder: (_) => MapTrackingScreen(), // Build tracking screen
            settings: settings, // Pass route settings
          ); // End MaterialPageRoute
        } // End if mapTracking
        
        // Handle home screen route (default landing after splash)
        if (settings.name == '/') { // Home route
          return MaterialPageRoute(builder: (_) => const HomeScreen()); // Build home screen
        } // End if home
        
        return null; // Return null for unhandled routes (triggers 404)
      }, // End onGenerateRoute
    ); // End MaterialApp
  } // End build
} // End MyAppState

/* File summary: main.dart is the entry point for the GeoWake application. It orchestrates the initialization
   sequence: Flutter bindings → Hive database → API client → Notifications → Tracking service. The MyApp widget
   manages app-wide theme state and lifecycle events, crucially flushing Hive to disk when the app is backgrounded
   to prevent data loss. It also bridges background service alarm events to the foreground UI, ensuring alarms
   triggered in the background isolate are presented to the user. The development server is started in debug/profile
   modes to enable remote testing of alarm and tracking features. The route system uses named routes with custom
   generator for flexibility in passing arguments to screens. */
