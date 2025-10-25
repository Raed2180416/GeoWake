// Annotated copy of lib/models/route_models.dart
// Purpose: Core data models for route representation and transit switching.
// This file defines the fundamental data structures used throughout the app for route management.

import 'package:google_maps_flutter/google_maps_flutter.dart'; // Google Maps Flutter plugin - provides LatLng class and map widget

// ═══════════════════════════════════════════════════════════════════════════
// TRANSIT SWITCH MODEL
// ═══════════════════════════════════════════════════════════════════════════
/// Represents a transit switch (for metro mode).
// This class models a point where the user must change transportation modes,
// such as transferring between metro lines or switching from bus to walking.
class TransitSwitch { // Data class for transit transfer points
  // Immutable value object - all fields are final (cannot be changed after creation)
  
  final LatLng location; // Geographic coordinates of the transfer point
  // LatLng is from google_maps_flutter: contains latitude and longitude as doubles
  // This is where on the map the user needs to make the transfer
  // Example: the exact station platform or bus stop location
  
  final String fromMode; // Transportation mode the user is switching FROM
  // Examples: "WALKING", "SUBWAY", "BUS", "TRAIN"
  // Matches Google Directions API travel mode strings
  // Lowercase versions might also be used depending on API response parsing
  
  final String toMode; // Transportation mode the user is switching TO
  // Examples: "WALKING", "SUBWAY", "BUS", "TRAIN"
  // The mode the user will use after completing this transfer
  
  final double estimatedTime; // in seconds
  // How long this transfer is expected to take
  // Includes walking time between platforms, waiting time, etc.
  // Used for ETA calculations and alarm timing
  // Stored as double for precision (can include fractional seconds)

  TransitSwitch({ // Constructor - creates a new TransitSwitch instance
    required this.location, // Required: must provide transfer location
    required this.fromMode, // Required: must specify source mode
    required this.toMode, // Required: must specify destination mode
    required this.estimatedTime, // Required: must provide time estimate
  }); // End constructor
  // All fields are required - TransitSwitch is invalid without complete information
  // No default values because each field is critical for transfer alarm logic
} // End TransitSwitch class
// Block summary: TransitSwitch models a single transfer point in a multi-modal route.
// Used primarily for metro/transit routes where user must change vehicles.
// Contains all information needed to trigger transfer alarms at the right time and place.

// ═══════════════════════════════════════════════════════════════════════════
// ROUTE MODEL
// ═══════════════════════════════════════════════════════════════════════════
/// Represents a complete route with necessary metadata.
// This is the core data structure for routes in GeoWake. Every route the user
// creates or activates is represented by a RouteModel instance.
class RouteModel { // Data class for complete route information
  // Mutable state object - some fields can change during tracking (ETA, isActive)
  
  final String polylineEncoded; // Encoded polyline string from Google Directions API
  // Polyline encoding is a compressed format that represents a path as a single string
  // Example: "a~l~Fjk~uOwHJy@P" represents a series of lat/lng coordinates
  // This is the format returned by Google Directions API and stored in cache
  // More compact than storing raw coordinates, saving memory and storage space
  
  final List<LatLng> polylineDecoded; // Decoded polyline - actual coordinate points
  // Array of geographic points that define the route path
  // Decoded from polylineEncoded using polyline_decoder service
  // Used for:
  //   - Drawing route on map
  //   - Snap-to-route calculations
  //   - Distance-along-route measurements
  //   - Deviation detection
  // Typically contains 50-500 points depending on route complexity and distance
  
  final DateTime timestamp; // When this route was fetched/created
  // Used for:
  //   - Cache expiration (routes older than X hours are considered stale)
  //   - Sorting routes (show most recent first)
  //   - Debugging (when did we last update this route?)
  // Stored in UTC to avoid timezone issues
  
