// Annotated copy of lib/debug/demo_tools.dart
// Purpose: Document demo/testing tools for simulating GPS journeys and triggering alarms without real navigation.

import 'dart:async'; // For Timer and StreamController
import 'dart:math' as math; // For geographic coordinate calculations
import 'package:google_maps_flutter/google_maps_flutter.dart'; // LatLng coordinate type
import 'package:geolocator/geolocator.dart'; // Position type for GPS data
import 'package:geowake2/services/trackingservice.dart'; // Background tracking service
import 'package:geowake2/services/notification_service.dart'; // Notification and alarm UI
import 'package:geowake2/services/alarm_player.dart'; // Alarm sound playback
import 'package:permission_handler/permission_handler.dart'; // Runtime permissions
import 'dart:developer' as dev; // Structured logging
import 'package:flutter_background_service/flutter_background_service.dart'; // Background service communication

class DemoRouteSimulator { // Static utility class for demo journey simulation
  static StreamController<Position>? _ctrl; // Optional stream controller for injecting fake GPS positions

  /// Starts a simulated journey from origin to a destination ~1.2km away
  /// This is used for testing/demonstrating the tracking and alarm features without actual travel
  /// The journey completes in ~18 seconds with progress notifications
  static Future<void> startDemoJourney({LatLng? origin}) async { // Main demo journey orchestrator
    dev.log('startDemoJourney() called', name: 'DemoRouteSimulator'); // Log invocation
    await _ensureNotificationsReady(); // Ensure notification permissions and initialization
    
    // Disable test mode flags to ensure real notifications are shown
    // Test mode normally suppresses notifications, but we want to see them in demos
    NotificationService.isTestMode = false; // Enable real notifications
    TrackingService.isTestMode = false; // Enable real tracking service
    
    // Initialize background tracking service
    try { 
      await TrackingService().initializeService(); // Configure background isolate
      dev.log('Background service configured', name: 'DemoRouteSimulator'); // Log success
    } catch (e) { 
      dev.log('Init service failed: $e', name: 'DemoRouteSimulator'); // Log failure
    }
    
    // Show initial journey progress notification
    try {
      await NotificationService().showJourneyProgress(
        title: 'GeoWake journey', // Notification title
        subtitle: 'Starting…', // Initial status message
        progress0to1: 0, // Progress bar at 0% (journey starting)
      ); // End showJourneyProgress
    } catch (e) { 
      dev.log('Initial progress notify failed: $e', name: 'DemoRouteSimulator'); // Log failure
    }

    // Set up demo route coordinates
    final LatLng start = origin ?? const LatLng(12.9600, 77.5855); // Default to Bangalore if no origin provided
    final LatLng dest = _offsetMeters(start, dxMeters: 1200, dyMeters: 0); // Destination ~1.2 km east
    final points = _interpolate(start, dest, 60); // Generate 60 evenly-spaced points along route

    // Register route directly in tracking service (bypass API call for demo)
    TrackingService().registerRoute(
      key: 'demo_route', // Unique route identifier
      mode: 'driving', // Simulating driving mode
      destinationName: 'Demo Destination', // Display name for destination
      points: points, // Route geometry (60 points)
    ); // End registerRoute

    // Enable injected position mode in background service
    // This tells the background service to use our fake GPS positions instead of real GPS
    FlutterBackgroundService().invoke('useInjectedPositions'); // Switch to injection mode
    
    // Close any existing stream controller and create a new one
    _ctrl?.close(); // Clean up old controller
    _ctrl = StreamController<Position>(); // Create new stream for injected positions

    // Start tracking with alarm trigger at 200m before destination
    dev.log('Starting tracking to demo dest...', name: 'DemoRouteSimulator'); // Log tracking start
    await TrackingService().startTracking(
      destination: dest, // Destination coordinates
      destinationName: 'Demo Destination', // Display name
      alarmMode: 'distance', // Trigger alarm based on distance
      alarmValue: 0.2, // 0.2 km = 200 meters before destination
      allowNotificationsInTest: true, // Force notifications even in test-like scenarios
    ); // End startTracking

    // Inject GPS positions at 300ms intervals (~18 seconds total for 60 points)
    int i = 0; // Current point index
    Timer.periodic(const Duration(milliseconds: 300), (t) { // Timer fires every 300ms
      dev.log('Demo tick ${i+1}/${points.length}', name: 'DemoRouteSimulator'); // Log progress
      
      // Check if stream controller was closed (cleanup)
      if (_ctrl == null || _ctrl!.isClosed) {
        t.cancel(); // Stop timer
        return; // Exit callback
      }
      
      // Check if we've reached the end of the route
      if (i >= points.length) {
        t.cancel(); // Stop timer
        _ctrl!.close(); // Close stream
        return; // Exit callback
      }
      
      // Get next point in route
      final p = points[i++]; // Get point and increment index
      
      // Create Position object from LatLng point
      // Position includes additional metadata beyond just lat/lng
      final pos = Position(
        latitude: p.latitude, // Latitude from route point
        longitude: p.longitude, // Longitude from route point
        timestamp: DateTime.now(), // Current timestamp (simulates real-time GPS)
        accuracy: 5.0, // Simulated accuracy (5 meters - good GPS)
        altitude: 0.0, // Sea level altitude (not relevant for demo)
        altitudeAccuracy: 0.0, // Altitude accuracy (not relevant)
        heading: 0.0, // Direction of travel (0 = north, not relevant for demo)
        headingAccuracy: 0.0, // Heading accuracy (not relevant)
        speed: 12.0, // Simulated speed (12 m/s ≈ 43 km/h, typical urban driving)
        speedAccuracy: 1.0, // Speed measurement accuracy
      ); // End Position
      
      _ctrl!.add(pos); // Add position to stream (for local consumption if needed)
      
      // Send position to background service for processing
      // This drives the progress notifications and alarm triggering
      FlutterBackgroundService().invoke('injectPosition', {
        'latitude': pos.latitude, // Latitude data
        'longitude': pos.longitude, // Longitude data
        'accuracy': pos.accuracy, // GPS accuracy
        'altitude': pos.altitude, // Altitude
        'altitudeAccuracy': pos.altitudeAccuracy, // Altitude accuracy
        'heading': pos.heading, // Direction
        'headingAccuracy': pos.headingAccuracy, // Direction accuracy
        'speed': pos.speed, // Speed in m/s
        'speedAccuracy': pos.speedAccuracy, // Speed accuracy
      }); // End invoke
    }); // End Timer.periodic
  } // End startDemoJourney

