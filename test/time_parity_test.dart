import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';
import 'package:geowake2/services/refactor/alarm_orchestrator_impl.dart';
import 'package:geowake2/services/refactor/location_types.dart';
import 'package:geowake2/services/refactor/interfaces.dart';

// Time parity: ensure orchestrator triggers similarly after eligibility + ETA threshold.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Position pos(double lat, double lng, {double speed = 15}) => Position(
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

  test('Time parity: orchestrator triggers near legacy', () async {
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();

    // Tweak legacy gating to make test faster
    TrackingService.timeAlarmMinSinceStart = const Duration(seconds: 2);
    TrackingService.testTimeAlarmMinDistanceMeters = 50;
    TrackingService.testTimeAlarmMinSamples = 2;

    final svc = TrackingService();
    final gps = StreamController<Position>();
    testGpsStream = gps.stream;

    final origin = const LatLng(0.0, 0.0);
    final dest = const LatLng(0.01, 0.0); // ~1110m

    await svc.startTracking(
      destination: dest,
      destinationName: 'Dest',
      alarmMode: 'time',
      alarmValue: 0.15, // 9 seconds threshold
    );

    final orch = AlarmOrchestratorImpl(requiredPasses: 1, minDwell: const Duration(milliseconds: 10));
    orch.setProximityGatingEnabled(false);
    orch.configure(const AlarmConfig(
      distanceThresholdMeters: 0,
      timeETALimitSeconds: 9.0,
      minEtaSamples: 2,
      stopsThreshold: 0,
      minTimeEligibilityDistanceMeters: 10, // relaxed for test speed
      minTimeEligibilitySinceStart: Duration(seconds: 1),
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

    for (int i = 0; i < 35; i++) {
      final frac = i / 35;
      final lat = origin.latitude + (dest.latitude - origin.latitude) * frac;
      final lng = 0.0;
      final p = pos(lat, lng);
      gps.add(p);
      final sample = LocationSample(lat: lat, lng: lng, speedMps: 15, timestamp: DateTime.now());
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

    expect(legacyFiredAt, isNotNull, reason: 'Legacy time alarm should fire');
    expect(newEvent, isNotNull, reason: 'Orchestrator time alarm should fire');

    final diff = (newEvent!.at.difference(legacyFiredAt!).inMilliseconds).abs();
    expect(diff < 1500, isTrue, reason: 'Trigger times close (diff=${diff}ms)');

    await sub.cancel();
    await svc.stopTracking();
    await gps.close();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
