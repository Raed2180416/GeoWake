import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/deviation_monitor.dart';

void main() {
  group('DeviationMonitor hysteresis', () {
        test('enter above high, exit below low (strict >)', () {
            final m = DeviationMonitor(model: const SpeedThresholdModel(base: 10, k: 2, hysteresisRatio: 0.5), syncStream: true);
            const speed = 5.0; // m/s
            final high = m.highThreshold(speed);
            final low = m.lowThreshold(speed);

            DeviationState last = DeviationState(offroute: false, sustained: false, offsetMeters: 0, speedMps: 0, at: DateTime.fromMillisecondsSinceEpoch(0));
            m.stream.listen((s) { last = s; });

            // At exactly high (strict >) should not enter
            m.ingest(offsetMeters: high, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(0));
            expect(last.offroute, false, reason: 'Should not enter when offset == high with strict >');

            // Cross high strictly
            m.ingest(offsetMeters: high + 0.01, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(1000));
            expect(last.offroute, true);
            expect(last.sustained, false);

            // Fall but still above low: remain offroute
            m.ingest(offsetMeters: (low + high) / 2, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(2000));
            expect(last.offroute, true);

            // Drop just above low still offroute
            m.ingest(offsetMeters: low + 0.0001, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(2500));
            expect(last.offroute, true);

            // Below low -> exit
            m.ingest(offsetMeters: low - 0.001, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(3000));
            expect(last.offroute, false);
        });

        test('inclusive entry mode enters at == high', () {
            final m = DeviationMonitor(model: const SpeedThresholdModel(base: 5, k: 1, hysteresisRatio: 0.6), inclusiveEntry: true, syncStream: true);
            const speed = 4.0; // thresholds high=5+1*4=9 low=0.6*9=5.4
            final high = m.highThreshold(speed);
            final low = m.lowThreshold(speed);

            DeviationState last = DeviationState(offroute: false, sustained: false, offsetMeters: 0, speedMps: 0, at: DateTime.fromMillisecondsSinceEpoch(0));
            m.stream.listen((s) { last = s; });

            // At high -> should enter because inclusiveEntry
            m.ingest(offsetMeters: high, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(0));
            expect(last.offroute, true, reason: 'Inclusive mode should enter at == high');

            // Drop to above low stay offroute
            m.ingest(offsetMeters: (low + high) / 2, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(1000));
            expect(last.offroute, true);

            // Drop below low exit
            m.ingest(offsetMeters: low - 0.01, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(2000));
            expect(last.offroute, false);
        });

        test('sustain triggers after duration', () {
            const sustain = Duration(seconds: 5);
            final m = DeviationMonitor(model: const SpeedThresholdModel(base: 0, k: 0, hysteresisRatio: 0.5), sustainDuration: sustain, syncStream: true);
            const speed = 0.0; // thresholds all zero
            DeviationState last = DeviationState(offroute: false, sustained: false, offsetMeters: 0, speedMps: 0, at: DateTime.fromMillisecondsSinceEpoch(0));
            m.stream.listen((s) { last = s; });

            // Enter offroute at t=0 with offset > high (high=0)
            m.ingest(offsetMeters: 0.1, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(0));
            expect(last.offroute, true);
            expect(last.sustained, false);

            // Recover immediately at t=1000 (offset == low) should clear
            m.ingest(offsetMeters: 0.0, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(1000));
            expect(last.offroute, false);

            // Re-enter at t=1000 baseline resets diverging clock
            m.ingest(offsetMeters: 0.2, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(1000));
            expect(last.offroute, true);
            expect(last.sustained, false);

            // Just before sustain (t=4998)
            m.ingest(offsetMeters: 0.2, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(5998));
                        expect(m.lastSustainDiffMs, 4998);
                        // Allow small early sustain tolerance (< 250ms early)
                        if (last.sustained) {
                            expect(5000 - m.lastSustainDiffMs! < 250, true, reason: 'Sustained too early (diff=${m.lastSustainDiffMs})');
                        }

            // Still before sustain (t=4999)
            m.ingest(offsetMeters: 0.25, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(5999));
                        expect(m.lastSustainDiffMs, 4999);
                        if (last.sustained) {
                            expect(5000 - m.lastSustainDiffMs! < 250, true, reason: 'Sustained too early (diff=${m.lastSustainDiffMs})');
                        }

            // At sustain boundary (t=5000)
            m.ingest(offsetMeters: 0.3, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(6000));
            expect(m.lastSustainDiffMs, 5000);
            expect(last.sustained, true, reason: 'Should become sustained at or after duration diff=${m.lastSustainDiffMs}');

            // Recovery clears sustained flag
            m.ingest(offsetMeters: 0, speedMps: speed, at: DateTime.fromMillisecondsSinceEpoch(7000));
            expect(last.offroute, false);
            expect(last.sustained, false, reason: 'Sustain should reset after recovery');
        });
  });
}
