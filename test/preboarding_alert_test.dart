import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Pre-boarding alert fires once near first transit boarding', () async {
    // Arrange hooks
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();

    // Directions with first TRANSIT step including departure_stop
    final origin = const LatLng(12.9716, 77.5946);
    final boarding = const LatLng(12.9720, 77.5946);
    final destination = const LatLng(12.99, 77.60);

    final directions = {
      'routes': [
        {
          'legs': [
            {
              'steps': [
                {
                  'travel_mode': 'WALKING',
                  'distance': {'value': 200.0},
                  'polyline': {'points': '}_ibE_seK'},
                },
                {
                  'travel_mode': 'TRANSIT',
                  'distance': {'value': 2000.0},
                  'transit_details': {
                    'departure_stop': {
                      'name': 'Metro A',
                      'location': {'lat': boarding.latitude, 'lng': boarding.longitude}
                    },
                    'num_stops': 5,
                    'line': {'short_name': 'R1'}
                  },
                  'polyline': {'points': '}_ibE_seK_seK'},
                },
                {
                  'travel_mode': 'TRANSIT',
                  'distance': {'value': 3000.0},
                  'transit_details': {
                    'num_stops': 6,
                    'line': {'short_name': 'R2'}
                  },
                  'polyline': {'points': '}_ibE_seK_seK_seK'},
                },
              ]
            }
          ],
          'overview_polyline': {'points': '}_ibE_seK_seK_seK_seK'},
        }
      ]
    };

    final svc = TrackingService();
    // Register route to compute boarding location
    svc.registerRouteFromDirections(
      directions: directions,
      origin: origin,
      destination: destination,
      transitMode: true,
      destinationName: 'Dest',
    );

    // Prepare test GPS stream BEFORE starting
    final ctrl = StreamController<Position>();
    testGpsStream = ctrl.stream;

    // Start tracking in stops mode to enable pre-boarding alert path
    await svc.startTracking(
      destination: destination,
      destinationName: 'Dest',
      alarmMode: 'stops',
      alarmValue: 2, // not used for pre-boarding; ensures stops mode
      // Keep NotificationService in test mode to record alarms
      allowNotificationsInTest: false,
      useInjectedPositions: false,
    );
    await Future.delayed(const Duration(milliseconds: 50));

    // Feed positions via testGpsStream
    void inject(LatLng p, {double speed = 12.0}) => ctrl.add(Position(
          latitude: p.latitude,
          longitude: p.longitude,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: speed,
          speedAccuracy: 1.0,
        ));

    // Far from boarding
  inject(const LatLng(12.9600, 77.5900));
  await Future.delayed(const Duration(milliseconds: 250));

    // Near boarding within 1km
  inject(LatLng(boarding.latitude + 0.002, boarding.longitude));
  await Future.delayed(const Duration(milliseconds: 350));

    // Another near sample - should not double-fire
  inject(LatLng(boarding.latitude + 0.0015, boarding.longitude));
  await Future.delayed(const Duration(milliseconds: 350));

    // Assert exactly one pre-boarding style alarm (allowContinue true)
    final alarms = NotificationService.testRecordedAlarms;
    final preboarding = alarms.where((a) => a['title'] == 'Approaching metro station').toList();
    expect(preboarding.length, 1);

    await svc.stopTracking();
    await ctrl.close();
  });
}
