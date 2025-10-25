import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/metrics/metrics.dart';

void main() {
  test('Metrics snapshot export produces valid JSON-ish string and values', () {
    final r = MetricsRegistry.I;
    r.counter('alarm.triggered').inc();
    r.counter('alarm.triggered').inc(2);
    r.duration('orchestrator.update').record(const Duration(milliseconds: 5));
    r.duration('orchestrator.update').record(const Duration(milliseconds: 15));

    final snap = r.snapshot();
    expect((snap['counters'] as Map)['alarm.triggered'], 3);
    final durations = (snap['durations'] as Map);
    final orch = durations['orchestrator.update'] as Map;
    expect(orch['count'], 2);
    expect(orch['maxMicros'], greaterThan(orch['avgMicros'] as int));

    final jsonStr = r.toJsonString();
    // Basic shape checks
    expect(jsonStr.contains('"counters"'), true);
    expect(jsonStr.contains('alarm.triggered'), true);
    expect(jsonStr.contains('orchestrator.update'), true);
  });
}
