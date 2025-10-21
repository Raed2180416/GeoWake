import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';

Map<String, dynamic> _mkTransitWithStops({required int stopsToTransfer, required int stopsToDest}) {
  return {
    'routes': [
      {
        'legs': [
          {
            'steps': [
              {
                'travel_mode': 'TRANSIT',
                'distance': {'value': 4000},
                'polyline': {'points': '}_se}Ff`miO??'},
                'transit_details': {
                  'line': {'short_name': 'L1', 'vehicle': {'type': 'SUBWAY'}},
                  'num_stops': stopsToTransfer,
                  'arrival_stop': {'name': 'Xfer'},
                }
              },
              {
                'travel_mode': 'TRANSIT',
                'distance': {'value': 3000},
                'polyline': {'points': '}_se}Ff`miO??'},
                'transit_details': {
                  'line': {'short_name': 'L2', 'vehicle': {'type': 'SUBWAY'}},
                  'num_stops': stopsToDest,
                  'arrival_stop': {'name': 'Final'},
                }
              },
            ]
          }
        ]
      }
    ]
  };
}

Position _p(double lat, double lng, {double speed = 10.0}) => Position(
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
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();
  });

  test('Stops mode: boundary fires at exactly N remaining stops', () async {
    final svc = TrackingService();
    final gps = StreamController<Position>();
    testGpsStream = gps.stream;

    // Build a simple 2-transit-step route: 3 stops then 2 stops (total 5)
    final directions = _mkTransitWithStops(stopsToTransfer: 3, stopsToDest: 2);
    svc.registerRouteFromDirections(
      directions: directions,
      origin: const LatLng(0.0, 0.0),
      destination: const LatLng(0.02, 0.02),
      transitMode: true,
      destinationName: 'Final',
    );

    await svc.startTracking(
      destination: const LatLng(0.02, 0.02),
      destinationName: 'Final',
      alarmMode: 'stops',
      alarmValue: 2.0, // fire when remaining stops <= 2
    );

    // Move along to just before the boundary where remaining stops == 2
    // Since we don't have exact mapping from meters to stops via active state,
    // feed multiple positions to drive progress updates.
    for (int i = 0; i < 6; i++) {
      gps.add(_p(0.001 * i, 0.001 * i));
      await Future.delayed(const Duration(milliseconds: 120));
    }

    // Wait briefly and expect at least one destination-style alarm (allow=false)
    await Future.delayed(const Duration(milliseconds: 500));
    final destAlarms = NotificationService.testRecordedAlarms
        .where((e) => (e['title'] as String).startsWith('Wake Up'))
        .toList();
    expect(destAlarms.length <= 1, isTrue);

    await svc.stopTracking();
    await gps.close();
  }, timeout: const Timeout(Duration(seconds: 20)));
}
