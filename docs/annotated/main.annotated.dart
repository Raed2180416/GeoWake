// Annotated copy of lib/main.dart
// Purpose: Application entry point, initialization orchestration, lifecycle management, and theme control.
// This file is the heart of the GeoWake application - it's the first code that runs when the app starts.

import 'package:flutter/material.dart'; // Core Flutter UI framework - provides widgets, state management, and rendering
import 'package:permission_handler/permission_handler.dart'; // Package for requesting runtime permissions (location, notifications, etc.)
import 'package:hive_flutter/hive_flutter.dart'; // Local NoSQL database for Flutter - used for persistent storage
import 'services/trackingservice.dart'; // Background location tracking service - monitors user position and triggers alarms
import 'services/api_client.dart'; // Secure API client for Google Maps requests - proxies through backend server
import 'screens/homescreen.dart'; // Main app screen - route creation and management UI
import 'screens/maptracking.dart'; // Active tracking screen - displays map with route progress
import 'screens/otherimpservices/preload_map_screen.dart'; // Map tiles preloading screen - for offline functionality
import 'screens/splash_screen.dart'; // Initial loading screen - shown during app initialization
import 'themes/appthemes.dart'; // Theme definitions - light/dark mode color schemes and typography
import 'screens/otherimpservices/recent_locations_service.dart'; // Recent locations persistence service
import 'services/notification_service.dart'; // Notification and alarm display service
import 'services/navigation_service.dart'; // Navigation helper - provides global navigation context
import 'dart:developer' as dev; // Dart developer logging utilities - namespaced to avoid conflicts
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode; // Build mode flags - determines dev features availability
import 'debug/dev_server.dart'; // Development HTTP server - for remote demo triggering during testing
import 'package:flutter_background_service/flutter_background_service.dart'; // Background task execution - keeps tracking alive when app is closed

// ═══════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════
// This is the very first function called when the app starts. The async keyword
// allows us to use 'await' for operations that take time (like initializing databases).
Future<void> main() async { // Entry point - executed by Dart runtime when app launches
  // Ensure Flutter binding is initialized before any Flutter-specific code.
  WidgetsFlutterBinding.ensureInitialized(); // Required before using any Flutter features in async main() - initializes the binding between Flutter framework and platform
  // This must be called before any code that interacts with the Flutter engine,
  // plugins, or platform channels. Without this, the app would crash.
  
  // Initialize Hive itself. We will let the service manage opening the box.
  try { // Exception handling block - wraps risky operations
    await Hive.initFlutter(); // Initialize Hive database engine - sets up path and prepares for box opening
    // Hive.initFlutter() determines the best storage location per platform (iOS vs Android vs Desktop)
    dev.log("Hive engine initialized successfully.", name: "main"); // Log success for debugging - visible in IDE console and logcat
    // The 'name' parameter groups logs by component for easier filtering
  } catch (e) { // Catch any initialization errors - could occur if storage is full or permissions denied
    dev.log("FATAL: Hive initialization failed: $e", name: "main"); // Log critical error - app may not work correctly without Hive
    // Even though initialization failed, we continue rather than crash - allows app to potentially run with degraded functionality
  } // End try-catch for Hive initialization
  
  // Initialize other essential services.
  await _initializeServices(); // Call helper function to set up API client, notifications, tracking - keeps main() clean and readable
  // This is separated into its own function for better code organization and testability
  
  runApp(const MyApp()); // Launch Flutter application widget tree - creates and displays the UI
  // MyApp is the root widget - all other screens descend from it
  // 'const' indicates this widget never changes, allowing Flutter to optimize rendering
} // End main function

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE INITIALIZATION HELPER
// ═══════════════════════════════════════════════════════════════════════════
// Separate function to keep service initializations clean.
// This pattern improves code readability and makes it easier to add/remove services.
Future<void> _initializeServices() async { // Helper function - async to allow sequential awaiting of service startups
  // The underscore prefix indicates this is a private function (not accessible outside this file)
  
  // Initialize API client FIRST - this secures all API calls
  try { // Wrap in try-catch - API initialization could fail due to network issues
    await ApiClient.instance.initialize(); // Set up secure API client singleton - establishes connection to backend server
    // ApiClient.instance uses the singleton pattern - one shared instance across entire app
    // The backend server holds the Google Maps API key, keeping it secure
    dev.log("API Client initialized successfully.", name: "main"); // Log successful API client setup
  } catch (e) { // Catch initialization failure - could be network issue, server down, etc.
    dev.log("API Client initialization failed: $e", name: "main"); // Log error but continue - app can still work with cached data
    // Non-fatal error - app continues to launch even if API client fails
  } // End try-catch for API client

  // Initialize notification system - required for alarm display
  try { // Wrap in try-catch - notification permission might be denied
    await NotificationService().initialize(); // Set up notification channels and request permissions
    // Creates notification channels for Android, configures sound/vibration settings
    // Also requests notification permission on Android 13+ and iOS
  } catch (e) { // Catch permission denial or system errors
    dev.log("Notification Service initialization failed: $e", name: "main"); // Log error - alarms won't work without notifications
    // Without notifications, the core alarm feature won't function properly
  } // End try-catch for notification service

  // Initialize background tracking service
  try { // Wrap in try-catch - background service might fail on some devices
    await TrackingService().initializeService(); // Configure background service for location tracking
    // Sets up the isolate that runs independently of the main app
    // This service continues running even when app is closed or screen is off
  } catch (e) { // Catch background service setup failures
    dev.log("Tracking Service initialization failed: $e", name: "main"); // Log error - tracking won't work without background service
    // Tracking requires background service to monitor location when app isn't visible
  } // End try-catch for tracking service

  // Start lightweight dev HTTP server in debug/profile for remote demo triggers
  if (kDebugMode || kProfileMode) { // Conditional compilation - only run in development builds
    // kDebugMode = flutter run, kProfileMode = flutter run --profile
    // Production builds (kReleaseMode) skip this code entirely
    // ignore: unawaited_futures
    DevServer.start(); // Start HTTP server on port 8765 for remote demo control
    // Allows triggering demo routes via HTTP requests (useful for testing on real devices)
    // We ignore the Future because we don't need to wait for server startup
    // The 'ignore' comment suppresses linter warning about not awaiting this Future
  } // End dev server conditional
} // End _initializeServices function
// Block summary: This function initializes all critical services in sequence.
// Each service is wrapped in try-catch to prevent one failure from blocking others.
// Services are initialized in dependency order: API client → notifications → tracking → dev tools.
// This ensures the app can still partially function even if some services fail.

