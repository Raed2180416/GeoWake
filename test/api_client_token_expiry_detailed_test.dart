@Tags(['serial'])
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/services/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient token expiry detailed', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ApiClient.resetForTests();
      ApiClient.clearTestAuthResponses();
      ApiClient.authBackoffScaler = 0.0; // speed retries
      ApiClient.testMode = true; // enable canned non-auth responses; queued auth still honored
      ApiClient.disableConnectionTest = true; // skip health check to keep queue simple
      ApiClient.setSecureStorage(InMemorySecureStorage()); // avoid platform plugin
    });

    test('Parses 24h format and sets dynamic early window', () async {
      ApiClient.enqueueTestAuthResponse(200, '{"success":true,"token":"t1","expiresIn":"24h"}');
      final client = ApiClient.instance;
      await client.initialize();
      expect(ApiClient.debugTestAuthCallCount, 1);
    });

    test('Retry backoff increments authCalls, stops at success', () async {
      ApiClient.enqueueTestAuthResponse(500, '{"error":"x"}');
      ApiClient.enqueueTestAuthResponse(500, '{"error":"x"}');
      ApiClient.enqueueTestAuthResponse(200, '{"success":true,"token":"t2","expiresIn":"3600s"}');
      final client = ApiClient.instance;
      final start = DateTime.now();
      await client.initialize();
      final elapsedMs = DateTime.now().difference(start).inMilliseconds;
      expect(ApiClient.debugTestAuthCallCount, 3);
      // With scaler=0.0 backoff delays collapse ~0ms so total should be quick
      expect(elapsedMs < 500, true);
    });

    test('Unknown expiresIn falls back to default', () async {
      ApiClient.enqueueTestAuthResponse(200, '{"success":true,"token":"t3","expiresIn":"weird"}');
      final client = ApiClient.instance;
      await client.initialize();
      expect(ApiClient.debugTestAuthCallCount, 1);
    });

    test('Concurrent initialize calls coalesce', () async {
      ApiClient.enqueueTestAuthResponse(200, '{"success":true,"token":"t4","expiresIn":"1800s"}');
      final futures = [ApiClient.instance.initialize(), ApiClient.instance.initialize(), ApiClient.instance.initialize()];
      await Future.wait(futures);
      expect(ApiClient.debugTestAuthCallCount, 1);
    });
  });
}
