// lib/models/route_models.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a transit switch (for metro mode).
class TransitSwitch {
  final LatLng location;
  final String fromMode;
  final String toMode;
  final double estimatedTime; // in seconds

  TransitSwitch({
    required this.location,
    required this.fromMode,
    required this.toMode,
    required this.estimatedTime,
  });
}

/// Represents a complete route with necessary metadata.
class RouteModel {
  final String polylineEncoded;
  final List<LatLng> polylineDecoded;
  final DateTime timestamp;
  double initialETA;  // in seconds
  double currentETA;  // updated ETA
  final double distance;    // in meters
  final String travelMode;  // "DRIVING", "TRANSIT", etc.
  bool isActive;
  final String routeId;     // unique identifier
  final Map<String, dynamic> originalResponse; // store full API response
  final List<TransitSwitch> transitSwitches;  // for metro mode

  RouteModel({
    required this.polylineEncoded,
    required this.polylineDecoded,
    required this.timestamp,
    required this.initialETA,
    required this.currentETA,
    required this.distance,
    required this.travelMode,
    this.isActive = false,
    required this.routeId,
    required this.originalResponse,
    this.transitSwitches = const [],
  });
}
