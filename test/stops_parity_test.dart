import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';
import 'package:geowake2/services/refactor/alarm_orchestrator_impl.dart';
import 'package:geowake2/services/refactor/location_types.dart';
import 'package:geowake2/services/refactor/interfaces.dart';

/// Parity harness: run legacy TrackingService in stops mode while feeding
/// identical progress (approximated) into new AlarmOrchestratorImpl and compare
/// trigger ordering (time tolerance window).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Position pos(double lat, double lng, {double speed = 12}) => Position(
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

  Map<String, dynamic> mkRoute() => {
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
                      'line': {'short_name': 'L1'},
                      'num_stops': 5,
                      'arrival_stop': {'name': 'Mid'}
                    }
                  },
                  {
                    'travel_mode': 'TRANSIT',
                    'distance': {'value': 3000},
                    'polyline': {'points': '}_se}Ff`miO??'},
                    'transit_details': {
                      'line': {'short_name': 'L2'},
                      'num_stops': 4,
                      'arrival_stop': {'name': 'Final'}
                    }
                  },
                ]
              }
            ],
            'overview_polyline': {'points': '}_se}Ff`miO??'}
          }
        ]
      };

  test('Stops parity: orchestrator triggers within tolerance of legacy', () async {
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();

    final svc = TrackingService();
    final gps = StreamController<Position>();
    testGpsStream = gps.stream;

    final directions = mkRoute();
    final origin = const LatLng(0.0, 0.0);
  // Use a destination far enough (~7km diagonal) so legacy progressMeters can exceed
  // the first step boundary (4000m) and approach the second (7000m) enabling remainingStops<=threshold
  final dest = const LatLng(0.045, 0.045);
    svc.registerRouteFromDirections(
      directions: directions,
      origin: origin,
      destination: dest,
      transitMode: true,
      destinationName: 'Final',
    );

    await svc.startTracking(
      destination: dest,
      destinationName: 'Final',
      alarmMode: 'stops',
      alarmValue: 2.0,
    );

    // New orchestrator configured equivalently
    final orch = AlarmOrchestratorImpl(requiredPasses: 1, minDwell: const Duration(milliseconds: 10));
    orch.setProximityGatingEnabled(false); // legacy gating already validated elsewhere; disable for pure parity timing
    orch.configure(const AlarmConfig(
      distanceThresholdMeters: 0,
      timeETALimitSeconds: 0,
      minEtaSamples: 0,
      stopsThreshold: 2,
    ));
  orch.registerDestination(const DestinationSpec(lat: 0.045, lng: 0.045, name: 'Final'));
    // Route metrics: total meters ~ straight-line fallback for simplicity
    orch.setTotalRouteMeters(7000); // matches 4km + 3km
    orch.setTotalStops(9); // 5 + 4

  DateTime? legacyFiredAt;
    // Track when legacy fires by observing NotificationService test alarms
    final legacyCheckTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final fired = NotificationService.testRecordedAlarms.where((a) => (a['title'] as String).startsWith('Wake Up')).toList();
      if (fired.isNotEmpty && legacyFiredAt == null) {
        legacyFiredAt = DateTime.now();
      }
    });

    AlarmEvent? newEvent;
    final sub = orch.events$.listen((e) {
      if (e.type == 'TRIGGERED' && newEvent == null) newEvent = e;
    });

    // Feed synthetic progress roughly linearly along the 7km route
    for (int i = 0; i <= 14; i++) {
      final frac = i / 14; // 0..1
  final lat = origin.latitude + (dest.latitude - origin.latitude) * frac;
  final lng = origin.longitude + (dest.longitude - origin.longitude) * frac;
      final p = pos(lat, lng);
      gps.add(p);
      // Simultaneously feed orchestrator with snapped progress
      final sample = LocationSample(lat: lat, lng: lng, speedMps: 12, timestamp: DateTime.now());
      final snapped = SnappedPosition(
        lat: lat,
        lng: lng,
        routeId: 'r',
        progressMeters: 7000 * frac,
        lateralOffsetMeters: 0,
        segmentIndex: 0,
      );
      orch.update(sample: sample, snapped: snapped);
      await Future.delayed(const Duration(milliseconds: 90));
      if (legacyFiredAt != null && newEvent != null) break;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    legacyCheckTimer.cancel();

    expect(legacyFiredAt, isNotNull, reason: 'Legacy should have fired in stops scenario');
    expect(newEvent, isNotNull, reason: 'New orchestrator should have fired');

    // Compare timing tolerance (<=1.5s diff acceptable given coarse simulation)
    final diffMs = (newEvent!.at.difference(legacyFiredAt!).inMilliseconds).abs();
    expect(diffMs < 1500, isTrue, reason: 'Trigger times should be close (diff=${diffMs}ms)');

    await sub.cancel();
    await svc.stopTracking();
    await gps.close();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
