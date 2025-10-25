import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/api_client.dart';
import 'package:geowake2/services/ssl_pinning.dart';
import 'package:geowake2/services/secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class FakeVerifier implements CertificatePinVerifier {
  final bool accept;
  FakeVerifier(this.accept);
  @override
  bool verify(String host, cert) => accept;
}

class FakeEnforcer implements PinEnforcer {
  final bool accept;
  FakeEnforcer(this.accept);
  @override
  Future<void> ensure(String host, int port, {bool https = true}) async {
    if (!accept) throw PinMismatchException(host);
  }
}

class DummyClient extends http.BaseClient {
  final http.Response response;
  DummyClient(this.response);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stream = Stream<List<int>>.fromIterable([response.bodyBytes]);
    return http.StreamedResponse(stream, response.statusCode, request: request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('SSL pinning', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ApiClient.resetForTests();
      ApiClient.disableConnectionTest = true;
      ApiClient.testMode = true; // so _makeRequest returns canned responses; avoids real HTTP
      ApiClient.setSecureStorage(InMemorySecureStorage());
    });

    test('Allows requests when pin enforcer approves', () async {
      // Force full client path (not ApiClient.testMode shortcut) so pin enforcer is invoked.
      ApiClient.testMode = false;
      final secure = InMemorySecureStorage();
      ApiClient.setSecureStorage(secure);
      await secure.write('geowake_api_token', 'seed-token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('geowake_api_token_exp', DateTime.now().add(const Duration(hours: 1)).toIso8601String());
      // Configure accepting enforcer
      ApiClient.setHttpClient(PinnedHttpClient(
        DummyClient(http.Response('{"routes":[{"overview_polyline":{"points":"abc"},"legs":[{"steps":[],"duration":{"value":10}}]}],"status":"OK"}', 200)),
        enforcer: FakeEnforcer(true),
        enabled: true,
      ));
      final client = ApiClient.instance;
      await client.initialize();
      final res = await client.getDirections(origin: 'A', destination: 'B');
      expect(res['status'], 'OK');
    });

    test('Throws PinMismatchException when pin enforcer rejects', () async {
      ApiClient.testMode = false;
      final secure = InMemorySecureStorage();
      ApiClient.setSecureStorage(secure);
      await secure.write('geowake_api_token', 'seed-token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('geowake_api_token_exp', DateTime.now().add(const Duration(hours: 1)).toIso8601String());
      ApiClient.setHttpClient(PinnedHttpClient(
        DummyClient(http.Response('{"routes":[],"status":"OK"}', 200)),
        enforcer: FakeEnforcer(false),
        enabled: true,
      ));
      final client = ApiClient.instance;
      await client.initialize();
      expect(() async => await client.getDirections(origin: 'A', destination: 'B'), throwsA(isA<PinMismatchException>()));
    });
  });
}
