// Annotated copy of lib/debug/demo_tools.dart
// Purpose: Demo route simulation with GPS position injection for testing alarm functionality.
// This file provides tools to simulate complete journeys without requiring actual GPS movement.

import 'dart:async'; // Dart async primitives - Future, Stream, StreamController, Timer, Completer
import 'dart:math' as math; // Dart math library - sin, cos, pi, sqrt, etc. (namespaced to avoid conflicts)
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Google Maps Flutter - LatLng coordinate class
import 'package:geolocator/geolocator.dart'; // Geolocator plugin - Position class, GPS access
import 'package:geowake2/services/trackingservice.dart'; // Background tracking service - location monitoring and alarms
import 'package:geowake2/services/notification_service.dart'; // Notification display service - alarms and progress
import 'package:geowake2/services/alarm_player.dart'; // Audio player - plays selected alarm ringtone
import 'package:permission_handler/permission_handler.dart'; // Permission plugin - notification permission handling
import 'dart:developer' as dev; // Dart developer tools - logging (namespaced to avoid conflicts)
import 'package:flutter_background_service/flutter_background_service.dart'; // Background service - isolate communication

// ═══════════════════════════════════════════════════════════════════════════
// DEMO ROUTE SIMULATOR CLASS
// ═══════════════════════════════════════════════════════════════════════════
class DemoRouteSimulator { // Static utility class for demo journey simulation
  // All methods are static - no instance needed, acts as namespace
  // Provides three main functions:
  //   1. Full journey simulation with GPS injection
  //   2. Transfer alarm demo (instant)
  //   3. Destination alarm demo (instant)
  
  static StreamController<Position>? _ctrl; // Position stream for GPS injection
  // StreamController allows manual Position event emission
  // Used to feed fake GPS positions to tracking service
  // Nullable because stream is only active during demo
  // Static because only one demo can run at a time

