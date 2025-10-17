import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper to allow injection & test shimming.
abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<bool> containsKey(String key);
}

class SecureStorageImpl implements SecureStorage {
  final FlutterSecureStorage _inner;
  SecureStorageImpl({FlutterSecureStorage? inner}) : _inner = inner ?? const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _inner.read(key: key);
  @override
  Future<void> write(String key, String value) => _inner.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _inner.delete(key: key);
  @override
  Future<bool> containsKey(String key) async => (await _inner.read(key: key)) != null;
}

/// In-memory fake for tests.
class InMemorySecureStorage implements SecureStorage {
  final Map<String,String> _map = {};
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async { _map[key] = value; }
  @override
  Future<void> delete(String key) async { _map.remove(key); }
  @override
  Future<bool> containsKey(String key) async => _map.containsKey(key);
  @visibleForTesting
  Map<String,String> debugDump() => Map.of(_map);
}
