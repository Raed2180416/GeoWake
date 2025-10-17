// lib/services/api_client.dart
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Removed direct dev.log usage; using Log utility instead
import 'package:geowake2/services/log.dart';
import 'package:geowake2/services/secure_storage.dart';
import 'package:geowake2/services/ssl_pinning.dart';

class ApiClient {
  static const String _baseUrl = 'https://geowake-production.up.railway.app/api'; // Fixed: Added https:// and /api
  static const String _tokenKey = 'geowake_api_token';
  static const String _deviceIdKey = 'geowake_device_id';
  
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._internal();
  static void resetForTests() { _instance = null; }
  static http.Client _client = http.Client();
  static void setHttpClient(http.Client client) { _client = client; }
  static List<CertificatePin> _pins = [];
  static List<CertificatePin> get debugConfiguredPins => List.unmodifiable(_pins);
  static void configureCertificatePins(List<CertificatePin> pins, {bool enabled = true, CertificatePinVerifier? verifier, PinEnforcer Function(CertificatePinVerifier v)? enforcerBuilder}) {
    _pins = pins;
    if (pins.isEmpty) return; // leave existing client
    final v = verifier ?? DefaultCertificatePinVerifier(pins);
    _client = PinnedHttpClientFactory.create(verifier: v, enabled: enabled, enforcerBuilder: enforcerBuilder);
  }
  static double authBackoffScaler = 1.0; // shrink backoff in tests
  static bool testMode = false; // When true, _makeRequest returns canned responses and records bodies
  static bool disableConnectionTest = false; // For tests: skip connectivity probe to avoid real HTTP
  // Test-only queued auth responses: each is a map {code:int, body:String}
  static final Queue<Map<String, dynamic>> _testAuthResponses = Queue();
  static int _testAuthCallCount = 0; // counts _doAuthenticate invocations in test queued mode
  static void enqueueTestAuthResponse(int code, String body) => _testAuthResponses.add({'code': code, 'body': body});
  static void clearTestAuthResponses() { _testAuthResponses.clear(); _testAuthCallCount = 0; }
  static int get debugTestAuthCallCount => _testAuthCallCount;
  static SecureStorage secureStorage = SecureStorageImpl();
  static void setSecureStorage(SecureStorage s) { secureStorage = s; }
  static Map<String, dynamic>? lastAutocompleteBody;
  static Map<String, dynamic>? lastPlaceDetailsBody;
  static Map<String, dynamic>? lastDirectionsBody;
  static int directionsCallCount = 0;
  
  ApiClient._internal();
  
  String? _authToken;
  String? _deviceId;
  DateTime? _tokenExpiration;
  Future<void>? _ongoingAuth; // guard concurrent refresh
  Duration? _tokenLifetime; // parsed lifetime
  static const Duration _maxEarlyRefreshWindow = Duration(minutes: 5);
  static const double _earlyRefreshFraction = 0.10; // 10% of lifetime
  int _authRetryCount = 0; // for exponential backoff
  
  /// Initialize the API client - call this on app startup
  Future<void> initialize() async {
  Log.i('ApiClient', 'Initializing ApiClient');
    // Prevent test mode in release builds
    assert(() {
      return true;
    }(), '');
    if (kReleaseMode) {
      testMode = false;
    }
    await _loadStoredCredentials();
    
    if (_authToken == null || _isTokenExpired()) {
      await _authenticate();
    }
    
    // Test connection (skippable for tests)
    if (!disableConnectionTest) {
      await testConnection();
    }
  }
  
