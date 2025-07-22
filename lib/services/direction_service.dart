import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // Newly added import
import 'polyline_decoder.dart';
import 'polyline_simplifier.dart';

class DirectionService {
  final String apiKey;
  Map<String, dynamic>? _cachedDirections;
  DateTime? _lastFetchTime;

  // Tiered intervals for updating directions.
  final Duration farInterval = const Duration(minutes: 15);
  final Duration midInterval = const Duration(minutes: 7);
  final Duration nearInterval = const Duration(minutes: 3);

  DirectionService({required this.apiKey});

  /// Fetches directions using a tiered strategy.
  /// [transitMode] indicates if transit (metro) mode is requested.
  /// [isDistanceMode] and [threshold] are used for tiering.
  Future<Map<String, dynamic>> getDirections(
    double startLat,
    double startLng,
    double endLat,
    double endLng, {
    required bool isDistanceMode,
    required double threshold,
    required bool transitMode,
    bool forceRefresh = false,
  }) async {
    // Calculate the straight-line distance in meters.
    double straightDistance = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);

    // Determine the update interval.
    Duration updateInterval;
    if (isDistanceMode) {
      double thresholdMeters = threshold * 1000;
      if (straightDistance > 5 * thresholdMeters) {
        updateInterval = farInterval;
      } else if (straightDistance > 2 * thresholdMeters) {
        updateInterval = midInterval;
      } else {
        updateInterval = nearInterval;
      }
    } else {
      updateInterval = nearInterval;
    }

