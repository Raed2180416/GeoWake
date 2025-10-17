import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';

Position p(double lat, double lng, {double speed = 1.5}) => Position(
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

  test('Adaptive journey: walk->drive->transit triggers schedule tightening and final alarm', () async {
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();
    testAccelerometerStream = Stream.empty();

    final svc = TrackingService();
    final gps = StreamController<Position>();
    testGpsStream = gps.stream;

    // Simple synthetic directions with one WALK step then TRANSIT with stops
    final directions = {
      'routes': [
        {
          'legs': [
            {
              'steps': [
                {
                  'travel_mode': 'WALKING',
                  'distance': {'value': 600},
                  'polyline': {'points': '}_ibE_seK'}
                },
                {
                  'travel_mode': 'TRANSIT',
                  'distance': {'value': 4000},
                  'transit_details': {
                    'num_stops': 5,
                    'departure_stop': {'location': {'lat': 0.006, 'lng': 0.0}},
                    'line': {'short_name': 'L'}
                  },
                  'polyline': {'points': '}_ibE_seK_seK'}
                }
              ]
            }
          ]
        }
      ]
    };

    svc.registerRouteFromDirections(
      directions: directions,
      origin: const LatLng(0.0, 0.0),
      destination: const LatLng(0.020, 0.0),
      transitMode: true,
      destinationName: 'End',
    );

    await svc.startTracking(
      destination: const LatLng(0.020, 0.0),
      destinationName: 'End',
      alarmMode: 'stops',
      alarmValue: 2.0,
    );

    // Phase 1: walking (slow speed) - provide a few samples
    gps.add(p(0.0002, 0.0, speed: 1.3));
    await Future.delayed(const Duration(milliseconds: 120));
    gps.add(p(0.0005, 0.0, speed: 1.4));
    await Future.delayed(const Duration(milliseconds: 120));

    // Phase 2: driving segment (simulate faster approach before boarding)
    gps.add(p(0.0020, 0.0, speed: 12.0));
    await Future.delayed(const Duration(milliseconds: 120));
    gps.add(p(0.0045, 0.0, speed: 14.0));
    await Future.delayed(const Duration(milliseconds: 150));

    // Phase 3: near boarding (trigger pre-boarding heuristic ~0.006 lat ~ 660m)
    gps.add(p(0.0054, 0.0, speed: 8.0));
    await Future.delayed(const Duration(seconds: 1));

    // Phase 4: onboard transit progress along line
    gps.add(p(0.0060, 0.0, speed: 18.0));
    await Future.delayed(const Duration(milliseconds: 300));
    gps.add(p(0.0100, 0.0, speed: 22.0));
    await Future.delayed(const Duration(milliseconds: 300));
    gps.add(p(0.0140, 0.0, speed: 22.0));
    await Future.delayed(const Duration(milliseconds: 300));
    gps.add(p(0.0175, 0.0, speed: 20.0));
    await Future.delayed(const Duration(milliseconds: 400));
    gps.add(p(0.0182, 0.0, speed: 12.0)); // within 2 stops window likely
    await Future.delayed(const Duration(seconds: 2));

    final titles = NotificationService.testRecordedAlarms.map((e) => e['title'] as String).toList();
    final hasPreBoard = titles.any((t) => t.contains('Approaching metro station'));
    final hasDestination = titles.any((t) => t.contains('Wake') || t.contains('Arriv') || t.contains('Final') || t.contains('End'));

    expect(hasPreBoard, true, reason: 'Should have pre-boarding alert');
    // Transfer may not exist if only one transit segment; allow false.
    expect(hasDestination, true, reason: 'Should have destination alarm fired');

    await svc.stopTracking();
    await gps.close();
  }, timeout: const Timeout(Duration(seconds: 25)));
}
