import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:geowake2/services/deviation_monitor.dart';

void main() {
  group('DeviationMonitor hysteresis', () {
    test('Does not flicker when offset oscillates between low/high thresholds', () async {
      final model = SpeedThresholdModel(base: 10, k: 2, hysteresisRatio: 0.6);
      final monitor = DeviationMonitor(
        sustainDuration: const Duration(seconds: 2),
        model: model,
      );
      final events = <DeviationState>[];
      monitor.stream.listen(events.add);

      // speed -> thresholds
      final speed = 5.0; // m/s
      final high = model.high(speed); // 10 + 2*5 = 20
      final low = model.low(speed); // 0.6 * 20 = 12

      DateTime t = DateTime(2023,1,1,12,0,0);
      int feedCount = 0;
      void feed(double offset) {
        monitor.ingest(offsetMeters: offset, speedMps: speed, at: t);
        t = t.add(const Duration(milliseconds: 500));
        feedCount++;
      }

      // Sanity: initial below-low (should emit on-route)
      feed(low - 1); // 11
      feed(low + 0.5); // 12.5 still below high, should not mark offroute yet
      // Cross high -> offroute start
      feed(high + 0.5); // 20.5 triggers offroute
      // Oscillate above low but below high (should stay offroute, not reset)
      feed((low + high) / 2); // 16
      feed(high + 1); // 21
      // Drop just above low repeatedly; should NOT clear until below low
      feed(low + 0.1); // 12.1 still >= low -> remain offroute
      feed(high + 2); // 22
      // After sustainDuration (~2s = 4 * 500ms intervals after initial dev), mark sustained
      feed(high + 2); // progress time
      feed(high + 2);
  // Now go clearly below low -> clear
  feed(low - 2); // 10

  // Allow async broadcast stream to deliver events
  await Future.delayed(Duration.zero);

      // Assertions (focus on invariants)
      expect(events.length, feedCount, reason: 'Mismatch events vs feeds (events=${events.length} feeds=$feedCount)');
      expect(events.isNotEmpty, true, reason: 'DeviationMonitor produced no events (high=$high low=$low)');

      // 1. At most one transition into sustained=true (subsequent sustained events allowed)
      int sustainedTransitions = 0;
      bool prevSustained = false;
      for (final e in events) {
        if (!prevSustained && e.sustained) sustainedTransitions++;
        prevSustained = e.sustained;
      }
      expect(sustainedTransitions <= 1, true, reason: 'More than one sustained transition');

      // 2. No flicker false->true->false->true pattern in offroute state
      bool badPattern = false;
      for (int i = 3; i < events.length; i++) {
        if (!events[i-3].offroute && events[i-2].offroute && !events[i-1].offroute && events[i].offroute) {
          badPattern = true; break;
        }
      }
      expect(badPattern, false, reason: 'Detected offroute flicker pattern');

      // 3. Final state should be on-route (cleared) after dropping below low
      expect(events.last.offroute, false, reason: 'Did not clear after final below-low offset');

      // 4. If sustained occurred, ensure sufficient elapsed simulated time
      final firstOffIndex = events.indexWhere((e) => e.offroute);
      if (firstOffIndex != -1) {
        final firstOffTime = events[firstOffIndex].at;
        final sustainIndex = events.indexWhere((e) => e.sustained);
        if (sustainIndex != -1) {
          final sustainTime = events[sustainIndex].at;
          expect(sustainTime.difference(firstOffTime) >= const Duration(seconds: 2), true, reason: 'Sustained flagged too early');
        }
      }
    });
  });
}
