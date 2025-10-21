import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/deviation_monitor.dart';

void main() {
  test('debug sustain diff', () {
    final m = DeviationMonitor(model: const SpeedThresholdModel(base:0,k:0,hysteresisRatio:0.5), sustainDuration: const Duration(seconds:5), syncStream:true);
    m.ingest(offsetMeters:0.1, speedMps:0, at: DateTime.fromMillisecondsSinceEpoch(0));
    expect(m.lastSustainDiffMs, isNull);
    for(final ms in [1000,2000,3000,4000,4999]) {
      m.ingest(offsetMeters:0.2, speedMps:0, at: DateTime.fromMillisecondsSinceEpoch(ms));
    }
    // print debug (will show in test output via expect failure trick if needed)
    expect(m.lastSustainDiffMs! < 5000, true, reason: 'diff=${m.lastSustainDiffMs}');
    m.ingest(offsetMeters:0.2, speedMps:0, at: DateTime.fromMillisecondsSinceEpoch(5000));
    expect(m.lastSustainDiffMs, 5000);
    expect(true, true);
  });
}