  /// Triggers a demo transfer alarm (for multi-modal transit)
  /// This simulates an alarm for changing transit modes (e.g., switching from bus to metro)
  static Future<void> triggerTransferAlarmDemo() async { // Demo transfer alarm
    dev.log('triggerTransferAlarmDemo() called', name: 'DemoRouteSimulator'); // Log invocation
    await _ensureNotificationsReady(); // Ensure notification system ready
    NotificationService.isTestMode = false; // Enable real notifications
    
    // Show full-screen alarm for transfer
    await NotificationService().showWakeUpAlarm(
      title: 'Upcoming transfer', // Alarm title
      body: 'Change at Central Station', // Transfer instructions
      allowContinueTracking: true, // Show "Continue" button (user can continue tracking after transfer)
    ); // End showWakeUpAlarm
    
    // Play alarm sound
    await AlarmPlayer.playSelected(); // Play user-selected or default alarm sound
  } // End triggerTransferAlarmDemo

  /// Triggers a demo destination alarm
  /// This simulates an alarm for approaching the final destination
  static Future<void> triggerDestinationAlarmDemo() async { // Demo destination alarm
    dev.log('triggerDestinationAlarmDemo() called', name: 'DemoRouteSimulator'); // Log invocation
    await _ensureNotificationsReady(); // Ensure notification system ready
    NotificationService.isTestMode = false; // Enable real notifications
    
    // Show full-screen alarm for destination
    await NotificationService().showWakeUpAlarm(
      title: 'Wake Up!', // Urgent alarm title
      body: 'Approaching: Demo Destination', // Destination name
      allowContinueTracking: false, // No "Continue" button (journey ends at destination)
    ); // End showWakeUpAlarm
    
    // Play alarm sound
    await AlarmPlayer.playSelected(); // Play user-selected or default alarm sound
  } // End triggerDestinationAlarmDemo

