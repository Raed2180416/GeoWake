import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';

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

  test('Pre-boarding heuristic scales with stops alarm but caps upper window', () async {
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();
    // Disable sensor fusion plugin calls
    testAccelerometerStream = Stream.empty();

    // Override heuristic for deterministic test (e.g., 500m per stop)
    TrackingService.stopsHeuristicMetersPerStop = 500.0;

    final origin = const LatLng(1.0000, 1.0000);
    final boarding = const LatLng(1.0050, 1.0000); // ~555m north (approx 111km per degree lat => 0.005 deg ~555m)
    final destination = const LatLng(1.0500, 1.0500);

    final directions = {
      'routes': [
        {
          'legs': [
            {
              'steps': [
                {
                  'travel_mode': 'WALKING',
                  'distance': {'value': 300.0},
                  'polyline': {'points': '}_ibE_seK'}
                },
                {
                  'travel_mode': 'TRANSIT',
                  'distance': {'value': 5000.0},
                  'transit_details': {
                    'departure_stop': {
                      'name': 'BoardStop',
                      'location': {'lat': boarding.latitude, 'lng': boarding.longitude}
                    },
                    'num_stops': 6,
                    'line': {'short_name': 'L1'}
                  },
                  'polyline': {'points': '}_ibE_seK_seK'}
                }
              ]
            }
          ],
          'overview_polyline': {'points': '}_ibE_seK_seK'}
        }
      ]
    };

    final svc = TrackingService();
    svc.registerRouteFromDirections(
      directions: directions,
      origin: origin,
      destination: destination,
      transitMode: true,
      destinationName: 'Dest',
    );

    final gps = StreamController<Position>();
    testGpsStream = gps.stream;

    // Alarm value 4 stops -> window = 4 * 500 = 2000m but will be capped to 1500m by implementation
    await svc.startTracking(
      destination: destination,
      destinationName: 'Dest',
      alarmMode: 'stops',
      alarmValue: 4.0,
    );

  // Compute helper offsets (approx 1 deg latitude ~ 111000 m)
  double offMeters(double meters) => meters / 111000.0;
  final cap = 1500.0; // expected cap
  final outsideLat = boarding.latitude - offMeters(cap + 100); // just outside cap
  final midLat = boarding.latitude - offMeters(cap - 200); // inside cap but still far (~1300m)
  final triggerLat = boarding.latitude - offMeters(1000); // ~1000m away

  gps.add(p(outsideLat, 1.0000));
  await Future.delayed(const Duration(milliseconds: 300));
  expect(NotificationService.testRecordedAlarms.isEmpty, true, reason: 'No alarm outside cap window');

  gps.add(p(midLat, 1.0000));
  await Future.delayed(const Duration(seconds: 2));
  final preList = NotificationService.testRecordedAlarms.where((a) => (a['title'] as String).contains('Approaching metro station')).toList();
  final firstCount = preList.length;
  expect(firstCount, 1, reason: 'Pre-boarding should fire upon entering heuristic window');

  // Closer sample (still inside window) should not fire again
  gps.add(p(triggerLat, 1.0000));
  await Future.delayed(const Duration(milliseconds: 500));
  final preList2 = NotificationService.testRecordedAlarms.where((a) => (a['title'] as String).contains('Approaching metro station')).toList();
  expect(preList2.length, firstCount, reason: 'No duplicate pre-boarding alert');

  // Additional closer sample should not double-fire (already validated above)

    await svc.stopTracking();
    await gps.close();
    // Reset heuristic default to avoid side-effects on other tests
    TrackingService.stopsHeuristicMetersPerStop = 550.0;
  });
}
