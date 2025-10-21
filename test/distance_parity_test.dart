import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';
import 'package:geowake2/services/refactor/alarm_orchestrator_impl.dart';
import 'package:geowake2/services/refactor/location_types.dart';
import 'package:geowake2/services/refactor/interfaces.dart';

// Distance parity: compare legacy vs orchestrator trigger times for a simple straight route.
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

  test('Distance parity: orchestrator triggers near legacy', () async {
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();

    final svc = TrackingService();
    final gps = StreamController<Position>();
    testGpsStream = gps.stream;

    final origin = const LatLng(0.0, 0.0);
    final dest = const LatLng(0.01, 0.0); // ~1110m

    await svc.startTracking(
      destination: dest,
      destinationName: 'Dest',
      alarmMode: 'distance',
      alarmValue: 0.3, // 300m threshold
    );

    final orch = AlarmOrchestratorImpl(requiredPasses: 1, minDwell: const Duration(milliseconds: 10));
    orch.setProximityGatingEnabled(false);
    orch.configure(AlarmConfig(
      distanceThresholdMeters: 300.0,
      timeETALimitSeconds: 0,
      minEtaSamples: 0,
      stopsThreshold: 0,
    ));
    orch.registerDestination(const DestinationSpec(lat: 0.01, lng: 0.0, name: 'Dest'));
    orch.setTotalRouteMeters(1110);

    DateTime? legacyFiredAt;
    final legacyTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final fired = NotificationService.testRecordedAlarms.where((a) => (a['title'] as String).startsWith('Wake Up')).toList();
      if (fired.isNotEmpty && legacyFiredAt == null) legacyFiredAt = DateTime.now();
    });

    AlarmEvent? newEvent;
    final sub = orch.events$.listen((e) {
      if (e.type == 'TRIGGERED' && newEvent == null) newEvent = e;
    });

    for (int i = 0; i <= 40; i++) {
      final frac = i / 40; // 0..1
      final lat = origin.latitude + (dest.latitude - origin.latitude) * frac;
      final lng = origin.longitude + (dest.longitude - origin.longitude) * frac;
      final p = pos(lat, lng);
      gps.add(p);
      final sample = LocationSample(lat: lat, lng: lng, speedMps: 12, timestamp: DateTime.now());
      final snapped = SnappedPosition(
        lat: lat,
        lng: lng,
        routeId: 'r',
        progressMeters: 1110 * frac,
        lateralOffsetMeters: 0,
        segmentIndex: 0,
      );
      orch.update(sample: sample, snapped: snapped);
      await Future.delayed(const Duration(milliseconds: 60));
      if (legacyFiredAt != null && newEvent != null) break;
    }

    await Future.delayed(const Duration(milliseconds: 250));
    legacyTimer.cancel();

    expect(legacyFiredAt, isNotNull, reason: 'Legacy distance alarm should fire');
    expect(newEvent, isNotNull, reason: 'Orchestrator distance alarm should fire');

    final diff = (newEvent!.at.difference(legacyFiredAt!).inMilliseconds).abs();
    expect(diff < 1200, isTrue, reason: 'Trigger times close (diff=${diff}ms)');

    await sub.cancel();
    await svc.stopTracking();
    await gps.close();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