  // ═══════════════════════════════════════════════════════════════════════════
  // DEMO JOURNEY SIMULATION
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> startDemoJourney({LatLng? origin}) async { // Simulate complete journey with GPS positions
    // Creates a short demo route and feeds simulated GPS positions over ~18 seconds
    // origin: Optional custom starting location (defaults to Bangalore if not provided)
    
    dev.log('startDemoJourney() called', name: 'DemoRouteSimulator'); // Log entry point
    
    await _ensureNotificationsReady(); // Request notification permission if needed
    // Must be done before showing alarms - alarms won't display without permission
    
    // Ensure real notifications even in test-mode logic path
    NotificationService.isTestMode = false; // Disable test mode - show real notifications
    // Test mode suppresses notifications to avoid spam during unit tests
    // Demo needs real notifications to verify alarm functionality
    
    TrackingService.isTestMode = false; // Disable test mode - enable real tracking
    // Test mode might skip GPS monitoring or use mock data
    // Demo needs real tracking service behavior
    
    try { 
      await TrackingService().initializeService(); // Initialize background service if not already running
      dev.log('Background service configured', name: 'DemoRouteSimulator'); 
    } catch (e) { 
      dev.log('Init service failed: $e', name: 'DemoRouteSimulator'); 
    } // Non-fatal - continue even if service init fails
    
    try {
      await NotificationService().showJourneyProgress( // Show initial progress notification
        title: 'GeoWake journey', // Notification title
        subtitle: 'Starting…', // Initial status message
        progress0to1: 0, // Progress bar at 0% (journey just started)
      ); // This creates the persistent notification showing route progress
    } catch (e) { 
      dev.log('Initial progress notify failed: $e', name: 'DemoRouteSimulator'); 
    } // Non-fatal - notification failure doesn't prevent demo

    final LatLng start = origin ?? const LatLng(12.9600, 77.5855); // Starting location
    // If origin not provided, default to coordinates in Bangalore, India
    // 12.9600°N, 77.5855°E is approximately in central Bangalore
    
    final LatLng dest = _offsetMeters(start, dxMeters: 1200, dyMeters: 0); // ~1.2 km east
    // Create destination 1200 meters east of start location
    // dyMeters: 0 = no north/south offset (purely east-west route)
    // This creates a short demo route suitable for quick testing
    
    final points = _interpolate(start, dest, 60); // Create 60 intermediate points
    // Generates 60 evenly-spaced coordinates along straight line from start to dest
    // More points = smoother route animation
    // 60 points over 1.2km ≈ 20 meters between points

    // Register route directly without network
    TrackingService().registerRoute( // Add route to tracking service without API call
      key: 'demo_route', // Unique identifier for this demo route
      mode: 'driving', // Travel mode (affects deviation thresholds)
      destinationName: 'Demo Destination', // Display name for destination
      points: points, // The 60 interpolated route points
    ); // Bypasses DirectionService - route created directly in memory
    // This avoids network calls and API key usage for demos

    // Use injected positions into background service for realistic progress
    FlutterBackgroundService().invoke('useInjectedPositions'); // Tell background service to use fake GPS
    // Switches background service from real GPS to injected Position stream
    // Allows demo to work indoors or on emulators without GPS
    
    _ctrl?.close(); // Close any existing position stream from previous demo
    // Cleanup from previous demo run (if any)
    
    _ctrl = StreamController<Position>(); // Create new position stream controller
    // Fresh stream for this demo journey
    // Will emit 60 Position events (one per route point)

    // Start tracking with small distance alarm
    dev.log('Starting tracking to demo dest...', name: 'DemoRouteSimulator');
    await TrackingService().startTracking( // Begin active route tracking
      destination: dest, // Destination coordinates (1.2km east of start)
      destinationName: 'Demo Destination', // Display name
      alarmMode: 'distance', // Trigger alarm based on distance to destination
      alarmValue: 0.2, // 200 m before destination
      // When remaining distance < 200m, alarm fires
      allowNotificationsInTest: true, // Force notifications even in test mode
    ); // This starts background GPS monitoring and alarm checking

    // Push positions periodically (~18 seconds total)
    int i = 0; // Current position index (0-59)
    Timer.periodic(const Duration(milliseconds: 300), (t) { // Fire every 300ms
      // 60 points × 300ms = 18,000ms = 18 seconds total journey duration
      // 300ms interval creates smooth animation (3.3 positions per second)
      
      dev.log('Demo tick ${i+1}/${points.length}', name: 'DemoRouteSimulator'); // Log progress
      
      if (_ctrl == null || _ctrl!.isClosed) { // Stream was closed (demo cancelled)
        t.cancel(); // Stop timer
        return; // Exit periodic callback
      } // End stream closed check
      
      if (i >= points.length) { // All positions sent - journey complete
        t.cancel(); // Stop timer
        _ctrl!.close(); // Close position stream
        return; // Exit periodic callback
      } // End journey complete check
      
      final p = points[i++]; // Get next route point and increment index
      // i++ post-increment: use current value then add 1
      
      final pos = Position( // Create Position object from route point
        latitude: p.latitude, // Latitude from LatLng
        longitude: p.longitude, // Longitude from LatLng
        timestamp: DateTime.now(), // Current time (positions appear real-time)
        accuracy: 5.0, // GPS accuracy in meters (5m is good accuracy)
        altitude: 0.0, // Height above sea level (not important for demo)
        altitudeAccuracy: 0.0, // Altitude precision (not used)
        heading: 0.0, // Direction of movement in degrees (0 = north)
        headingAccuracy: 0.0, // Heading precision (not used)
        speed: 12.0, // Movement speed in m/s (12 m/s ≈ 43 km/h ≈ 27 mph)
        speedAccuracy: 1.0, // Speed precision in m/s (±1 m/s)
      ); // Position mimics real GPS data structure
      
      _ctrl!.add(pos); // Emit position to stream
      // This triggers tracking service to process new location
      
      // Send into background service as well, to drive foreground notification progress
      FlutterBackgroundService().invoke('injectPosition', { // Send position to background isolate
        // Background service runs in separate isolate - can't access _ctrl stream
        // Must send position data via invoke() message passing
        'latitude': pos.latitude, // Copy all fields to Map for serialization
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'altitude': pos.altitude,
        'altitudeAccuracy': pos.altitudeAccuracy,
        'heading': pos.heading,
        'headingAccuracy': pos.headingAccuracy,
        'speed': pos.speed,
        'speedAccuracy': pos.speedAccuracy,
      }); // Background service updates progress notification based on this position
    }); // End Timer.periodic
  } // End startDemoJourney
  // Block summary: startDemoJourney creates a 1.2km demo route and simulates GPS movement.
  // Sends 60 positions over 18 seconds, triggering distance alarm at 200m from destination.
  // Works without real GPS or network - perfect for indoor testing.

