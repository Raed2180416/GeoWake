import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/deviation_detection.dart';
import 'package:geowake2/models/route_models.dart';

void main() {
  group('Deviation Detection Integration', () {
    // Create a dummy route using the actual RouteModel.
    // This route is defined as a short straight line.
    final dummyRoute = RouteModel(
      polylineEncoded: "dummy", // Dummy encoded polyline string.
      polylineDecoded: [
        LatLng(37.4219999, -122.0840575),
        LatLng(37.4225, -122.0840),
      ],
      timestamp: DateTime.now(),
      initialETA: 1000.0, // in seconds.
      currentETA: 1000.0, // in seconds.
      distance: 500.0,    // in meters.
      travelMode: "METRO",
      isActive: true,
      routeId: "test_route_001",
      originalResponse: {},
      transitSwitches: [],
    );

    test('returns false when current location is on the route', () {
      // Choose a point on the line.
      LatLng currentLocation = LatLng(37.4222, -122.08402);
      bool deviated = isDeviationExceeded(currentLocation, dummyRoute, false);
      expect(deviated, isFalse);
    });

    test('returns true when current location is off the route', () {
      // Choose a point far from the route (more than 600 m away).
      LatLng currentLocation = LatLng(37.4300, -122.0800);
      bool deviated = isDeviationExceeded(currentLocation, dummyRoute, false);
      expect(deviated, isTrue);
    });
  });
}
