import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('showPendingAlarmScreenIfAny reads and clears stored keys', () async {
    NotificationService.isTestMode = true; // avoid platform calls
    SharedPreferences.setMockInitialValues({
      'pending_alarm_flag': true,
      'pending_alarm_title': 'Wake Up!',
      'pending_alarm_body': 'Approaching test',
      'pending_alarm_allow': true,
    });

    await NotificationService().showPendingAlarmScreenIfAny();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pending_alarm_flag') ?? false, false);
    expect(prefs.getString('pending_alarm_title'), isNull);
    expect(prefs.getString('pending_alarm_body'), isNull);
    expect(prefs.getBool('pending_alarm_allow'), isNull);

    NotificationService.isTestMode = false;
  });
}
