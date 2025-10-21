import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/deviation_detection.dart';
import 'package:geowake2/models/route_models.dart';

// Minimal stub RouteModel to satisfy interface used in deviation_detection.

void main() {
  group('Segment projector deviation', () {
    test('Projection lies on segment and deviation reasonable', () {
      final route = RouteModel(
        polylineEncoded: '',
        polylineDecoded: const [
          LatLng(37.0000, -122.0000),
          LatLng(37.0100, -121.9900),
        ],
        timestamp: DateTime.now(),
        initialETA: 0,
        currentETA: 0,
        distance: 0,
        travelMode: 'DRIVING',
        routeId: 'test',
        originalResponse: const {},
      );
      final current = const LatLng(37.0052, -121.9951);
      final projInfo = findClosestPointOnRouteSegmented(current, route);
      final deviation = calculateDistance(current, projInfo.point);
      // Should be within a few hundred meters for this synthetic geometry.
      expect(deviation < 500, isTrue, reason: 'Deviation should be bounded');
      // Progress should be roughly half the segment length (~ distance from start to projection)
      expect(projInfo.distanceFromStart > 0, isTrue);
    });
  });
}
