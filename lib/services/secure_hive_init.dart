import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:developer' as dev;

/// Secure Hive initialization service that handles encryption for sensitive data.
/// This service manages encryption keys and provides encrypted box opening.
class SecureHiveInit {
  static const String _encryptionKeyKey = 'hive_encryption_key';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  static HiveAesCipher? _cipher;
  static bool _initialized = false;
  
  /// Initialize Hive with encryption support.
  /// Must be called before opening any encrypted boxes.
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await Hive.initFlutter();
      
      // Get or generate encryption key
      final cipher = await _getOrCreateCipher();
      _cipher = cipher;
      _initialized = true;
      
      dev.log('Hive encryption initialized successfully', name: 'SecureHiveInit');
    } catch (e) {
      dev.log('Failed to initialize Hive encryption: $e', name: 'SecureHiveInit');
      rethrow;
    }
  }
  
  /// Get existing cipher or create a new one if it doesn't exist.
  static Future<HiveAesCipher> _getOrCreateCipher() async {
    try {
      // Try to read existing key
      String? keyString = await _secureStorage.read(key: _encryptionKeyKey);
      
      if (keyString == null) {
        dev.log('No encryption key found, generating new one', name: 'SecureHiveInit');
        // Generate new key
        final key = Hive.generateSecureKey();
        keyString = base64Encode(key);
        
        // Store it securely
        await _secureStorage.write(key: _encryptionKeyKey, value: keyString);
        dev.log('New encryption key generated and stored', name: 'SecureHiveInit');
      } else {
        dev.log('Using existing encryption key', name: 'SecureHiveInit');
      }
      
      // Create cipher from key
      final encryptionKey = base64Decode(keyString);
      return HiveAesCipher(encryptionKey);
    } catch (e) {
      dev.log('Error creating cipher: $e', name: 'SecureHiveInit');
      rethrow;
    }
  }
  
  /// Open a box with encryption.
  /// If the box exists unencrypted, it will be migrated to encrypted format.
  static Future<Box<T>> openEncryptedBox<T>(String name) async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      // Check if box exists
      final boxExists = await Hive.boxExists(name);
      
      if (boxExists) {
        // Try to open with encryption
        try {
          return await Hive.openBox<T>(name, encryptionCipher: _cipher);
        } catch (e) {
          // If it fails, it might be an unencrypted box - migrate it
          dev.log('Box $name appears to be unencrypted, migrating...', name: 'SecureHiveInit');
          return await _migrateToEncrypted<T>(name);
        }
      } else {
        // New box, open with encryption
        return await Hive.openBox<T>(name, encryptionCipher: _cipher);
      }
    } catch (e) {
      dev.log('Error opening encrypted box $name: $e', name: 'SecureHiveInit');
      rethrow;
    }
  }
  
  /// Migrate an unencrypted box to encrypted format.
  static Future<Box<T>> _migrateToEncrypted<T>(String name) async {
    try {
      dev.log('Starting migration of box $name to encrypted format', name: 'SecureHiveInit');
      
      // Open the unencrypted box
      final oldBox = await Hive.openBox<T>(name);
      
      // Read all data
      final Map<dynamic, T> allData = {};
      for (var key in oldBox.keys) {
        allData[key] = oldBox.get(key) as T;
      }
      
      dev.log('Read ${allData.length} entries from unencrypted box', name: 'SecureHiveInit');
      
      // Close and delete the old box
      await oldBox.close();
      await Hive.deleteBoxFromDisk(name);
      
      // Create new encrypted box
      final newBox = await Hive.openBox<T>(name, encryptionCipher: _cipher);
      
      // Write all data to encrypted box
      for (var entry in allData.entries) {
        await newBox.put(entry.key, entry.value);
      }
      
      dev.log('Successfully migrated ${allData.length} entries to encrypted box', name: 'SecureHiveInit');
      
      return newBox;
    } catch (e) {
      dev.log('Error migrating box $name: $e', name: 'SecureHiveInit');
      rethrow;
    }
  }
  
  /// Check if a box needs migration (exists but is not encrypted).
  static Future<bool> needsMigration(String name) async {
    try {
      if (!await Hive.boxExists(name)) {
        return false; // Box doesn't exist, no migration needed
      }
      
      // Try to open with encryption
      try {
        final box = await Hive.openBox(name, encryptionCipher: _cipher);
        await box.close();
        return false; // Already encrypted
      } catch (e) {
        // Failed to open with encryption, probably needs migration
        return true;
      }
    } catch (e) {
      dev.log('Error checking migration status for $name: $e', name: 'SecureHiveInit');
      return false;
    }
  }
  
  /// Get the encryption cipher for manual box operations.
  /// Only use this if you need direct control over box opening.
  static HiveAesCipher? get cipher {
    if (!_initialized) {
      dev.log('Warning: Cipher requested before initialization', name: 'SecureHiveInit');
    }
    return _cipher;
  }
}