  double initialETA; // in seconds
  // Original estimated time of arrival when route was first created
  // Baseline for comparison - how much has ETA changed during journey?
  // Not final because it can be updated if route is refetched
  // Stored in seconds (not Duration) for easier arithmetic and API compatibility
  
  double currentETA; // updated ETA
  // Current estimated time to destination
  // Updated periodically during tracking based on:
  //   - Actual progress along route
  //   - Current speed
  //   - Traffic conditions (if route is refreshed)
  // This is what drives the alarm trigger - when currentETA < alarmValue, fire alarm
  // Mutable - changes every few seconds during active tracking
  
  final double distance; // in meters
  // Total route distance from start to destination
  // Used for:
  //   - Displaying distance to user
  //   - Calculating progress percentage
  //   - Distance-based alarms (wake up when 500m from destination)
  // Always in meters for consistency (converted to km/mi for display)
  
  final String travelMode; // "DRIVING", "TRANSIT", etc.
  // Transportation mode for this route
  // Matches Google Directions API travel modes:
  //   - "DRIVING": car
  //   - "WALKING": on foot
  //   - "BICYCLING": bicycle
  //   - "TRANSIT": public transportation (bus, train, metro)
  // Affects:
  //   - Which API parameters are used for directions
  //   - How deviation is calculated (different thresholds per mode)
  //   - Which icons are shown in UI
  
  bool isActive; // Whether this route is currently being tracked
  // true = user is actively tracking this route (location monitoring is on)
  // false = route is saved but not currently tracking
  // Only one route can be active at a time (enforced by ActiveRouteManager)
  // Mutable - changes when user starts/stops tracking
  
  final String routeId; // unique identifier
  // UUID or hash that uniquely identifies this route
  // Used for:
  //   - Cache lookups (avoid fetching duplicate routes)
  //   - Route registry management
  //   - Identifying which route triggered an alarm
  // Format: typically "origin_lat,origin_lng_dest_lat,dest_lng_mode" or UUID
  
  final Map<String, dynamic> originalResponse; // store full API response
  // Complete raw JSON response from Google Directions API
  // Stored for debugging and potential future feature extraction
  // Contains data we don't currently parse but might need later:
  //   - Turn-by-turn instructions
  //   - Street names
  //   - Traffic information
  //   - Alternative routes
  // Stored as dynamic Map to accommodate API changes without code updates
  
  final List<TransitSwitch> transitSwitches; // for metro mode
  // Array of transfer points where user must change vehicles
  // Empty for non-transit routes (driving, walking, bicycling)
  // For transit routes, contains one TransitSwitch per transfer
  // Example: Metro route with 2 transfers = list of 2 TransitSwitch objects
  // Used to trigger transfer alarms ("Change trains at next stop")
  // Default value is empty list (const []) for non-transit routes

  RouteModel({ // Constructor - creates a new RouteModel instance
    required this.polylineEncoded, // Required: must have encoded polyline from API
    required this.polylineDecoded, // Required: must have decoded points for map drawing
    required this.timestamp, // Required: must know when route was created
    required this.initialETA, // Required: must have initial time estimate
    required this.currentETA, // Required: must have current time estimate
    required this.distance, // Required: must know route distance
    required this.travelMode, // Required: must specify transportation mode
    this.isActive = false, // Optional: defaults to inactive (route saved but not tracking)
    // New routes start inactive - user must explicitly start tracking
    required this.routeId, // Required: must have unique identifier
    required this.originalResponse, // Required: must store full API response
    this.transitSwitches = const [], // Optional: defaults to no transfers (most routes are single-mode)
  }); // End constructor
  // Most fields are required because RouteModel is invalid without complete route data
  // Only isActive and transitSwitches have defaults since they're optional features
} // End RouteModel class
// Block summary: RouteModel is the central data structure for route representation.
// Contains all information needed to:
//   - Display route on map (polylineDecoded)
//   - Calculate progress and ETA (currentETA, distance)
//   - Trigger alarms (currentETA, transitSwitches)
//   - Cache routes (routeId, timestamp)
//   - Track active journey (isActive)
//   - Handle multi-modal transit (transitSwitches)
// Mutable fields (currentETA, isActive) change during tracking.
// Immutable fields represent the route definition and don't change.