  // ═══════════════════════════════════════════════════════════════════════════
  // INSTANT ALARM DEMOS
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> triggerTransferAlarmDemo() async { // Show transfer alarm immediately
    // Simulates metro transfer alarm without running full journey
    // Useful for testing transfer alarm UI and sound in isolation
    
    dev.log('triggerTransferAlarmDemo() called', name: 'DemoRouteSimulator');
    await _ensureNotificationsReady(); // Request notification permission
    NotificationService.isTestMode = false; // Show real notification
    
    await NotificationService().showWakeUpAlarm( // Display full-screen alarm
      title: 'Upcoming transfer', // Alarm title
      body: 'Change at Central Station', // Alarm message
      allowContinueTracking: true, // Show "Continue Tracking" button
      // Transfer alarms allow continuing (user moves to next transit leg)
    ); // Shows both notification and full-screen activity
    
    await AlarmPlayer.playSelected(); // Play alarm ringtone
    // Plays sound selected in settings (or default if none selected)
  } // End triggerTransferAlarmDemo
  // Block summary: Instantly shows transfer alarm with sound.
  // Used to test transfer alarm functionality without simulating full metro route.

  static Future<void> triggerDestinationAlarmDemo() async { // Show destination alarm immediately
    // Simulates destination arrival alarm without running full journey
    // Useful for testing destination alarm UI and sound in isolation
    
    dev.log('triggerDestinationAlarmDemo() called', name: 'DemoRouteSimulator');
    await _ensureNotificationsReady(); // Request notification permission
    NotificationService.isTestMode = false; // Show real notification
    
    await NotificationService().showWakeUpAlarm( // Display full-screen alarm
      title: 'Wake Up!', // Alarm title
      body: 'Approaching: Demo Destination', // Alarm message
      allowContinueTracking: false, // Hide "Continue Tracking" button
      // Destination alarms don't allow continuing (journey ends)
    ); // Shows both notification and full-screen activity
    
    await AlarmPlayer.playSelected(); // Play alarm ringtone
    // Plays sound selected in settings (or default if none selected)
  } // End triggerDestinationAlarmDemo
  // Block summary: Instantly shows destination alarm with sound.
  // Used to test destination alarm functionality without simulating full route.

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> _ensureNotificationsReady() async { // Ensure notification system is initialized
    // Private helper - ensures notification service is ready and permission granted
    
    try {
      await NotificationService().initialize(); // Initialize notification channels
      dev.log('Notification service initialized', name: 'DemoRouteSimulator');
    } catch (e) { 
      dev.log('Notification init failed: $e', name: 'DemoRouteSimulator'); 
    } // Non-fatal - continue even if init fails
    
    final status = await Permission.notification.status; // Check notification permission
    dev.log('Notification permission status: $status', name: 'DemoRouteSimulator');
    
    if (!status.isGranted) { // Permission not granted - request it
      final req = await Permission.notification.request(); // Show permission dialog
      dev.log('Notification permission requested, result: $req', name: 'DemoRouteSimulator');
      // Without permission, alarms won't display (critical demo failure)
    } // End permission check
  } // End _ensureNotificationsReady
  // Block summary: Initializes notification service and ensures permission is granted.
  // Called by all demo methods before showing alarms.

