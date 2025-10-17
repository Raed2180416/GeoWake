import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/eta/eta_engine.dart';

void main() {
  group('EtaEngine core behavior', () {
    test('Smoothing converges toward raw ETA', () {
      final engine = EtaEngine(minSamplesForConfidence: 3, rapidDropFraction: 0.2);
      // Distance 600m, speed 2 m/s => raw ETA 300s
      EtaResult r1 = engine.update(distanceMeters: 600, representativeSpeedMps: 2.0, movementMode: 'walk');
      expect(r1.etaSeconds, closeTo(300, 0.001));
      // Reduce distance to 500m (raw 250s). Smoothed should still be > 250 first update
      EtaResult r2 = engine.update(distanceMeters: 500, representativeSpeedMps: 2.0, movementMode: 'walk');
      expect(r2.etaSeconds, greaterThan(250));
      // After several consistent updates it should approach 250
      for (int i=0;i<5;i++) { r2 = engine.update(distanceMeters: 500, representativeSpeedMps: 2.0, movementMode: 'walk'); }
      expect(r2.etaSeconds, closeTo(250, 20)); // within ~20s band
    });

    test('Confidence rises with samples and caps at 1', () {
      final engine = EtaEngine(minSamplesForConfidence: 4);
      double lastConf = 0;
      for (int i=0;i<10;i++) {
        final r = engine.update(distanceMeters: 1000 - i*10, representativeSpeedMps: 5.0, movementMode: 'drive');
        expect(r.confidence, inInclusiveRange(lastConf, 1.0));
        lastConf = r.confidence;
      }
      expect(lastConf, equals(1.0));
    });

    test('Volatility reflects variance of recent ETAs', () {
      final engine = EtaEngine(volatilityWindow: 6);
      // Provide stable sequence -> low volatility
      for (int i=0;i<6;i++) { engine.update(distanceMeters: 600, representativeSpeedMps: 2.0, movementMode: 'walk'); }
      final stable = engine.update(distanceMeters: 600, representativeSpeedMps: 2.0, movementMode: 'walk');
      expect(stable.volatility, lessThan(0.05));
      // Introduce big change -> volatility should rise
      engine.update(distanceMeters: 200, representativeSpeedMps: 2.0, movementMode: 'walk');
      final volatile = engine.update(distanceMeters: 800, representativeSpeedMps: 1.0, movementMode: 'walk');
      expect(volatile.volatility, greaterThan(stable.volatility));
    });

    test('Rapid drop hint triggers when ETA improves sharply', () {
      final engine = EtaEngine(rapidDropFraction: 0.2); // 20%
      engine.update(distanceMeters: 1000, representativeSpeedMps: 2.0, movementMode: 'walk'); // ~500s baseline
      engine.update(distanceMeters: 980, representativeSpeedMps: 2.0, movementMode: 'walk'); // minor change
      final noHint = engine.update(distanceMeters: 960, representativeSpeedMps: 2.0, movementMode: 'walk');
      expect(noHint.immediateEvaluationHint, isFalse);
      // Big improvement (>20% raw) -> distance 500m (raw 250s) from ~ ~490s smoothed; drop > 40%
      final hint = engine.update(distanceMeters: 500, representativeSpeedMps: 2.0, movementMode: 'walk');
      expect(hint.immediateEvaluationHint, isTrue);
    });
  });
}