    // Return cached data if available and recent.
    if (!forceRefresh && _cachedDirections != null && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < updateInterval) {
        return _cachedDirections!;
      }
    }

    // Build the URL. For transit mode, use the transit parameter.
    String modeParam = transitMode ? 'transit&transit_mode=rail' : 'driving';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$startLat,$startLng'
      '&destination=$endLat,$endLng'
      '&mode=$modeParam'
      '&key=$apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception("Failed to fetch directions (HTTP ${response.statusCode}).");
    }
    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

    // Check for error statuses.
    if (jsonResponse['status'] == 'ZERO_RESULTS') {
      throw Exception("No feasible route found (ZERO_RESULTS).");
    }
    if (jsonResponse['status'] != 'OK') {
      throw Exception("No feasible route found: ${jsonResponse['status']}");
    }

    // --- New logic: Simplify & compress the overview polyline ---
    if (jsonResponse['routes'] != null && jsonResponse['routes'].isNotEmpty) {
      final route = jsonResponse['routes'][0];
      if (route['overview_polyline'] != null && route['overview_polyline']['points'] != null) {
        final String encodedPolyline = route['overview_polyline']['points'] as String;
        // Decode the polyline.
        List<LatLng> decodedPoints = decodePolyline(encodedPolyline);
        // Simplify with a tolerance of 10 meters.
        List<LatLng> simplifiedPoints = PolylineSimplifier.simplifyPolyline(decodedPoints, 10);
        // Compress the simplified polyline.
        String compressedPolyline = PolylineSimplifier.compressPolyline(simplifiedPoints);
        // Add the simplified compressed polyline to the response.
        route['simplified_polyline'] = compressedPolyline;
      }
    }
    // --- End new logic ---

    _cachedDirections = jsonResponse;
    _lastFetchTime = DateTime.now();
    return jsonResponse;
  }

  /// Builds segmented polylines from the directions response.
  /// For transit mode, groups segments by transit line; non-transit segments are drawn in blue.
  List<Polyline> buildSegmentedPolylines(Map<String, dynamic> directions, bool transitMode) {
    List<Polyline> polylines = [];
    if (directions['routes'] == null || directions['routes'].isEmpty) return polylines;

    Map<String, Color> transitColorMap = {};
    List<Color> transitColors = [Colors.red, Colors.green, Colors.orange, Colors.purple];
    int transitColorIndex = 0;

    for (var leg in directions['routes'][0]['legs']) {
      List<dynamic> steps = leg['steps'];
      if (steps.isEmpty) continue;

      List<LatLng> groupPoints = [];
      String currentGroupType;
      String? currentTransitLine;

      // Initialize first step
      var firstStep = steps[0];
      String firstMode = firstStep['travel_mode'];
      bool isFirstTransitMetro = false;
      if (firstMode == 'TRANSIT' && transitMode) {
        if (firstStep.containsKey('transit_details') && firstStep['transit_details'] != null) {
          var transitDetails = firstStep['transit_details'];
          var vehicleType = transitDetails['line']['vehicle']['type'];
          isFirstTransitMetro = vehicleType == 'SUBWAY' || vehicleType == 'HEAVY_RAIL';
          if (isFirstTransitMetro) {
            currentGroupType = "transit";
            currentTransitLine = transitDetails['line']['short_name'] ?? transitDetails['line']['name'];
          } else {
            currentGroupType = "non_transit";
            currentTransitLine = null;
          }
        } else {
          currentGroupType = "non_transit";
          currentTransitLine = null;
        }
      } else {
        currentGroupType = "non_transit";
        currentTransitLine = null;
      }
      // Decode, simplify, then add first step points.
      List<LatLng> rawPoints = decodePolyline(firstStep['polyline']['points']);
      List<LatLng> simplifiedPoints = PolylineSimplifier.simplifyPolyline(rawPoints, 10);
      groupPoints.addAll(simplifiedPoints);

      for (int i = 1; i < steps.length; i++) {
        var step = steps[i];
        String stepMode = step['travel_mode'];
        String stepGroupType = "non_transit";
        String? stepTransitLine;
        bool isStepTransitMetro = false;

        if (stepMode == 'TRANSIT' && transitMode) {
          if (step.containsKey('transit_details') && step['transit_details'] != null) {
            var transitDetails = step['transit_details'];
            var vehicleType = transitDetails['line']['vehicle']['type'];
            isStepTransitMetro = vehicleType == 'SUBWAY' || vehicleType == 'HEAVY_RAIL';
            if (isStepTransitMetro) {
              stepGroupType = "transit";
              stepTransitLine = transitDetails['line']['short_name'] ?? transitDetails['line']['name'];
            } else {
              stepGroupType = "non_transit";
              stepTransitLine = null;
            }
          }
        }

        bool sameGroup = false;
        if (currentGroupType == "non_transit" && stepGroupType == "non_transit") {
          sameGroup = true;
        } else if (currentGroupType == "transit" && stepGroupType == "transit") {
          sameGroup = (currentTransitLine == stepTransitLine);
        }

        if (sameGroup) {
          List<LatLng> rawStepPoints = decodePolyline(step['polyline']['points']);
          List<LatLng> simplifiedStepPoints = PolylineSimplifier.simplifyPolyline(rawStepPoints, 10);
          groupPoints.addAll(simplifiedStepPoints);
        } else {
          Color groupColor;
          if (currentGroupType == "non_transit") {
            groupColor = Colors.blue;
          } else {
            if (!transitColorMap.containsKey(currentTransitLine)) {
              transitColorMap[currentTransitLine!] = transitColors[transitColorIndex % transitColors.length];
              transitColorIndex++;
            }
            groupColor = transitColorMap[currentTransitLine]!;
          }

          polylines.add(Polyline(
            polylineId: PolylineId('group_${polylines.length}'),
            points: groupPoints,
            color: groupColor,
            width: 4,
          ));

          groupPoints = [];
          currentGroupType = stepGroupType;
          currentTransitLine = stepTransitLine;
          List<LatLng> rawStepPoints = decodePolyline(step['polyline']['points']);
          List<LatLng> simplifiedStepPoints = PolylineSimplifier.simplifyPolyline(rawStepPoints, 10);
          groupPoints.addAll(simplifiedStepPoints);
        }
      }

      if (groupPoints.isNotEmpty) {
        Color finalColor;
        if (currentGroupType == "non_transit") {
          finalColor = Colors.blue;
        } else {
          if (!transitColorMap.containsKey(currentTransitLine)) {
            transitColorMap[currentTransitLine!] = transitColors[transitColorIndex % transitColors.length];
            transitColorIndex++;
          }
          finalColor = transitColorMap[currentTransitLine]!;
        }

        polylines.add(Polyline(
          polylineId: PolylineId('group_${polylines.length}'),
          points: groupPoints,
          color: finalColor,
          width: 4,
        ));
      }
    }

    return polylines;
  }
}
