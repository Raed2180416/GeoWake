import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/idle_power_scaler.dart';

void main() {
  group('IdlePowerScaler', () {
    test('Remains active with insufficient samples', () {
      final s = IdlePowerScaler(minSamples: 4, windowSize: 4, idleMinDuration: const Duration(seconds: 5));
      final t0 = DateTime.now();
      for (int i = 0; i < 3; i++) {
        s.addSample(lat: 0, lng: 0.00001 * i, speedMps: 0.2, ts: t0.add(Duration(seconds: i)));
      }
      expect(s.isIdle, false);
    });

    test('Transitions to idle after sustained low movement & speed', () {
      final s = IdlePowerScaler(
        minSamples: 4,
        windowSize: 6,
        distanceSlackMeters: 10.0,
        speedThresholdMps: 0.5,
        idleMinDuration: const Duration(seconds: 3),
      );
      final t0 = DateTime.now();
      // Very tiny movements ~1m each second, speed low
      for (int i = 0; i < 10; i++) {
        // Spread samples 1 second apart; idleMinDuration is 6s so last.ts - first idle candidate >= 9s
        s.addSample(lat: 0, lng: 0.000009 * i, speedMps: 0.3, ts: t0.add(Duration(seconds: i)));
      }
      expect(s.isIdle, true);
    });

    test('Wakes immediately on jump distance', () {
      final s = IdlePowerScaler(
        minSamples: 4,
        windowSize: 6,
        distanceSlackMeters: 10.0,
        speedThresholdMps: 0.5,
        wakeDistanceMeters: 15.0,
        idleMinDuration: const Duration(seconds: 3),
      );
      final t0 = DateTime.now();
      for (int i = 0; i < 10; i++) {
        s.addSample(lat: 0, lng: 0.000005 * i, speedMps: 0.2, ts: t0.add(Duration(seconds: i)));
      }
      expect(s.isIdle, true);
      // Big jump ~30m
      s.addSample(lat: 0, lng: 0.0003, speedMps: 0.4, ts: t0.add(const Duration(seconds: 9)));
      expect(s.isIdle, false);
    });

    test('Wakes on speed spike', () {
      final s = IdlePowerScaler(
        minSamples: 4,
        windowSize: 6,
        distanceSlackMeters: 10.0,
        speedThresholdMps: 0.5,
        wakeSpeedMps: 3.0,
        idleMinDuration: const Duration(seconds: 3),
      );
      final t0 = DateTime.now();
      for (int i = 0; i < 10; i++) {
        s.addSample(lat: 0, lng: 0.000004 * i, speedMps: 0.4, ts: t0.add(Duration(seconds: i)));
      }
      expect(s.isIdle, true);
      // Speed spike
      s.addSample(lat: 0, lng: 0.000004 * 10, speedMps: 4.0, ts: t0.add(const Duration(seconds: 10)));
      expect(s.isIdle, false);
    });
  });
}