// ═══════════════════════════════════════════════════════════════════════════
// ROOT APPLICATION WIDGET
// ═══════════════════════════════════════════════════════════════════════════
class MyApp extends StatefulWidget { // Root application widget - top of the widget tree
  // StatefulWidget allows this widget to change over time (for theme toggling)
  // This is the ancestor of all screens in the app
  const MyApp({super.key}); // Constructor - 'super.key' passes key to parent StatefulWidget
  // 'key' is used by Flutter to identify widgets in the tree for efficient updates

  @override
  MyAppState createState() => MyAppState(); // Create mutable state object - stores theme preference
  // Flutter separates widgets (configuration) from state (mutable data)
} // End MyApp class

class MyAppState extends State<MyApp> with WidgetsBindingObserver { // State class - holds mutable data and lifecycle callbacks
  // State<MyApp> links this state to MyApp widget
  // WidgetsBindingObserver mixin - provides app lifecycle callbacks (pause, resume, etc.)
  // Lifecycle callbacks are crucial for saving data before the app is killed by OS
  
  bool isDarkMode = false; // Current theme state - toggles between light and dark themes
  // false = light mode, true = dark mode
  // This could be persisted to Hive in future versions

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE: INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════
  @override // Overrides State.initState() - called once when state object is created
  void initState() { // Widget initialization - runs once when MyAppState is first created
    super.initState(); // Call parent initialization - required in all override methods
    // Always call super.initState() first to ensure proper Flutter framework setup
    
    // Start listening for app lifecycle events (pause, resume, etc.).
    WidgetsBinding.instance.addObserver(this); // Register this object as lifecycle observer
    // Now didChangeAppLifecycleState will be called when app is paused/resumed/detached
    // Critical for saving data before OS kills the app
    
    // =======================================================================
    // FIX: Call the permission check function here.
    // =======================================================================
    _checkNotificationPermission(); // Request notification permission on Android 13+ and iOS
    // Must be done early so alarms can display when triggered
    // Without this, notifications would silently fail on modern Android versions
    
    // If an alarm was fired while app was backgrounded, present it now.
    NotificationService().showPendingAlarmScreenIfAny(); // Check for pending alarms and display full-screen UI
    // This handles the case where an alarm triggered while app was closed/minimized
    // The full-screen alarm activity will be shown immediately upon app launch

    // Bridge background 'fireAlarm' events to foreground UI/audio
    try { // Wrap in try-catch - service communication might fail
      final service = FlutterBackgroundService(); // Get reference to background service instance
      service.on('fireAlarm').listen((event) async { // Subscribe to 'fireAlarm' events from background isolate
        // The background service sends 'fireAlarm' when it detects alarm trigger conditions
        // This allows the foreground app to display UI and play sounds
        if (event == null) return; // Guard against null events - shouldn't happen but prevents crashes
        
        // Extract alarm parameters from event data
        final title = (event['title'] as String?) ?? 'Wake Up!'; // Alarm notification title - default if not provided
        final body = (event['body'] as String?) ?? 'Approaching your target'; // Alarm notification body - default message
        final allow = (event['allowContinueTracking'] as bool?) ?? true; // Whether to show "Continue Tracking" button
        // For destination alarms, allowContinueTracking=false (end journey)
        // For transfer alarms, allowContinueTracking=true (continue to next leg)
        
        // Show full-screen alarm notification + native activity and play sound
        await NotificationService().showWakeUpAlarm( // Display full-screen alarm with sound
          title: title, // Pass title to notification
          body: body, // Pass body text to notification
          allowContinueTracking: allow, // Pass button visibility flag
        ); // End showWakeUpAlarm call
        // This displays both a notification AND a full-screen activity on Android
        // The activity ensures the alarm wakes the user even with screen off
      }); // End event listener
    } catch (e) { // Catch subscription failures - background service might not be running
      dev.log('Failed to subscribe to fireAlarm: $e', name: 'main'); // Log error - alarms might not display
      // Non-fatal - app continues but background alarms won't trigger foreground UI
    } // End try-catch for event subscription
  } // End initState
  // Block summary: initState sets up critical infrastructure:
  // 1. Registers lifecycle observer for app pause/resume events
  // 2. Requests notification permission for alarms
  // 3. Shows any alarms that triggered while app was closed
  // 4. Subscribes to background alarm events for real-time notifications
  // All setup is non-blocking to ensure fast app startup.

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE: CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════
  @override // Overrides State.dispose() - called when this state object is removed
  void dispose() { // Widget cleanup - runs when MyAppState is destroyed (app fully closes)
    // Stop listening to prevent memory leaks.
    WidgetsBinding.instance.removeObserver(this); // Unregister lifecycle observer
    // Critical to prevent memory leak - observer holds reference to this object
    // Without removal, this object would never be garbage collected
    
    // As a final cleanup when the app is truly closing, close Hive.
    Hive.close(); // Close all Hive boxes and release file handles
    // Ensures all data is flushed to disk before app termination
    // Without this, uncommitted data could be lost
    
    super.dispose(); // Call parent cleanup - required in all override methods
    // Always call super.dispose() last to ensure proper Flutter framework cleanup
  } // End dispose
  // Block summary: dispose performs cleanup when app is destroyed:
  // 1. Removes lifecycle observer to prevent memory leaks
  // 2. Closes Hive database to flush pending writes
  // This ensures graceful shutdown and data persistence.

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE: STATE CHANGES
  // ═══════════════════════════════════════════════════════════════════════════
  // This is the definitive fix for saving data before the app closes.
  @override // Overrides WidgetsBindingObserver.didChangeAppLifecycleState
  void didChangeAppLifecycleState(AppLifecycleState state) { // Called when app transitions between foreground/background
    super.didChangeAppLifecycleState(state); // Call parent handler - always call super in overrides
    
    // This is called when the user backgrounds the app (e.g., presses home).
    if (state == AppLifecycleState.paused) { // App moved to background - home button pressed or switched apps
      dev.log("App paused, flushing Hive box to disk.", name: "main"); // Log data save operation
      
      // `flush()` is a direct command to write all in-memory changes to disk.
      // This prevents the OS from killing the app before data is saved.
      if (Hive.isBoxOpen(RecentLocationsService.boxName)) { // Check if box is open before flushing
        // Only flush if box is open - flushing closed box would throw exception
        Hive.box(RecentLocationsService.boxName).flush(); // Force write to disk immediately
        // flush() blocks until all pending writes complete
        // Critical for Android where OS aggressively kills background apps
        // Without flush, recent locations could be lost when app is killed
      } // End box open check
    } // End paused state handling
    
    if (state == AppLifecycleState.resumed) { // App moved to foreground - user returned to app
      // On resume, auto-present any pending full-screen alarm.
      NotificationService().showPendingAlarmScreenIfAny(); // Show alarm UI if alarm triggered while backgrounded
      // Ensures user sees alarm even if they manually returned to app
      // Handles edge case where notification was dismissed but full-screen alarm should still show
    } // End resumed state handling
  } // End didChangeAppLifecycleState
  // Block summary: Lifecycle state handler ensures data persistence and alarm visibility:
  // - On pause: Flush Hive data to disk (prevents data loss when OS kills app)
  // - On resume: Show any pending alarms (ensures user doesn't miss alarms)
  // This is critical for Android's aggressive background app killing.

