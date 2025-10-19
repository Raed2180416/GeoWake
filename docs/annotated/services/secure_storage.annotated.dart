/// secure_storage.dart: Source file from lib/lib/services/secure_storage.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper to allow injection & test shimming.
abstract class SecureStorage {
  /// read: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<String?> read(String key);
  /// write: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> write(String key, String value);
  /// delete: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> delete(String key);
  /// containsKey: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<bool> containsKey(String key);
}

/// SecureStorageImpl: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class SecureStorageImpl implements SecureStorage {
  /// [Brief description of this field]
  final FlutterSecureStorage _inner;
  SecureStorageImpl({FlutterSecureStorage? inner}) : _inner = inner ?? const FlutterSecureStorage();
  @override
  /// read: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<String?> read(String key) => _inner.read(key: key);
  @override
  /// write: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> write(String key, String value) => _inner.write(key: key, value: value);
  @override
  /// delete: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> delete(String key) => _inner.delete(key: key);
  @override
  /// containsKey: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<bool> containsKey(String key) async => (await _inner.read(key: key)) != null;
}

/// In-memory fake for tests.
class InMemorySecureStorage implements SecureStorage {
  /// [Brief description of this field]
  final Map<String,String> _map = {};
  @override
  /// read: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<String?> read(String key) async => _map[key];
  @override
  /// write: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> write(String key, String value) async { _map[key] = value; }
  @override
  /// delete: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> delete(String key) async { _map.remove(key); }
  @override
  /// containsKey: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<bool> containsKey(String key) async => _map.containsKey(key);
  @visibleForTesting
  /// debugDump: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Map<String,String> debugDump() => Map.of(_map);
}
