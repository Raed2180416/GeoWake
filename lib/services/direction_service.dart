
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'polyline_decoder.dart';
import 'polyline_simplifier.dart';
import 'package:geowake2/services/api_client.dart'; // ADD THIS IMPORT
import 'package:geowake2/services/route_cache.dart';
import 'dart:convert' show utf8;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:developer' as dev;

class DirectionService {
  final ApiClient _apiClient = ApiClient.instance;
  Map<String, dynamic>? _cachedDirections;
  DateTime? _lastFetchTime;
  // In-memory cache for decode+simplify keyed by hash 'len:md5' of polyline+tol
  final Map<String, List<LatLng>> _polylineSimplifyCache = {};

  // Tiered intervals for updating directions.
  final Duration farInterval = const Duration(minutes: 15);
  final Duration midInterval = const Duration(minutes: 7);
  final Duration nearInterval = const Duration(minutes: 3);

  DirectionService();

  /// Fetches directions using a tiered strategy through your secure API.
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
    // Ensure ApiClient is ready on first run (bootstrap late init may still be running)
    try {
      await _apiClient.initialize();
    } catch (e) {
      Log.w('DirectionService', 'API client initialization warning (may already be initialized): $e');
    }
    // L2 persistent cache check (Hive)
    final origin = LatLng(startLat, startLng);
    final dest = LatLng(endLat, endLng);
    final mode = transitMode ? 'transit' : 'driving';
    if (!forceRefresh) {
      final cached = await RouteCache.get(
        origin: origin,
        destination: dest,
        mode: mode,
        transitVariant: transitMode ? 'rail' : null,
      );
      if (cached != null) {
        dev.log('Using RouteCache entry for $mode', name: 'DirectionService');
        _cachedDirections = cached.directions;
        _lastFetchTime = cached.timestamp;
      }
    }
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