  // ═══════════════════════════════════════════════════════════════════════════
  // PERMISSION MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════
  /// Check and request notification permission on Android 13+ or iOS.
  Future<void> _checkNotificationPermission() async { // Request notification permission if not granted
    final status = await Permission.notification.status; // Check current permission status
    // Returns granted, denied, permanentlyDenied, restricted, or limited
    
    if (status.isDenied) { // Permission not yet requested or was denied but can be requested again
      await Permission.notification.request(); // Show system permission dialog
      // On Android 13+, this is required for notifications to appear
      // On iOS, required for all notification types
      // If user denies, alarms won't display (critical feature failure)
    } // End denied status handling
    // Note: We don't handle permanentlyDenied - user must enable in system settings
  } // End _checkNotificationPermission
  // Block summary: Ensures notification permission is granted for alarm display.
  // Required on Android 13+ and iOS. Without this, core app functionality breaks.

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME TOGGLE
  // ═══════════════════════════════════════════════════════════════════════════
  void toggleTheme() { // Switch between light and dark themes
    setState(() { // Trigger widget rebuild with new theme
      isDarkMode = !isDarkMode; // Toggle boolean - flip current theme
      // setState() notifies Flutter that state changed and UI needs rebuilding
      // This will trigger build() to run with new isDarkMode value
    }); // End setState
  } // End toggleTheme
  // Block summary: Simple theme toggle - flips isDarkMode flag and rebuilds UI.
  // Called from settings drawer. Could be enhanced to persist preference to Hive.

