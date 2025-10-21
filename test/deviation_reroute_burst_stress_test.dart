import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/api_client.dart';
import 'log_helper.dart';

Position _p(double lat, double lng, {double speed = 14.0}) => Position(
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

List<LatLng> _line(LatLng a, LatLng b, int n) => List.generate(n, (i) {
  final t = i / (n - 1);
  return LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
});

void main() {
  group('Deviation & reroute burst stress', () {
    late TrackingService svc;
    late StreamController<Position> gps;

    setUp(() {
      TrackingService.isTestMode = true;
      ApiClient.testMode = true;
      gps = StreamController<Position>();
      testGpsStream = gps.stream;
      svc = TrackingService();
    });

    tearDown(() async {
      await gps.close();
      testGpsStream = null;
      await svc.stopTracking();
    });

    test('Multiple deviation enter/clear cycles without duplicate overlapping reroute decisions', () async {
      logSection('Burst deviation cycles');
      // Two perpendicular routes around origin
      final rH = _line(const LatLng(0.0005, -0.01), const LatLng(0.0005, 0.01), 30); // horizontal slightly north
      final rV = _line(const LatLng(-0.01, 0.0005), const LatLng(0.01, 0.0005), 30); // vertical slightly east

      svc.registerRoute(key: 'H', mode: 'driving', destinationName: 'H', points: rH);
      svc.registerRoute(key: 'V', mode: 'driving', destinationName: 'V', points: rV);

      await svc.startTracking(destination: const LatLng(0.01, 0.01), destinationName: 'Burst', alarmMode: 'distance', alarmValue: 5.0);

      final switches = <String>[];
      final rerouteFlags = <bool>[];
      final switchSub = svc.routeSwitchStream.listen((e) => switches.add('${e.fromKey}->${e.toKey}'));
      final rerouteSub = svc.rerouteDecisionStream.listen((r) => rerouteFlags.add(r.shouldReroute));

      // Pattern: on horizontal -> drift off to trigger deviation sustain -> back near -> cross vertical -> repeat
      // We'll do 5 cycles
      for (int cycle = 0; cycle < 5; cycle++) {
        logStep('Cycle $cycle: feed along H near center');
        gps.add(_p(0.0005, -0.006));
        await Future.delayed(const Duration(milliseconds: 120));
        gps.add(_p(0.0005, -0.002));
        await Future.delayed(const Duration(milliseconds: 120));
        // Drift diagonally away to exceed threshold
        gps.add(_p(0.003 + cycle * 0.0001, -0.0005));
        await Future.delayed(const Duration(milliseconds: 150));
        gps.add(_p(0.005 + cycle * 0.0001, 0.001));
        await Future.delayed(const Duration(milliseconds: 300)); // allow sustain window
        // Return towards intersection triggering potential clear
        gps.add(_p(0.0008, 0.0008));
        await Future.delayed(const Duration(milliseconds: 120));
        // Move toward vertical alignment
        gps.add(_p(0.002, 0.0005));
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // Let final events settle
      await Future.delayed(const Duration(milliseconds: 600));

      await switchSub.cancel();
      await rerouteSub.cancel();

      // Assertions:
      // Expect at least one switch OR several reroute decisions across cycles
      final switchCount = switches.length;
      final rerouteCount = rerouteFlags.where((v) => v).length;
      logInfo('Observed switch events: $switches');
      logInfo('Reroute decisions (bool flags): $rerouteFlags');
      expect(switchCount + rerouteCount > 0, true, reason: 'Some deviation-induced action occurred');

      // Ensure no pathological duplication: require distinct entries <= cycles * 2
      expect(switchCount <= 10, true, reason: 'Limited number of route switches');
      expect(rerouteCount <= 10, true, reason: 'Limited number of reroute decisions');
    }, timeout: const Timeout(Duration(seconds: 40)));
  });
}
