import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NotificationService: safe when notifications unavailable/denied', () async {
    NotificationService.isTestMode = true; // avoid platform calls
    NotificationService.clearTestRecordedAlarms();

    // Wake-up alarm should record in test mode and not throw
    await NotificationService().showWakeUpAlarm(title: 'T', body: 'B');
    final alarms = NotificationService.testRecordedAlarms;
    expect(alarms.length, 1);
    expect(alarms.first['title'], 'T');
    expect(alarms.first['body'], 'B');

    // Progress updates should not throw even if plugin not available
    await NotificationService().showJourneyProgress(title: 'Journey', subtitle: 'Remaining 1.0 km', progress0to1: 0.5);
    await NotificationService().cancelJourneyProgress();

    NotificationService.isTestMode = false;
  });
}
