import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/sample_validator.dart';
import 'package:geolocator/geolocator.dart';

Position mk({
  required double lat,
  required double lng,
  required DateTime ts,
  double speed = 0,
  double accuracy = 10,
}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: ts,
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
);

void main() {
  group('SampleValidator', () {
    test('accepts valid sample', () {
      final v = SampleValidator();
      final now = DateTime.now();
      final res = v.validate(mk(lat: 0, lng: 0, ts: now, speed: 5), now);
      expect(res.accepted, isTrue);
      expect(v.lastAccepted, isNotNull);
    });

    test('rejects stale', () {
      final v = SampleValidator(staleThreshold: const Duration(seconds: 2));
      final now = DateTime.now();
      final res = v.validate(mk(lat: 0, lng: 0, ts: now.subtract(const Duration(seconds: 5))), now);
      expect(res.accepted, isFalse);
      expect(res.reason, 'stale');
    });

    test('rejects poor accuracy', () {
      final v = SampleValidator(maxAccuracyMeters: 30);
      final now = DateTime.now();
      final res = v.validate(mk(lat: 0, lng: 0, ts: now, accuracy: 100), now);
      expect(res.accepted, isFalse);
      expect(res.reason, 'accuracy');
    });

    test('rejects speed cap', () {
      final v = SampleValidator(maxSpeedMps: 20);
      final now = DateTime.now();
      final res = v.validate(mk(lat: 0, lng: 0, ts: now, speed: 50), now);
      expect(res.accepted, isFalse);
      expect(res.reason, 'speed');
    });

    test('rejects acceleration spike', () {
      final v = SampleValidator(maxAccelMps2: 5);
      DateTime t = DateTime.now();
      final s1 = mk(lat:0, lng:0, ts: t, speed: 0);
      v.validate(s1, t);
      t = t.add(const Duration(seconds: 1));
      final s2 = mk(lat:0, lng:0.0001, ts: t, speed: 40); // 40 m/s in 1s accel=40
      final res = v.validate(s2, t);
      expect(res.accepted, isFalse);
      expect(res.reason, 'accel');
    });

    test('rejects teleport jump', () {
      final v = SampleValidator(maxSpeedMps: 30);
      DateTime t = DateTime.now();
      final s1 = mk(lat:0, lng:0, ts: t, speed: 10);
      v.validate(s1, t);
      t = t.add(const Duration(seconds: 1));
      // ~111m east jump => implies > maxSpeed*1.2 (30*1.2=36). distance 111m in 1s => 111 m/s
      final s2 = mk(lat:0, lng:0.001, ts: t, speed: 10);
      final res = v.validate(s2, t);
      expect(res.accepted, isFalse);
      expect(res.reason, 'jump');
    });
  });
}
