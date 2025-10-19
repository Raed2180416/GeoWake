// lib/models/route_models.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';

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
  }) : assert(estimatedTime >= 0 && estimatedTime.isFinite, 
              'estimatedTime must be >= 0 and finite, got: $estimatedTime'),
       assert(fromMode.isNotEmpty, 'fromMode cannot be empty'),
       assert(toMode.isNotEmpty, 'toMode cannot be empty');

  Map<String, dynamic> toJson() => {
    'location': {'lat': location.latitude, 'lng': location.longitude},
    'fromMode': fromMode,
    'toMode': toMode,
    'estimatedTime': estimatedTime,
  };

  factory TransitSwitch.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>;
    return TransitSwitch(
      location: LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      ),
      fromMode: json['fromMode'] as String,
      toMode: json['toMode'] as String,
      estimatedTime: (json['estimatedTime'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitSwitch &&
          runtimeType == other.runtimeType &&
          location.latitude == other.location.latitude &&
          location.longitude == other.location.longitude &&
          fromMode == other.fromMode &&
          toMode == other.toMode;

  @override
  int get hashCode => Object.hash(
    location.latitude,
    location.longitude,
    fromMode,
    toMode,
  );
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
  }) : 
    // CRITICAL INPUT VALIDATION
    assert(polylineEncoded.isNotEmpty, 'Encoded polyline cannot be empty'),
    assert(polylineDecoded.isNotEmpty, 'Decoded polyline must have at least one point'),
    assert(polylineDecoded.length >= 2, 'Route must have at least start and end points'),
    assert(initialETA >= 0 && initialETA.isFinite, 'initialETA must be >= 0 and finite, got: $initialETA'),
    assert(currentETA >= 0 && currentETA.isFinite, 'currentETA must be >= 0 and finite, got: $currentETA'),
    assert(distance >= 0 && distance.isFinite, 'distance must be >= 0 and finite, got: $distance'),
    assert(distance <= 40075000, 'distance cannot exceed Earth circumference (40,075 km), got: $distance meters'),
    assert(routeId.isNotEmpty, 'routeId cannot be empty'),
    assert(travelMode.isNotEmpty, 'travelMode cannot be empty');

  /// Create a copy of this route with updated fields
  RouteModel copyWith({
    String? polylineEncoded,
    List<LatLng>? polylineDecoded,
    DateTime? timestamp,
    double? initialETA,
    double? currentETA,
    double? distance,
    String? travelMode,
    bool? isActive,
    String? routeId,
    Map<String, dynamic>? originalResponse,
    List<TransitSwitch>? transitSwitches,
  }) {
    return RouteModel(
      polylineEncoded: polylineEncoded ?? this.polylineEncoded,
      polylineDecoded: polylineDecoded ?? this.polylineDecoded,
      timestamp: timestamp ?? this.timestamp,
      initialETA: initialETA ?? this.initialETA,
      currentETA: currentETA ?? this.currentETA,
      distance: distance ?? this.distance,
      travelMode: travelMode ?? this.travelMode,
      isActive: isActive ?? this.isActive,
      routeId: routeId ?? this.routeId,
      originalResponse: originalResponse ?? this.originalResponse,
      transitSwitches: transitSwitches ?? this.transitSwitches,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteModel &&
          runtimeType == other.runtimeType &&
          routeId == other.routeId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => routeId.hashCode ^ timestamp.hashCode;

  /// Convert route to JSON (without large originalResponse to save space)
  Map<String, dynamic> toJson() => {
    'polylineEncoded': polylineEncoded,
    'timestamp': timestamp.toIso8601String(),
    'initialETA': initialETA,
    'currentETA': currentETA,
    'distance': distance,
    'travelMode': travelMode,
    'isActive': isActive,
    'routeId': routeId,
    'transitSwitches': transitSwitches.map((t) => t.toJson()).toList(),
    // Note: originalResponse is intentionally excluded to reduce serialization size
  };

  /// Create route from JSON
  factory RouteModel.fromJson(Map<String, dynamic> json, {
    List<LatLng>? decodedPolyline,
    Map<String, dynamic>? originalResponse,
  }) {
    // If polyline not provided, decode it from encoded string
    List<LatLng> polyline = decodedPolyline ?? _decodePolyline(json['polylineEncoded'] as String);
    
    return RouteModel(
      polylineEncoded: json['polylineEncoded'] as String,
      polylineDecoded: polyline,
      timestamp: DateTime.parse(json['timestamp'] as String),
      initialETA: (json['initialETA'] as num).toDouble(),
      currentETA: (json['currentETA'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      travelMode: json['travelMode'] as String,
      isActive: json['isActive'] as bool? ?? false,
      routeId: json['routeId'] as String,
      originalResponse: originalResponse ?? {},
      transitSwitches: (json['transitSwitches'] as List?)
          ?.map((t) => TransitSwitch.fromJson(t as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  /// Simple polyline decoder (basic implementation)
  /// Note: In production, use a proper polyline decoding library
  static List<LatLng> _decodePolyline(String encoded) {
    // This is a placeholder - the actual decoder should be imported
    // from the existing polyline_decoder service in the codebase
    return [];
  }
}