  /// Test server connection
  Future<void> testConnection() async {
    try {
  Log.d('ApiClient', 'Testing connection to: $_baseUrl');
      final response = await _client.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
  Log.i('ApiClient', 'Server connection successful');
      } else {
  Log.w('ApiClient', 'Server responded with: ${response.statusCode}');
      }
    } catch (e) {
  Log.w('ApiClient', 'Server connection failed: $e');
      // Don't rethrow - connection test failure shouldn't break initialization
    }
  }
  
  /// Check if token is expired
  bool _isTokenExpired() {
    if (_tokenExpiration == null) return true;
  final now = DateTime.now();
    // Compute dynamic early refresh window (min of fraction * lifetime, max fixed window)
    Duration dynamicWindow;
    if (_tokenLifetime != null) {
      final fractionWindow = Duration(milliseconds: (_tokenLifetime!.inMilliseconds * _earlyRefreshFraction).round());
      dynamicWindow = fractionWindow < _maxEarlyRefreshWindow ? fractionWindow : _maxEarlyRefreshWindow;
    } else {
      dynamicWindow = _maxEarlyRefreshWindow; // default fallback
    }
    return now.isAfter(_tokenExpiration!.subtract(dynamicWindow));
  }
  
  /// Load stored token and device ID
  Future<void> _loadStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    // Migration path: prefer secure storage; if absent but present in prefs, migrate.
    final secureToken = await secureStorage.read(_tokenKey);
    if (secureToken != null) {
      _authToken = secureToken;
      // Even if already migrated earlier, ensure any lingering legacy key is removed now
      if (prefs.getString(_tokenKey) != null) {
        await prefs.remove(_tokenKey);
      }
    } else {
      final legacy = prefs.getString(_tokenKey);
      if (legacy != null) {
        await secureStorage.write(_tokenKey, legacy);
        _authToken = legacy;
        await prefs.remove(_tokenKey); // remove legacy token
      }
    }
    _deviceId = prefs.getString(_deviceIdKey);
    
    // Load token expiration if exists
    final expString = prefs.getString('${_tokenKey}_exp');
    if (expString != null) {
      _tokenExpiration = DateTime.tryParse(expString);
    }
  }
  
  /// Authenticate with server using bundle ID
  Future<void> _authenticate() async {
    // In test mode without queued responses, avoid real HTTP auth; seed dummy token if missing
    if (testMode && _testAuthResponses.isEmpty) {
      if (_authToken == null) {
        _authToken = 'test-token';
        _tokenLifetime = const Duration(hours: 1);
        _tokenExpiration = DateTime.now().add(_tokenLifetime!);
        await _saveCredentials(rawExpires: '3600s');
      }
      return;
    }
    // Coalesce concurrent calls
    if (_ongoingAuth != null) {
  Log.d('ApiClient', 'Auth already in progress; awaiting existing future');
      return _ongoingAuth;
    }
    _ongoingAuth = _doAuthenticate();
    try {
      await _ongoingAuth;
    } finally {
      _ongoingAuth = null;
    }
  }

  Future<void> _doAuthenticate() async {
    try {
  Log.d('ApiClient', 'Authenticating with server');
      http.Response response;
      if (_testAuthResponses.isNotEmpty) {
        // Test queued mode
        _testAuthCallCount += 1;
        final plan = _testAuthResponses.removeFirst();
        response = http.Response(plan['body'] as String, plan['code'] as int);
      } else {
        response = await _client.post(
          Uri.parse('$_baseUrl/auth/token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'bundleId': 'com.yourcompany.geowake2',
          }),
        ).timeout(const Duration(seconds: 15));
      }
      
  Log.d('ApiClient', 'Auth response status: ${response.statusCode}');
      if (!kReleaseMode) {
  Log.d('ApiClient', 'Auth response body (redacted)');
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _authToken = data['token'];
          final rawExpires = data['expiresIn'];
          final lifetime = _parseExpiresIn(rawExpires) ?? const Duration(hours: 24);
          _tokenLifetime = lifetime;
          _tokenExpiration = DateTime.now().add(lifetime);
          _authRetryCount = 0; // reset retry counter on success
          await _saveCredentials(rawExpires: rawExpires);
          Log.i('ApiClient', 'Authentication successful lifetime=${lifetime.inSeconds}s');
        } else {
          throw Exception('Authentication failed: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, st) {
  Log.w('ApiClient', 'Authentication failed: $e');
      Log.e('ApiClient', 'Authentication failure', e, st);
      // exponential backoff with jitter for transient failures up to 5 tries
      if (_authRetryCount < 5) {
        _authRetryCount += 1;
        final baseDelayMs = (1 << (_authRetryCount - 1)) * 500; // 500,1000,2000,4000,8000
        final jitterMs = (baseDelayMs * 0.2).toInt();
        int computed = baseDelayMs + _randomJitter(jitterMs);
        if (authBackoffScaler != 1.0) computed = (computed * authBackoffScaler).round();
        final delay = Duration(milliseconds: computed);
  Log.d('ApiClient', 'Auth retry #$_authRetryCount in ${delay.inMilliseconds}ms');
        if (delay.inMilliseconds > 0) await Future.delayed(delay);
        return _doAuthenticate();
      }
      rethrow;
    }
  }
  
  /// Save credentials to local storage
  Future<void> _saveCredentials({dynamic rawExpires}) async {
    final prefs = await SharedPreferences.getInstance();
    if (_authToken != null) {
      await secureStorage.write(_tokenKey, _authToken!);
      // Remove legacy copy if lingering
      await prefs.remove(_tokenKey);
    }
    if (_deviceId != null) await prefs.setString(_deviceIdKey, _deviceId!);
    if (_tokenExpiration != null) {
      await prefs.setString('${_tokenKey}_exp', _tokenExpiration!.toIso8601String());
    }
    if (rawExpires != null) {
      await prefs.setString('${_tokenKey}_raw_expires', rawExpires.toString());
    }
  }

  // Parse expiresIn formats like '24h', '3600s', '15m', plain seconds int, or ISO8601 duration (subset)
  Duration? _parseExpiresIn(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return Duration(seconds: raw);
    if (raw is String) {
      final s = raw.trim();
      final intMatch = int.tryParse(s);
      if (intMatch != null) return Duration(seconds: intMatch);
  final unitMatch = RegExp(r'^(\d+)([smhd])$').firstMatch(s);
      if (unitMatch != null) {
        final v = int.parse(unitMatch.group(1)!);
        switch (unitMatch.group(2)) {
          case 's': return Duration(seconds: v);
          case 'm': return Duration(minutes: v);
          case 'h': return Duration(hours: v);
          case 'd': return Duration(days: v);
        }
      }
      // Basic ISO8601 duration like PT24H
  final iso = RegExp(r'^P(T)?(\d+H)?(\d+M)?(\d+S)?').firstMatch(s.toUpperCase());
      if (iso != null) {
        int hours = 0, minutes = 0, seconds = 0;
        final hMatch = RegExp(r'(\\d+)H').firstMatch(s.toUpperCase());
        if (hMatch != null) hours = int.parse(hMatch.group(1)!);
        final mMatch = RegExp(r'(\\d+)M').firstMatch(s.toUpperCase());
        if (mMatch != null) minutes = int.parse(mMatch.group(1)!);
        final secMatch = RegExp(r'(\\d+)S').firstMatch(s.toUpperCase());
        if (secMatch != null) seconds = int.parse(secMatch.group(1)!);
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    }
    return null; // unknown format
  }

  int _randomJitter(int max) {
    if (max <= 0) return 0;
    // simple LCG-based jitter without importing dart:math Random (stay lightweight)
    final micros = DateTime.now().microsecondsSinceEpoch;
    return (micros % max);
  }
  
  /// Build headers with authentication
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }
  
  /// Make authenticated API request with auto-retry on auth failure
  Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      // Test mode: short-circuit HTTP and return canned payloads
      if (testMode) {
        // Record bodies for verification
        if (endpoint.contains('/maps/autocomplete')) {
          lastAutocompleteBody = body != null ? Map<String, dynamic>.from(body) : {};
          return {
            'predictions': [
              {
                'description': 'Test Place',
                'place_id': 'test_place_id',
              }
            ],
            'status': 'OK'
          };
        }
        if (endpoint.contains('/maps/place-details')) {
          lastPlaceDetailsBody = body != null ? Map<String, dynamic>.from(body) : {};
          return {
            'result': {
              'name': 'Test Place',
              'geometry': {
                'location': {'lat': 12.34, 'lng': 56.78}
              },
              'formatted_address': '123 Test St'
            },
            'status': 'OK'
          };
        }
        if (endpoint.contains('/maps/directions')) {
          lastDirectionsBody = body != null ? Map<String, dynamic>.from(body) : {};
          directionsCallCount++;
          // Minimal directions payload
          return {
            'routes': [
              {
                'overview_polyline': {'points': '}_se}Ff`miO??'},
                'legs': [
                  {
                    'steps': [],
                    'duration': {'value': 600}
                  }
                ]
              }
            ],
            'status': 'OK'
          };
        }
        // Default canned OK
        return {'status': 'OK'};
      }
      // Ensure we have a valid token
      if (_authToken == null || _isTokenExpired()) {
  Log.d('ApiClient', 'Token missing or expired, authenticating');
        await _authenticate();
      }
      
      Uri uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      
    Log.d('ApiClient', 'Making ${method.toUpperCase()} request to: $uri');
      
      late http.Response response;
      final headers = _buildHeaders();
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(const Duration(seconds: 15));
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
      
  Log.d('ApiClient', 'Response status: ${response.statusCode}');
      if (!kReleaseMode) {
        final preview = response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body;
  Log.d('ApiClient', 'Response body preview (redacted in release): $preview');
      }
      
      // Handle token expiration
      if (response.statusCode == 401) {
  Log.d('ApiClient', 'Token expired (401), re-authenticating');
        await _authenticate(); // guarded
        
        // Retry the request with new token
        headers['Authorization'] = 'Bearer $_authToken';
        switch (method.toUpperCase()) {
          case 'GET':
            response = await _client.get(uri, headers: headers);
            break;
          case 'POST':
            response = await _client.post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
        }
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, st) {
  Log.w('ApiClient', 'API request failed: $e');
      Log.e('ApiClient', 'Request failed $endpoint', e, st);
      rethrow;
    }
  }
  
  // ================================
  // GOOGLE MAPS API METHODS
  // ================================
  
  /// Get directions between two points
  Future<Map<String, dynamic>> getDirections({
    required String origin,
    required String destination,
    String mode = 'driving',
    String? transitMode,
  }) async {
  Log.d('ApiClient', 'Get directions $origin -> $destination');
    
    final body = <String, dynamic>{
      'origin': origin,
      'destination': destination,
      'mode': mode,
      if (transitMode != null) 'transit_mode': transitMode,
    };
    
    final result = await _makeRequest('POST', '/maps/directions', body: body); // Fixed: Changed to POST
    return result; // Return the full result, not just 'data' field
  }
  
  /// Get autocomplete suggestions
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions({
    required String input,
    String? location,
    String? components,
    String? sessionToken,
  }) async {
  Log.d('ApiClient', 'Autocomplete input="$input"');
    
    final body = <String, dynamic>{
      'input': input,
      if (location != null) 'location': location,
      if (components != null) 'components': components,
      if (sessionToken != null) 'sessiontoken': sessionToken,
    };
    
    final result = await _makeRequest('POST', '/maps/autocomplete', body: body); // Fixed: Changed to POST
    
    // Handle the response structure from your server
    if (result['predictions'] != null) {
      final predictions = result['predictions'] as List;
      return predictions.map((p) => p as Map<String, dynamic>).toList();
    }
    
    return [];
  }
  
  /// Get place details
  Future<Map<String, dynamic>?> getPlaceDetails({
    required String placeId,
    String? sessionToken,
  }) async {
  Log.d('ApiClient', 'Place details placeId=$placeId');
    
    final body = <String, String>{
      'place_id': placeId,
      if (sessionToken != null) 'sessiontoken': sessionToken,
    };
    
    final result = await _makeRequest('POST', '/maps/place-details', body: body); // Fixed: Changed to POST
    
    // Handle the response structure from your server
    return result['result'] ?? result;
  }
  
  /// Get nearby transit stations
  Future<List<Map<String, dynamic>>> getNearbyTransitStations({
    required String location,
    String radius = '500',
  }) async {
  Log.d('ApiClient', 'Nearby transit stations at: $location');
    
    final body = <String, dynamic>{
      'location': location,
      'radius': radius,
      'type': 'transit_station',
    };
    
    final result = await _makeRequest('POST', '/maps/nearby-search', body: body); // Fixed: Changed to POST
    
    // Handle the response structure from your server
    if (result['results'] != null) {
      final results = result['results'] as List;
      return results.map((r) => r as Map<String, dynamic>).toList();
    }
    
    return [];
  }
  
  /// Get geocoding results
  Future<Map<String, dynamic>?> geocode({
    required String latlng,
  }) async {
  Log.d('ApiClient', 'Geocoding latlng=$latlng');
    
    final body = <String, String>{
      'address': latlng, // Note: server expects 'address' parameter for geocoding
    };
    
    final result = await _makeRequest('POST', '/maps/geocode', body: body);
    
    // Handle the response structure
    if (result['results'] != null && (result['results'] as List).isNotEmpty) {
      return (result['results'] as List).first;
    }
    
    return null;
  }
}