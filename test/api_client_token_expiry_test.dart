import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/services/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient token expiry parsing & early refresh', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ApiClient.resetForTests();
      ApiClient.setSecureStorage(InMemorySecureStorage());
      ApiClient.testMode = true;
      ApiClient.disableConnectionTest = true;
      ApiClient.clearTestAuthResponses();
    });

    test('Legacy 24h token migrates to secure storage and is not refreshed early', () async {
      final client = ApiClient.instance;
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString('geowake_api_token', 'legacy-token');
      await prefs.setString('geowake_api_token_exp', now.add(const Duration(hours: 24)).toIso8601String());
      await client.initialize();
      // Legacy key should be removed after migration
      expect(prefs.getString('geowake_api_token'), isNull, reason: 'Legacy key should be cleared after migration');
      // Secure storage contains migrated token
      final secure = ApiClient.secureStorage as InMemorySecureStorage;
      expect(await secure.read('geowake_api_token'), 'legacy-token');
      // No auth attempts (no queued responses consumed)
      expect(ApiClient.debugTestAuthCallCount, 0);
    });
  });
}
