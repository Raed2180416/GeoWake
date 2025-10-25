import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Event alarms fire once per index; do not overlap with destination', () async {
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();

    final origin = const LatLng(37.0, -122.0);
    final destination = const LatLng(37.02, -122.0);

    // Build a transit route with one transfer mid-way
    Map<String, dynamic> mkStep(String mode, double meters, {int? stops, Map<String, dynamic>? td}) => {
      'travel_mode': mode,
      'distance': {'value': meters},
      if (mode == 'TRANSIT') 'transit_details': {
        if (td != null) ...td,
        if (stops != null) 'num_stops': stops,
        'line': {'short_name': td?['line']?['short_name'] ?? 'R1'}
      },
      'polyline': {'points': '}_ibE_seK'},
    };

    final directions = {
      'routes': [
        {
          'legs': [
            {
              'steps': [
                mkStep('WALKING', 200.0),
                mkStep('TRANSIT', 1200.0, stops: 3, td: {
                  'arrival_stop': {'name': 'Xfer A'}
                }),
                // transfer occurs here to R2
                {
                  'travel_mode': 'TRANSIT',
                  'distance': {'value': 1200.0},
                  'transit_details': {
                    'num_stops': 3,
                    'line': {'short_name': 'R2'}
                  },
                  'polyline': {'points': '}_ibE_seK'},
                },
                mkStep('WALKING', 200.0),
              ]
            }
          ],
          'overview_polyline': {'points': '}_ibE_seK_seK_seK'},
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

    // Use distance mode with 1km threshold so both event and destination alerts are possible
    final ctrl = StreamController<Position>();
    testGpsStream = ctrl.stream;
    await svc.startTracking(
      destination: destination,
      destinationName: 'Dest',
      alarmMode: 'distance',
      alarmValue: 1.0,
      allowNotificationsInTest: true,
      useInjectedPositions: false,
    );

    Position mk(double lat, double lng, double spd) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: spd,
      speedAccuracy: 1.0,
    );

    // Move towards the transfer boundary to trigger the event alert
    for (int i = 0; i < 8; i++) {
      ctrl.add(mk(origin.latitude + 0.001 * i, origin.longitude, 8.0));
      await Future.delayed(const Duration(milliseconds: 120));
    }

  // Record alarms so far and expect at least one event-style alarm (allow=true)
  final alarms1 = List<Map<String, dynamic>>.from(NotificationService.testRecordedAlarms);
  expect(alarms1.any((a) => a['allow'] == true), isTrue);

    // Move closer to destination to potentially trigger destination alarm
    for (int i = 8; i < 14; i++) {
      ctrl.add(mk(origin.latitude + 0.001 * i, origin.longitude, 10.0));
      await Future.delayed(const Duration(milliseconds: 120));
    }

    // Event alarms should be single-fired per index (no duplicates)
  final events = NotificationService.testRecordedAlarms.where((a) => a['allow'] == true).toList();
    expect(events.length <= 1, isTrue);

    // Destination alarm (if fired) should be final and not co-fire with another destination; verify at most one 'Wake Up!' entry
    final destAlarms = NotificationService.testRecordedAlarms.where((a) => (a['title'] as String).startsWith('Wake Up')).toList();
    expect(destAlarms.length <= 1, isTrue);

    await svc.stopTracking();
    await ctrl.close();
  });
}