    // Return in-memory cached data if available and recent.
    if (!forceRefresh && _cachedDirections != null && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < updateInterval) {
        return _cachedDirections!;
      }
    }

    try {
      // REPLACE THE DIRECT HTTP CALL WITH API CLIENT
      final resp = await _apiClient.getDirections(
        origin: '$startLat,$startLng',
        destination: '$endLat,$endLng',
        mode: transitMode ? 'transit' : 'driving',
        transitMode: transitMode ? 'rail' : null,
      );
      // Do not overwrite ApiClient.lastDirectionsBody here; ApiClient records the request payload itself in test mode
      // Normalize shape: backend may return top-level or nested under 'data'
      Map<String, dynamic> directions = resp;
      if (directions['routes'] == null && directions['data'] is Map<String, dynamic>) {
        directions = (directions['data'] as Map<String, dynamic>);
      }
      final routes = (directions['routes'] as List?) ?? const [];
      final status = directions['status'] as String?; // optional
      if (routes.isEmpty || (status != null && status != 'OK')) {
        final err = directions['error_message'] ?? status ?? 'NO_STATUS';
        // If transit failed, try a single fallback to driving to avoid user-facing errors
        if (transitMode) {
          dev.log('Transit directions failed ($err). Falling back to driving…', name: 'DirectionService');
          final resp2 = await _apiClient.getDirections(
            origin: '$startLat,$startLng',
            destination: '$endLat,$endLng',
            mode: 'driving',
          );
          Map<String, dynamic> d2 = resp2;
          if (d2['routes'] == null && d2['data'] is Map<String, dynamic>) {
            d2 = (d2['data'] as Map<String, dynamic>);
          }
          final routes2 = (d2['routes'] as List?) ?? const [];
          final status2 = d2['status'] as String?;
          if (routes2.isEmpty || (status2 != null && status2 != 'OK')) {
            throw Exception('No feasible route (transit and driving fallback failed)');
          }
          directions = d2; // use fallback
        } else {
          throw Exception('No feasible route found (routes=${routes.length} status=$status err=$err)');
        }
      }

      // --- Simplify & compress the overview polyline ---
      String? simplifiedCompressed;
      if (directions['routes'] != null && directions['routes'].isNotEmpty) {
        final route = directions['routes'][0];
        if (route['overview_polyline'] != null && route['overview_polyline']['points'] != null) {
          final String encodedPolyline = route['overview_polyline']['points'] as String;
          // Decode + simplify with small in-memory cache
          final simplifiedPoints = _decodeAndSimplifyCached(encodedPolyline, 10);
          // Compress the simplified polyline.
          String compressedPolyline = PolylineSimplifier.compressPolyline(simplifiedPoints);
          // Add the simplified compressed polyline to the response.
          route['simplified_polyline'] = compressedPolyline;
          simplifiedCompressed = compressedPolyline;
        }
      }

      _cachedDirections = directions;
      _lastFetchTime = DateTime.now();

      // Persist to RouteCache (L2)
      try {
        final key = RouteCache.makeKey(
          origin: origin,
          destination: dest,
          mode: mode,
          transitVariant: transitMode ? 'rail' : null,
        );
        await RouteCache.put(RouteCacheEntry(
          key: key,
          directions: directions,
          timestamp: _lastFetchTime!,
          origin: origin,
          destination: dest,
          mode: mode,
          simplifiedCompressedPolyline: simplifiedCompressed,
        ));
      } catch (e) {
        dev.log('Failed to persist route cache: $e', name: 'DirectionService');
      }
  return directions;

    } catch (e) {
      dev.log("Error fetching directions via API client: $e", name: "DirectionService");
      throw Exception("Failed to fetch directions: $e");
    }
  }

  // Rest of the class remains the same...
  List<Polyline> buildSegmentedPolylines(Map<String, dynamic> directions, bool transitMode) {
    List<Polyline> polylines = [];
    if (directions['routes'] == null || directions['routes'].isEmpty) return polylines;

  Map<String, Color> transitColorMap = {};
  // Only use green and purple for metro transit lines; deterministic assignment
  final List<Color> transitColors = [Colors.green, Colors.purple];
  int transitColorIndex = 0;

    for (var leg in directions['routes'][0]['legs']) {
      List<dynamic> steps = leg['steps'];
      if (steps.isEmpty) continue;

  List<LatLng> groupPoints = [];
  String currentGroupType;
  // non_transit subtype to distinguish DRIVING vs WALKING for styling
  String? currentNonTransitMode; // 'DRIVING' | 'WALKING' | null when transit
      String? currentTransitLine;

      // Initialize first step
      var firstStep = steps[0];
      String firstMode = firstStep['travel_mode'];
  bool isFirstTransitMetro = false;
  if (firstMode == 'TRANSIT' && transitMode) {
        if (firstStep.containsKey('transit_details') && firstStep['transit_details'] != null) {
          var transitDetails = firstStep['transit_details'];
          var vehicleType = transitDetails['line']['vehicle']['type'];
          isFirstTransitMetro = vehicleType == 'SUBWAY' || vehicleType == 'HEAVY_RAIL' || vehicleType == 'RAIL';
          if (isFirstTransitMetro) {
            currentGroupType = "transit";
            currentTransitLine = transitDetails['line']['short_name'] ?? transitDetails['line']['name'];
          } else {
            currentGroupType = "non_transit";
            currentTransitLine = null;
            currentNonTransitMode = firstMode;
          }
        } else {
          currentGroupType = "non_transit";
          currentTransitLine = null;
          currentNonTransitMode = firstMode;
        }
      } else {
        currentGroupType = "non_transit";
        currentTransitLine = null;
        currentNonTransitMode = firstMode;
      }
      // Decode, simplify, then add first step points (guard missing polyline).
      try {
        final ptsStr = (firstStep['polyline'] is Map) ? firstStep['polyline']['points'] as String? : null;
        if (ptsStr != null) {
          List<LatLng> simplifiedPoints = _decodeAndSimplifyCached(ptsStr, 10);
          groupPoints.addAll(simplifiedPoints);
        }
      } catch (_) {}

      for (int i = 1; i < steps.length; i++) {
        var step = steps[i];
        String stepMode = step['travel_mode'];
  String stepGroupType = "non_transit";
        String? stepTransitLine;
  bool isStepTransitMetro = false;
  String? stepNonTransitMode; // track DRIVING vs WALKING

        if (stepMode == 'TRANSIT' && transitMode) {
          if (step.containsKey('transit_details') && step['transit_details'] != null) {
            var transitDetails = step['transit_details'];
            var vehicleType = transitDetails['line']['vehicle']['type'];
            isStepTransitMetro = vehicleType == 'SUBWAY' || vehicleType == 'HEAVY_RAIL' || vehicleType == 'RAIL';
            if (isStepTransitMetro) {
              stepGroupType = "transit";
              stepTransitLine = transitDetails['line']['short_name'] ?? transitDetails['line']['name'];
            } else {
                stepGroupType = "non_transit";
                stepTransitLine = null;
                stepNonTransitMode = stepMode; // could be BUS etc., but treat as non_transit
            }
          }
          } else {
            // Non-transit: remember the specific mode for styling (DRIVING/WALKING)
            stepNonTransitMode = stepMode;
        }

        bool sameGroup = false;
          if (currentGroupType == "non_transit" && stepGroupType == "non_transit") {
            // keep grouping only if same non-transit mode to allow different styling
            sameGroup = (currentNonTransitMode == stepNonTransitMode);
        } else if (currentGroupType == "transit" && stepGroupType == "transit") {
          sameGroup = (currentTransitLine == stepTransitLine);
        }

        if (sameGroup) {
          try {
            final ptsStr = (step['polyline'] is Map) ? step['polyline']['points'] as String? : null;
            if (ptsStr != null) {
              List<LatLng> simplifiedStepPoints = _decodeAndSimplifyCached(ptsStr, 10);
              groupPoints.addAll(simplifiedStepPoints);
            }
          } catch (_) {}
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

          // Determine walking dashed pattern; driving solid
          List<PatternItem>? pattern;
          if (currentGroupType == 'non_transit' && currentNonTransitMode == 'WALKING') {
            pattern = [PatternItem.dash(20), PatternItem.gap(12)];
          }

          polylines.add(Polyline(
            polylineId: PolylineId('group_${polylines.length}'),
            points: groupPoints,
            color: groupColor,
            width: 5,
            patterns: pattern ?? const <PatternItem>[],
            zIndex: currentGroupType == 'transit' ? 3 : 2,
          ));

          groupPoints = [];
          currentGroupType = stepGroupType;
          currentTransitLine = stepTransitLine;
          currentNonTransitMode = stepNonTransitMode;
          // Use cached decode+simplify for consistency
          try {
            final ptsStr = (step['polyline'] is Map) ? step['polyline']['points'] as String? : null;
            if (ptsStr != null) {
              List<LatLng> simplifiedStepPoints = _decodeAndSimplifyCached(ptsStr, 10);
              groupPoints.addAll(simplifiedStepPoints);
            }
          } catch (_) {}
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

        // Walking dashed at tail too
        List<PatternItem>? pattern;
        if (currentGroupType == 'non_transit' && currentNonTransitMode == 'WALKING') {
          pattern = [PatternItem.dash(20), PatternItem.gap(12)];
        }

        polylines.add(Polyline(
          polylineId: PolylineId('group_${polylines.length}'),
          points: groupPoints,
          color: finalColor,
          width: 5,
          patterns: pattern ?? const <PatternItem>[],
          zIndex: currentGroupType == 'transit' ? 3 : 2,
        ));
      }
    }
    // Fallback: if no segmented polylines built (e.g., missing step polylines), use overview polyline
    if (polylines.isEmpty) {
      try {
        final route = directions['routes'][0];
        final ov = (route['overview_polyline'] as Map?)?['points'] as String?;
        if (ov != null) {
          final decoded = _decodeAndSimplifyCached(ov, 10);
            polylines.add(Polyline(
              polylineId: const PolylineId('overview_fallback'),
              points: decoded,
              color: transitMode ? Colors.green : Colors.blue,
              width: 5,
            ));
        }
      } catch (_) {}
    }
    return polylines;
  }

  // Decode an encoded polyline and simplify it with caching keyed by md5 of input+tol
  List<LatLng> _decodeAndSimplifyCached(String encoded, double toleranceMeters) {
    final key = _polyKey(encoded, toleranceMeters);
    final cached = _polylineSimplifyCache[key];
    if (cached != null) return cached;
    final decoded = decodePolyline(encoded);
    final simplified = PolylineSimplifier.simplifyPolyline(decoded, toleranceMeters);
    _polylineSimplifyCache[key] = simplified;
    return simplified;
  }

  String _polyKey(String encoded, double tol) {
    final bytes = utf8.encode('$tol|' + encoded);
    final digest = crypto.md5.convert(bytes).toString();
    return '${encoded.length}:$digest';
  }
}