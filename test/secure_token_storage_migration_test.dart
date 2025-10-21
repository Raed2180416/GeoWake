import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/api_client.dart';
import 'package:geowake2/services/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Secure token storage migration', () {
    late InMemorySecureStorage secure;

    setUp(() async {
      secure = InMemorySecureStorage();
      ApiClient.setSecureStorage(secure);
      ApiClient.resetForTests();
      SharedPreferences.setMockInitialValues({});
      // Ensure deterministic auth path uses queued responses not network
      ApiClient.clearTestAuthResponses();
      ApiClient.disableConnectionTest = true;
      ApiClient.testMode = true; // will short-circuit auth; we manually seed legacy token
    });

    test('Migrates legacy SharedPreferences token to secure storage and removes legacy key', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('geowake_api_token', 'legacy-token');
      await prefs.setString('geowake_api_token_exp', DateTime.now().add(const Duration(hours: 1)).toIso8601String());

      final client = ApiClient.instance;
      await client.initialize();

      // Validate migration
      expect(await secure.read('geowake_api_token'), 'legacy-token');
      expect(prefs.getString('geowake_api_token'), isNull, reason: 'Legacy key should be removed after migration');
    });

    test('Does not overwrite secure token if already migrated', () async {
      final prefs = await SharedPreferences.getInstance();
      await secure.write('geowake_api_token', 'secure-token');
      await prefs.setString('geowake_api_token', 'legacy-token-should-not-win');

      final client = ApiClient.instance;
      await client.initialize();

      expect(await secure.read('geowake_api_token'), 'secure-token');
      // legacy key should be removed still
      expect(prefs.getString('geowake_api_token'), isNull);
    });
  });
}
