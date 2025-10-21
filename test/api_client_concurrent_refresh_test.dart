@Tags(['serial'])
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/services/secure_storage.dart';

class _FakeClient extends http.BaseClient {
  int authCalls = 0;
  int directionsCalls = 0;
  // Pre-planned auth responses
  final List<Map<String, dynamic>> authPlan; // each: {token:String, expiresIn:String}
  _FakeClient(this.authPlan);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url.toString();
    if (uri.endsWith('/auth/token')) {
      if (authPlan.isEmpty) {
        return http.StreamedResponse(Stream.value(utf8.encode('{"error":"no-plan"}')), 500);
      }
      authCalls += 1;
      final next = authPlan.removeAt(0);
      final body = jsonEncode({'success': true, 'token': next['token'], 'expiresIn': next['expiresIn']});
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
    }
    if (uri.contains('/maps/directions')) {
      directionsCalls += 1;
      final body = jsonEncode({
        'routes': [
          {
            'overview_polyline': {'points': '}_se}Ff`miO??'},
            'legs': [
              {
                'steps': [],
                'duration': {'value': 120}
              }
            ]
          }
        ],
        'status': 'OK'
      });
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
    }
    if (uri.endsWith('/health')) {
      // connection test
      return http.StreamedResponse(Stream.value(utf8.encode('OK')), 200);
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{"status":"OK"}')), 200);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient concurrent refresh (real auth path, fake HTTP)', () {
    late _FakeClient fake;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ApiClient.resetForTests();
      ApiClient.clearTestAuthResponses(); // not used here
      ApiClient.testMode = false; // exercise real path
      ApiClient.disableConnectionTest = true; // avoid extra /health noise
      ApiClient.setSecureStorage(InMemorySecureStorage());
    });

    test('Parallel first-burst requests do not trigger multiple auth attempts', () async {
      fake = _FakeClient([
        {'token': 'conc1', 'expiresIn': '30s'},
      ]);
      ApiClient.setHttpClient(fake);
      final client = ApiClient.instance;
      // Explicitly initialize to ensure a single auth happens deterministically
      await client.initialize();
      expect(fake.authCalls, 1, reason: 'Single auth during initialize');

      // Launch N parallel requests which should reuse existing token (still valid)
      const int N = 25;
      final futures = List.generate(N, (i) => client.getDirections(origin: '0,0', destination: '1,1'));
      await Future.wait(futures);
      expect(fake.authCalls, 1, reason: 'No extra auth calls while token valid');
    });

    test('Token expiry triggers only one refresh across burst', () async {
      // First very short lifetime, second longer
      fake = _FakeClient([
        {'token': 't_short', 'expiresIn': '1s'},
        {'token': 't_long', 'expiresIn': '60s'},
      ]);
      ApiClient.setHttpClient(fake);
      final client = ApiClient.instance;
      await client.initialize(); // seeds t_short
      expect(fake.authCalls, 1, reason: 'Initial auth');
      // Allow short token to enter refresh window / expire
      await Future.delayed(const Duration(milliseconds: 1200));
      const int M = 15;
      final reqs = List.generate(M, (_) => client.getDirections(origin: '0,0', destination: '2,2'));
      await Future.wait(reqs);
      expect(fake.authCalls, 2, reason: 'Exactly one additional auth (refresh) expected');
    });
  });
}