  static List<LatLng> _interpolate(LatLng a, LatLng b, int n) { // Generate points between two coordinates
    // Creates n evenly-spaced points along straight line from a to b
    // Linear interpolation in lat/lng space (not geodesic)
    // Good enough for short distances (<10km) where Earth curvature is negligible
    
    final List<LatLng> pts = []; // Result array
    for (int i = 0; i < n; i++) { // Generate n points
      final t = i / (n - 1); // Interpolation factor: 0.0 to 1.0
      // i=0 → t=0.0 (point a)
      // i=n-1 → t=1.0 (point b)
      // i=n/2 → t=0.5 (midpoint)
      
      pts.add(LatLng( // Create interpolated point
        a.latitude + (b.latitude - a.latitude) * t, // Linear interpolation: a + (b-a)*t
        a.longitude + (b.longitude - a.longitude) * t,
      )); // Standard lerp formula
    } // End for loop
    return pts; // Return array of n points
  } // End _interpolate
  // Block summary: Linear interpolation between two coordinates.
  // Creates smooth path with n evenly-spaced points.
  // Used to generate demo route points between start and destination.

  static LatLng _offsetMeters(LatLng p, {double dxMeters = 0, double dyMeters = 0}) { // Offset coordinate by meters
    // Moves a coordinate by specified meters east (dx) and north (dy)
    // Uses approximate flat-Earth formula (good for small offsets)
    // More accurate methods exist (Vincenty, Haversine) but overkill for demos
    
    const double earth = 6378137.0; // Earth radius in meters (equatorial)
    // WGS84 ellipsoid semi-major axis
    // Used to convert meters to degrees
    
    final dLat = dyMeters / earth; // Meters north → radians latitude
    // 1 degree latitude ≈ 111km everywhere (latitude lines are parallel)
    // dyMeters / earth = radians, then converted to degrees below
    
    final dLng = dxMeters / (earth * math.cos(math.pi * p.latitude / 180.0)); // Meters east → radians longitude
    // Longitude degree distance varies by latitude (converges at poles)
    // At equator: 1 degree ≈ 111km
    // At 45°: 1 degree ≈ 78km
    // At 89°: 1 degree ≈ 2km
    // math.cos(lat in radians) accounts for this convergence
    
    final lat = p.latitude + dLat * 180.0 / math.pi; // Convert radians to degrees and add to original
    final lng = p.longitude + dLng * 180.0 / math.pi;
    
    return LatLng(lat, lng); // Return offset coordinate
  } // End _offsetMeters
  // Block summary: Offsets a coordinate by specified meters east/north.
  // Uses simplified spherical Earth model (accurate enough for <10km offsets).
  // Used to create demo destination from start location.
} // End DemoRouteSimulator class

