// Annotated copy of lib/models/route_models.dart
// Purpose: Document core data structures for routes and transit switches used throughout the application.

// lib/models/route_models.dart
import 'package:google_maps_flutter/google_maps_flutter.dart'; // LatLng geographic coordinate type

/// Represents a transit switch point (for metro/public transit mode).
/// A transit switch occurs when the user must change from one transit line/mode to another.
/// For example: switching from Bus Line 42 to Metro Line 3 at Central Station.
class TransitSwitch { // Data model for transit transfer points
  final LatLng location; // Geographic coordinates of the transfer point (e.g., station location)
  final String fromMode; // Mode/line being left (e.g., "Bus 42", "Metro Red Line")
  final String toMode; // Mode/line being joined (e.g., "Metro 3", "Bus 15")
  final double estimatedTime; // Estimated time needed for the transfer in seconds (walking time, waiting time)

  TransitSwitch({ // Constructor requiring all fields
    required this.location, // Transfer location is mandatory
    required this.fromMode, // Must specify what transit is being left
    required this.toMode, // Must specify what transit is being joined
    required this.estimatedTime, // Transfer time must be specified for ETA calculations
  }); // End constructor
} // End TransitSwitch

/// Represents a complete route with all necessary metadata for tracking and navigation.
/// This is the primary data structure used throughout the app for active routes.
/// Contains both the route geometry (polyline) and metadata (ETA, distance, mode, etc.).
class RouteModel { // Core route data structure
  final String polylineEncoded; // Google-encoded polyline string (compressed route geometry)
  final List<LatLng> polylineDecoded; // Decoded list of lat/lng points forming the route path
  final DateTime timestamp; // When this route was fetched/created (for cache expiration)
  double initialETA;  // Initial estimated time of arrival in seconds (from API at fetch time)
  double currentETA;  // Updated/recalculated ETA in seconds (adjusted during active tracking)
  final double distance;    // Total route distance in meters
  final String travelMode;  // Travel mode: "DRIVING", "TRANSIT", "WALKING", "BICYCLING"
  bool isActive; // Whether this route is currently being tracked (only one can be active)
  final String routeId;     // Unique identifier for this route (used in cache keys)
  final Map<String, dynamic> originalResponse; // Full API response from server (preserved for debugging/reprocessing)
  final List<TransitSwitch> transitSwitches;  // List of transfer points for transit mode (empty for driving/walking)

  RouteModel({ // Constructor with both required and optional parameters
    required this.polylineEncoded, // Must have encoded polyline from API
    required this.polylineDecoded, // Must have decoded points for distance calculations
    required this.timestamp, // Timestamp required for cache management
    required this.initialETA, // Initial ETA must be provided from API
    required this.currentETA, // Current ETA initialized to same as initial
    required this.distance, // Total distance required for progress calculations
    required this.travelMode, // Mode required to determine tracking strategy
    this.isActive = false, // Routes start inactive by default
    required this.routeId, // Unique ID required for route registry/cache
    required this.originalResponse, // Full response preserved for metadata access
    this.transitSwitches = const [], // Empty list by default (only populated for transit routes)
  }); // End constructor
} // End RouteModel

/* File summary: route_models.dart defines the core data structures for route representation and transit
   navigation. TransitSwitch captures transfer points in multi-modal journeys (e.g., switching from bus to metro),
   including location, modes, and transfer time for accurate ETA calculations. RouteModel is the central route
   representation, containing both the geometric path (encoded and decoded polylines) and metadata (ETA, distance,
   mode, etc.). The model supports mutable state (isActive, currentETA) for tracking updates while preserving
   immutable source data (originalResponse, initialETA). The routeId enables cache key generation and registry
   lookups. Transit mode is fully supported through transitSwitches list, enabling alarm triggers at transfer points.
   All routes store their fetch timestamp for cache expiration logic. */
