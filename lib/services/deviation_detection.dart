// lib/services/deviation_detection.dart
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/models/route_models.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

/// Iterates through the decoded polyline of a [RouteModel] to find the point closest to [currentLocation].
PointInfo findClosestPointOnRoute(LatLng currentLocation, RouteModel route) {
  double minDistance = double.infinity;
  LatLng closestPoint = currentLocation;
  int closestIndex = 0;
  double cumulativeDistance = 0;

  for (int i = 0; i < route.polylineDecoded.length; i++) {
    final point = route.polylineDecoded[i];
    final distance = calculateDistance(currentLocation, point);
    if (distance < minDistance) {
      minDistance = distance;
      closestPoint = point;
      closestIndex = i;
      // Approximate the distance from the start by summing up distances from the beginning to this point.
      cumulativeDistance = 0;
      for (int j = 0; j < i; j++) {
        cumulativeDistance += calculateDistance(route.polylineDecoded[j], route.polylineDecoded[j + 1]);
      }
    }
  }
  return PointInfo(point: closestPoint, segmentIndex: closestIndex, distanceFromStart: cumulativeDistance);
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
  final closest = findClosestPointOnRoute(currentLocation, activeRoute);
  final deviationDistance = calculateDistance(currentLocation, closest.point);
  final threshold = determineThreshold(isOffline, currentLocation, activeRoute);
  
  return deviationDistance > threshold;
}