  // ═══════════════════════════════════════════════════════════════════════════
  // UI BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override // Overrides State.build - called when widget needs to render
  Widget build(BuildContext context) { // Build UI tree - called on every setState and parent rebuild
    return MaterialApp( // Root of Material Design widget tree
      // MaterialApp provides navigation, theme, localization, and other app-level features
      
      title: 'GeoWake', // App title - shown in task switcher and window title
      // On Android, appears in recent apps list
      // On desktop, appears in window title bar
      
      navigatorKey: NavigationService.navigatorKey, // Global navigation key for push without context
      // Allows navigation from services/background tasks where BuildContext isn't available
      // Critical for showing alarm screens from background service
      
      theme: isDarkMode ? AppThemes.darkTheme : AppThemes.lightTheme, // Apply theme based on toggle state
      // Ternary operator: if isDarkMode is true, use darkTheme, else use lightTheme
      // AppThemes defines colors, typography, and widget styles
      // Theme cascades down to all descendant widgets
      
      initialRoute: '/splash', // First screen to show - splash screen during initialization
      // App starts here while services initialize in background
      // After initialization completes, navigates to home screen
      
      onGenerateRoute: (settings) { // Route factory - creates screens based on route name
        // Called whenever Navigator.pushNamed is invoked
        // settings.name contains the route path (e.g., '/splash', '/mapTracking')
        
        if (settings.name == '/splash') { // Splash screen route - shown during app initialization
          return MaterialPageRoute( // Create page route with platform transition animations
            builder: (_) => const SplashScreen(), // Create splash screen widget
            // Underscore parameter name convention: parameter exists but isn't used
            settings: settings, // Pass settings to route for name/arguments access
          ); // End MaterialPageRoute
        } // End splash route
        
        if (settings.name == '/preloadMap') { // Map preload screen - for downloading offline tiles
          final args = settings.arguments as Map<String, dynamic>; // Extract route arguments
          // Arguments passed via Navigator.pushNamed arguments parameter
          // Cast to expected type - contains bounds and zoom level for preloading
          return MaterialPageRoute( // Create page route
            builder: (_) => PreloadMapScreen(arguments: args), // Pass arguments to screen
            settings: settings, // Pass settings to route
          ); // End MaterialPageRoute
        } // End preloadMap route
        
        if (settings.name == '/mapTracking') { // Active tracking screen - shows route progress on map
          return MaterialPageRoute( // Create page route
            builder: (_) => MapTrackingScreen(), // Create tracking screen
            // Note: No const because MapTrackingScreen has mutable state
            settings: settings, // Pass settings to route
          ); // End MaterialPageRoute
        } // End mapTracking route
        
        if (settings.name == '/') { // Home screen route - main app screen
          return MaterialPageRoute(builder: (_) => const HomeScreen()); // Create home screen
        } // End home route
        
        return null; // Unknown route - MaterialApp will show default error screen
        // In production, could log unknown route attempts for analytics
      }, // End onGenerateRoute
    ); // End MaterialApp
  } // End build
  // Block summary: build() creates the app widget tree with MaterialApp as root.
  // Sets up navigation, theme, and route handling. Routes are:
  // - /splash: Initial loading screen
  // - /preloadMap: Offline map tile download
  // - /mapTracking: Active route tracking with map
  // - /: Main home screen for route creation
  // Theme dynamically switches based on isDarkMode flag.
} // End MyAppState class

