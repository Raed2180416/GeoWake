// lib/services/deviation_detection.dart
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/models/route_models.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/log.dart';
import 'package:geowake2/services/geometry/segment_projection.dart';

/// A simple data class to store information about the closest point.
class PointInfo {
  final LatLng point;
  final int segmentIndex;
  final double distanceFromStart;

  PointInfo({
    required this.point,
    required this.segmentIndex,
    required this.distanceFromStart,
  });
}

/// Calculates the Haversine distance in meters between two [LatLng] points.
double calculateDistance(LatLng a, LatLng b) {
  return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
}

// Unified projector-based closest point search.
final Map<String, SegmentProjector> _projectorCache = {};
void clearProjectorCache() => _projectorCache.clear();

PointInfo findClosestPointOnRouteSegmented(LatLng currentLocation, RouteModel route) {
  final key = route.routeId.isNotEmpty ? route.routeId : route.timestamp.toIso8601String();
  final projector = _projectorCache.putIfAbsent(key, () => SegmentProjector(route.polylineDecoded));
  final res = projector.project(currentLocation);
  LatLng point;
  if (res.segmentIndex >= 0 && res.segmentIndex < route.polylineDecoded.length - 1) {
    final a = route.polylineDecoded[res.segmentIndex];
    final b = route.polylineDecoded[res.segmentIndex + 1];
    final segLen = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    double t;
    if (segLen <= 0) {
      t = 0;
    } else {
      final segStartMeters = projector.cumulativeDistances[res.segmentIndex];
      t = ((res.progressMeters - segStartMeters) / segLen).clamp(0.0, 1.0);
    }
    point = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  } else {
    point = currentLocation;
  }
  return PointInfo(point: point, segmentIndex: res.segmentIndex, distanceFromStart: res.progressMeters);
}


/// Determines the deviation threshold based on connectivity and environment.
/// For now, it returns a fixed base threshold—adapt this as needed.
double determineThreshold(bool isOffline, LatLng currentLocation, RouteModel route) {
  // Base threshold: 600m when online, 1500m when offline.
  double baseThreshold = isOffline ? 1500.0 : 600.0;

  // (Optional) Add adjustments based on factors such as urban density, road type, or speed.

  return baseThreshold;
}

/// Checks whether the current location deviates from the [activeRoute] beyond the acceptable threshold.
bool isDeviationExceeded(LatLng currentLocation, RouteModel activeRoute, bool isOffline) {
  final info = findClosestPointOnRouteSegmented(currentLocation, activeRoute);
  final deviationDistance = calculateDistance(currentLocation, info.point);
  final threshold = determineThreshold(isOffline, currentLocation, activeRoute);
  Log.d('Deviation', 'dev=$deviationDistance th=$threshold seg=${info.segmentIndex} prog=${info.distanceFromStart.toStringAsFixed(1)}');
  return deviationDistance > threshold;
}