  /// Ensures notification service is initialized and permissions are granted
  /// This is a helper method called before any demo that shows notifications
  static Future<void> _ensureNotificationsReady() async { // Notification setup helper
    // Initialize notification service
    try {
      await NotificationService().initialize(); // Set up notification channels
      dev.log('Notification service initialized', name: 'DemoRouteSimulator'); // Log success
    } catch (e) { 
      dev.log('Notification init failed: $e', name: 'DemoRouteSimulator'); // Log failure
    }
    
    // Check and request notification permission
    final status = await Permission.notification.status; // Get current permission status
    dev.log('Notification permission status: $status', name: 'DemoRouteSimulator'); // Log status
    if (!status.isGranted) { // If not granted
      final req = await Permission.notification.request(); // Request permission
      dev.log('Notification permission requested, result: $req', name: 'DemoRouteSimulator'); // Log result
    }
  } // End _ensureNotificationsReady

  /// Interpolates n points evenly between two coordinates
  /// This generates a straight-line route with evenly spaced waypoints
  /// Used to create a smooth demo journey path
  static List<LatLng> _interpolate(LatLng a, LatLng b, int n) { // Linear interpolation
    final List<LatLng> pts = []; // Result list
    for (int i = 0; i < n; i++) { // Generate n points
      final t = i / (n - 1); // Interpolation factor (0.0 to 1.0)
      // Linear interpolation formula: point = a + (b - a) * t
      pts.add(LatLng(
        a.latitude + (b.latitude - a.latitude) * t, // Interpolated latitude
        a.longitude + (b.longitude - a.longitude) * t, // Interpolated longitude
      )); // End LatLng
    } // End for
    return pts; // Return interpolated points
  } // End _interpolate

  /// Offsets a coordinate by a distance in meters
  /// This calculates a new lat/lng point offset from the original by specified meters
  /// Uses Mercator projection approximation (accurate enough for small distances)
  static LatLng _offsetMeters(LatLng p, {double dxMeters = 0, double dyMeters = 0}) { // Coordinate offset
    const double earth = 6378137.0; // Earth's radius in meters (WGS84 standard)
    // Calculate latitude offset (straightforward - meters to radians)
    final dLat = dyMeters / earth; // Latitude change in radians
    // Calculate longitude offset (accounts for latitude - longitude lines converge at poles)
    final dLng = dxMeters / (earth * math.cos(math.pi * p.latitude / 180.0)); // Longitude change in radians
    // Convert radians to degrees and apply to original coordinates
    final lat = p.latitude + dLat * 180.0 / math.pi; // New latitude
    final lng = p.longitude + dLng * 180.0 / math.pi; // New longitude
    return LatLng(lat, lng); // Return offset coordinate
  } // End _offsetMeters
} // End DemoRouteSimulator

/* File summary: demo_tools.dart provides testing and demonstration capabilities for GeoWake's tracking and alarm
   features without requiring actual travel. The DemoRouteSimulator class orchestrates simulated GPS journeys by
   generating interpolated route points and injecting them into the background service at 300ms intervals. The
   startDemoJourney method creates a ~1.2km route and simulates traveling it in ~18 seconds, triggering progress
   notifications and alarms as configured. Two additional methods (triggerTransferAlarmDemo and
   triggerDestinationAlarmDemo) allow testing alarm UI and sound independently. The class handles notification
   permissions, service initialization, and coordinates between foreground and background services. Geographic
   utilities (_interpolate and _offsetMeters) use basic Mercator projection math to generate realistic route
   geometry. All demo functions disable test mode flags to ensure real notifications are shown. This tool is
   critical for development, testing, and demonstrations without requiring physical movement. The injected positions
   include realistic metadata (speed, accuracy) to simulate authentic GPS behavior. */