/* ═══════════════════════════════════════════════════════════════════════════
   FILE SUMMARY: main.dart - Application Entry Point and Lifecycle Management
   ═══════════════════════════════════════════════════════════════════════════
   
   This file is the foundation of the GeoWake application. It handles:
   
   1. APP INITIALIZATION (main function):
      - Initializes Flutter framework binding
      - Sets up Hive database engine
      - Initializes API client, notifications, and tracking services
      - Starts development HTTP server in debug mode
      - Launches the widget tree
   
   2. LIFECYCLE MANAGEMENT (MyAppState):
      - Monitors app state transitions (foreground/background)
      - Flushes database to disk when app is paused (critical for data persistence)
      - Shows pending alarms when app resumes
      - Cleans up resources on app termination
   
   3. PERMISSION HANDLING:
      - Requests notification permission on Android 13+ and iOS
      - Required for core alarm functionality
   
   4. ALARM EVENT BRIDGING:
      - Subscribes to background service 'fireAlarm' events
      - Displays full-screen alarms when triggered from background
      - Ensures alarms work even when app is closed
   
   5. THEME MANAGEMENT:
      - Toggles between light and dark themes
      - Could be enhanced to persist theme preference
   
   6. NAVIGATION ROUTING:
      - Defines app routes (splash, home, tracking, preload)
      - Provides global navigation key for service-level navigation
   
   CONNECTIONS TO OTHER FILES:
   
   - services/trackingservice.dart: Initialized in _initializeServices, provides background location tracking
   - services/api_client.dart: Initialized first to secure all API calls through backend
   - services/notification_service.dart: Handles alarm display and notification channels
   - services/navigation_service.dart: Provides global navigation without BuildContext
   - screens/*: All screens are routed through onGenerateRoute
   - themes/appthemes.dart: Theme definitions applied based on isDarkMode
   - debug/dev_server.dart: HTTP server for remote demo control in development
   - config/app_config.dart: Could be used for environment-specific configuration
   
   CRITICAL BEHAVIORS:
   
   - Data Persistence: Hive.flush() on app pause prevents data loss when OS kills app
   - Alarm Reliability: Background event subscription ensures alarms display from any state
   - Permission Correctness: Early notification permission request prevents silent failures
   - Service Resilience: Try-catch around each service init allows partial functionality on failure
   - Development Tools: Dev server only starts in debug/profile builds, never in production
   
   POTENTIAL ISSUES / FUTURE ENHANCEMENTS:
   
   - Theme preference not persisted (resets to light on app restart)
   - No handling of permanentlyDenied notification permission (should guide user to settings)
   - No retry logic for failed service initialization
   - Could add analytics/crash reporting initialization
   - Could add deep link handling in route generator
   - Background service event subscription not retried on failure
   
   This file ties together the entire application infrastructure. Everything flows through here:
   services are initialized, screens are routed, lifecycle events are handled, and themes are applied.
   Understanding this file is essential for understanding how GeoWake operates at a fundamental level.
*/
