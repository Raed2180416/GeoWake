import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/services/notification_service.dart';
import 'package:geowake2/services/trackingservice.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotificationService.isTestMode = true;
    TrackingService.resetNativeActionHandlersForTest();
    NotificationService.debugMethodChannelInvoker = null;
  });

  tearDown(() async {
    TrackingService.resetNativeActionHandlersForTest();
  const channel = MethodChannel('com.example.geowake2/alarm');
  binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    NotificationService.debugMethodChannelInvoker = null;
  });

  test('native end tracking triggers handler and ack', () async {
    bool stopCalled = false;
    TrackingService.debugNativeEndTrackingHandler = () async {
      stopCalled = true;
    };

    final calls = <MethodCall>[];
    const channel = MethodChannel('com.example.geowake2/alarm');
  binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return null;
    });

    await NotificationService().debugHandleNativeCallback('nativeEndTrackingTriggered', {'source': 'test'});

    expect(stopCalled, isTrue);
    expect(calls.any((c) => c.method == 'acknowledgeNativeEndTracking'), isTrue);
  });

  test('native ignore tracking triggers handler and ack', () async {
    bool ignoreCalled = false;
    TrackingService.debugNativeIgnoreTrackingHandler = () async {
      ignoreCalled = true;
    };

    final calls = <MethodCall>[];
    const channel = MethodChannel('com.example.geowake2/alarm');
  binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return null;
    });

    await NotificationService().debugHandleNativeCallback('nativeIgnoreTrackingTriggered', {'source': 'test'});

    expect(ignoreCalled, isTrue);
    expect(calls.any((c) => c.method == 'acknowledgeNativeIgnoreTracking'), isTrue);
  });
}