/* ═══════════════════════════════════════════════════════════════════════════
   FILE SUMMARY: demo_tools.dart - GPS Journey Simulation for Testing
   ═══════════════════════════════════════════════════════════════════════════
   
   This file provides tools for simulating complete journeys without requiring
   actual GPS movement or network access. It's essential for:
   - Indoor testing (no GPS signal)
   - Emulator testing (emulators don't move)
   - Automated testing (reproducible scenarios)
   - Quick manual testing (no need to physically travel)
   
   THREE MAIN FUNCTIONS:
   
   1. startDemoJourney({origin}):
      - Creates 1.2km route (60 points)
      - Simulates GPS movement over 18 seconds
      - Triggers distance alarm at 200m from destination
      - Shows progress notification during journey
      - Works without GPS or network
      
   2. triggerTransferAlarmDemo():
      - Instantly shows metro transfer alarm
      - Includes sound and full-screen UI
      - Tests transfer alarm in isolation
      
   3. triggerDestinationAlarmDemo():
      - Instantly shows destination arrival alarm
      - Includes sound and full-screen UI
      - Tests destination alarm in isolation
   
   TECHNICAL APPROACH:
   
   - GPS Injection: Uses StreamController to emit fake Position objects
   - Background Service: Sends positions to both foreground and background isolates
   - No Network: Route created directly without API calls
   - Real Notifications: Disables test mode to show actual alarms
   - Timing: 300ms intervals for smooth animation (60 positions in 18 seconds)
   
   POSITION SIMULATION:
   
   - Accuracy: 5m (good GPS signal)
   - Speed: 12 m/s (43 km/h, typical driving)
   - Heading: 0° (north, not critical for demo)
   - Timestamp: Real-time (positions appear current)
   
   ROUTE GENERATION:
   
   - Start: Custom or default (Bangalore: 12.96°N, 77.585°E)
   - End: 1200m east of start
   - Points: 60 (linear interpolation)
   - Spacing: ~20m between points
   
   ALARM CONFIGURATION:
   
   - Mode: Distance-based (not time-based)
   - Threshold: 200m (0.2 km)
   - Trigger: When remaining distance < 200m
   - Action: Full-screen alarm + sound + notification
   
   CONNECTIONS TO OTHER FILES:
   
   - debug/dev_server.dart: HTTP endpoints call these demo functions
   - services/trackingservice.dart: Receives injected positions, monitors progress
   - services/notification_service.dart: Displays alarms and progress notifications
   - services/alarm_player.dart: Plays alarm sound
   - screens/alarm_fullscreen.dart: Full-screen alarm UI shown on trigger
   
   DEMO FLOW:
   
   1. Dev server receives /demo/journey request
   2. startDemoJourney() called with optional origin
   3. Notification permission requested
   4. Background service initialized
   5. 60-point route generated (start to 1.2km east)
   6. Route registered in tracking service
   7. Tracking started with 200m distance alarm
   8. Timer starts: 300ms intervals
   9. Each tick: emit Position, update background service
   10. Progress notification shows journey advancement
   11. At ~54th position (200m from end): alarm triggers
   12. Full-screen alarm shown + sound played
   13. User dismisses alarm or lets journey complete
   14. Timer ends, stream closes, demo complete
   
   HELPER FUNCTIONS:
   
   - _ensureNotificationsReady(): Init notification service, request permission
   - _interpolate(a, b, n): Generate n points between coordinates
   - _offsetMeters(p, dx, dy): Move coordinate by meters (flat-Earth approximation)
   
   MATH DETAILS:
   
   Linear Interpolation:
   - Formula: point = start + (end - start) * t
   - t ranges 0 to 1 (0=start, 0.5=midpoint, 1=end)
   - Applied independently to lat and lng
   
   Meter Offset:
   - Earth radius: 6,378,137m (WGS84 equatorial)
   - Latitude: 1° ≈ 111km everywhere (parallel lines)
   - Longitude: 1° ≈ 111km * cos(latitude) (convergent lines)
   - Conversion: meters → radians → degrees
   
   LIMITATIONS:
   
   - Straight Line: Route is linear, not following roads
   - Flat Earth: Uses simplified spherical model (inaccurate >10km)
   - Constant Speed: All positions show 12 m/s (real GPS varies)
   - No Deviations: User can't go off-route in demo
   - Single Route: Only one demo can run at a time (shared _ctrl)
   
   POTENTIAL ISSUES / FUTURE ENHANCEMENTS:
   
   - No demo cancellation: Once started, runs to completion
   - No custom alarm distance: Always 200m (could parameterize)
   - No variable speed: Could simulate acceleration/deceleration
   - No road-following: Could use real API route for realistic path
   - No demo for transfer alarms in journey: Only instant demo exists
   - Timer not stored: Can't cancel timer if demo is interrupted
   - No progress callbacks: Caller can't monitor demo state
   - Origin validation: Could validate lat/lng are reasonable values
   
   This file makes testing infinitely easier. Without it, every alarm test would
   require physically traveling or complex GPS mocking. It's a critical development
   tool that enables rapid iteration and automated testing.
*/
