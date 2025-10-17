import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/alarm_orchestrator.dart';
import 'package:geowake2/services/alarm_rollout.dart';

class MockNotifier implements AlarmNotifier {
  bool shown = false;
  @override
  Future<void> show(String title, String body, bool allowContinue) async {
    shown = true;
  }
  @override
  Future<void> cancelProgress() async {}
}

class FailingSound implements AlarmSoundPlayer {
  @override
  Future<void> play() async {
    throw Exception('Audio backend unavailable');
  }
}

void main() {
  test('Two-phase alarm rollback when audio fails', () async {
    final notifier = MockNotifier();
    final orchestrator = AlarmOrchestrator(
      notifier: notifier,
      sound: FailingSound(),
      rollout: AlarmRolloutConfig()..setStage(OrchestratorRolloutStage.primary),
    );
    expect(orchestrator.fired, isFalse);
    bool threw = false;
    try {
      await orchestrator.triggerDestinationAlarm(title: 't', body: 'b');
    } catch (_) {
      threw = true;
    }
    expect(threw, isTrue, reason: 'Should propagate audio failure');
    expect(orchestrator.fired, isFalse, reason: 'Should not mark fired when audio fails');
    expect(notifier.shown, isTrue, reason: 'Notification phase should have run');
  });
}
