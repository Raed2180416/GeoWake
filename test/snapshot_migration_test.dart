import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/persistence/snapshot.dart';

void main() {
  group('TrackingSnapshot migration', () {
    test('decodes v1 -> v2 migration with new nullable fields absent', () {
      final v1 = '{"v":1,"ts":123,"p":0.5,"eta":50,"dist":100,"dLat":1.1,"dLng":2.2,"dName":"D","route":"rk","fb":111,"lastDestAlarm":222}';
      final snap = TrackingSnapshot.decode(v1);
      expect(snap, isNotNull);
      expect(snap!.version, 2, reason: 'v1 should migrate to current version 2');
      expect(snap.smoothedHeadingDeg, isNull);
      expect(snap.timeEligible, isNull);
      expect(snap.distanceTravelledMeters, 100);
      expect(snap.destinationName, 'D');
    });

    test('rejects unsupported future version', () {
      final future = '{"v":999,"ts":0}';
      final snap = TrackingSnapshot.decode(future);
      expect(snap, isNull);
    });

    test('rejects malformed json', () {
      final bad = '{"v":2,"ts":';
      final snap = TrackingSnapshot.decode(bad);
      expect(snap, isNull);
    });
  });
}