/* ═══════════════════════════════════════════════════════════════════════════
   FILE SUMMARY: route_models.dart - Core Route Data Structures
   ═══════════════════════════════════════════════════════════════════════════
   
   This file defines the fundamental data models used for route representation
   throughout the GeoWake application. These models are the "lingua franca" of
   the app - every service that deals with routes uses these structures.
   
   TWO PRIMARY MODELS:
   
   1. TransitSwitch:
      - Represents a single transfer point in multi-modal routes
      - Contains location, modes (from/to), and estimated transfer time
      - Used for triggering transfer alarms in metro/bus routes
      - Example: "Change from Red Line to Blue Line at Central Station"
   
   2. RouteModel:
      - Represents a complete route with all metadata
      - Stores both encoded (compact) and decoded (usable) polyline
      - Tracks both initial and current ETA (for progress tracking)
      - Contains travel mode, distance, and unique ID
      - Stores original API response for debugging/future features
      - Includes array of TransitSwitch for multi-modal routes
      - Mutable fields: currentETA (updated during tracking), isActive (tracking state)
   
   KEY DESIGN DECISIONS:
   
   - Immutability: Most fields are final (immutable) - route data doesn't change
   - Dual Polyline Storage: Both encoded (compact) and decoded (usable) formats
     - Encoded: Efficient for storage and caching
     - Decoded: Ready for map rendering and calculations
   - ETA Separation: initialETA vs currentETA allows progress tracking
   - Original Response: Full API response stored for debugging and extensibility
   - Seconds for Time: Using double seconds instead of Duration for API compatibility
   - Meters for Distance: Consistent unit system (converted to km/mi for display)
   
   CONNECTIONS TO OTHER FILES:
   
   - services/direction_service.dart: Creates RouteModel from Google API responses
   - services/route_cache.dart: Stores/retrieves RouteModel by routeId
   - services/route_registry.dart: Manages collection of RouteModel instances
   - services/active_route_manager.dart: Tracks currently active RouteModel
   - services/snap_to_route.dart: Uses polylineDecoded for position projection
   - services/eta_utils.dart: Updates currentETA based on progress
   - services/deviation_detection.dart: Uses polylineDecoded to detect off-route
   - services/metro_stop_service.dart: Uses transitSwitches for transfer alarms
   - screens/maptracking.dart: Renders polylineDecoded as route on map
   - test/*: Many tests create mock RouteModel instances
   
   DATA FLOW:
   
   1. User requests route → DirectionService fetches from API
   2. DirectionService decodes polyline, creates RouteModel
   3. RouteModel stored in RouteCache by routeId
   4. RouteModel added to RouteRegistry
   5. User starts tracking → RouteModel.isActive = true
   6. ActiveRouteManager references active RouteModel
   7. TrackingService updates RouteModel.currentETA periodically
   8. ETA reaches alarm threshold → alarm triggered
   9. For transit: MetroStopService uses transitSwitches for transfer alarms
   
   POTENTIAL ISSUES / FUTURE ENHANCEMENTS:
   
   - No validation: RouteModel can be created with invalid data (negative ETA, etc.)
   - No immutability enforcement: Mutable fields could be modified incorrectly
   - Large originalResponse stored in memory: Could be offloaded to disk
   - TransitSwitch lacks validation: fromMode/toMode could be invalid strings
   - No serialization methods: Can't easily save/load from JSON or Hive
   - No equality/hashCode: Two identical routes won't be considered equal
   - No copy constructor: Hard to create modified versions
   - routeId format not standardized: Different services might generate different formats
   
   These models are intentionally simple - they're pure data classes without logic.
   All route manipulation logic lives in service classes that operate on these models.
   This separation keeps models clean and services focused.
*/
