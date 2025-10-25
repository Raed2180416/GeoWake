import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';

Position p(double lat, double lng, {double speed = 10.0}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Stops hysteresis prevents single-pass jitter triggering', () async {
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();
    testAccelerometerStream = Stream.empty();

    // Build directions with a single transit step of 6 stops (~3000m) for simplicity
    final directions = {
      'routes': [
        {'legs': [{'steps': [
          {
            'travel_mode': 'TRANSIT',
            'distance': {'value': 3000},
            'transit_details': {
              'num_stops': 6,
              'departure_stop': {'location': {'lat': 0.0, 'lng': 0.0}},
              'line': {'short_name': 'L'}
            },
            'polyline': {'points': '}_ibE_seK'}
          }
        ]}]}
      ]
    };

    final svc = TrackingService();
    svc.registerRouteFromDirections(
      directions: directions,
      origin: const LatLng(0.0, 0.0),
      destination: const LatLng(0.030, 0.0),
      transitMode: true,
      destinationName: 'End',
    );

    final gps = StreamController<Position>();
    testGpsStream = gps.stream;

    // Alarm: 2 stops prior
    await svc.startTracking(
      destination: const LatLng(0.030, 0.0),
      destinationName: 'End',
      alarmMode: 'stops',
      alarmValue: 2.0,
    );

    // Approach progress such that remaining stops toggles just below threshold then back above.
    // We simulate by jumping forward near the end then slight regress (due to polyline simplification progress fallback).
    gps.add(p(0.020, 0.0)); // Maybe ~4 stops done -> remaining ~2 (first pass below)
    await Future.delayed(const Duration(milliseconds: 300));
    // Slightly earlier progress (simulate jitter reposition) -> remaining >2 -> hysteresis reset
    gps.add(p(0.019, 0.0));
    await Future.delayed(const Duration(milliseconds: 300));
    // Go below again twice to satisfy two-pass requirement
    gps.add(p(0.021, 0.0));
    await Future.delayed(const Duration(milliseconds: 250));
    gps.add(p(0.022, 0.0));
    await Future.delayed(const Duration(seconds: 2));

    // Ensure destination alarm fired exactly once and not earlier
    final destAlarms = NotificationService.testRecordedAlarms.where((a) => (a['allowContinueTracking'] != true)).toList();
    expect(destAlarms.length, 1, reason: 'Should trigger once after hysteresis satisfied');

    await svc.stopTracking();
    await gps.close();
  });
}
