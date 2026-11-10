import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecretKv {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FlutterSecretKv implements SecretKv {
  FlutterSecretKv([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// In-memory vault for tests. Never used on a real device.
class MemorySecretKv implements SecretKv {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}
