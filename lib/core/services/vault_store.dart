import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../crypto/vault_crypto.dart';
import '../models/models.dart';
import 'io_support.dart' if (dart.library.html) 'io_support_web.dart';
import 'secret_kv.dart';

class VaultStore {
  VaultStore({
    SecretKv? kv,
    VaultCrypto? crypto,
  })  : _kv = kv ?? FlutterSecretKv(),
        _crypto = crypto ?? VaultCrypto();

  final SecretKv _kv;
  final VaultCrypto _crypto;

  bool get _memoryOnly => _kv is MemorySecretKv;

  static const _kDeviceKey = 'device_key';
  static const _kPinSalt = 'pin_salt';
  static const _kPinVerifier = 'pin_verifier';
  static const _kWrappedPin = 'wrapped_master_pin';
  static const _kWrappedBio = 'wrapped_master_bio';
  static const _kLockoutUntil = 'lockout_until';
  static const _kFailCount = 'fail_count';
  static const _kHasVault = 'has_vault';
  static const _kWebVault = 'web_vault_blob';

  bool get isWeb => kIsWeb;

  Future<bool> hasVault() async {
    return (await _kv.read(_kHasVault)) == '1';
  }

  Future<Duration?> lockoutRemaining() async {
    final raw = await _kv.read(_kLockoutUntil);
    if (raw == null) return null;
    final until = DateTime.tryParse(raw);
    if (until == null) return null;
    final left = until.difference(DateTime.now().toUtc());
    return left.isNegative ? null : left;
  }

  Future<void> createVault({required String pin}) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const FormatException('PIN must be exactly 6 digits');
    }
    final deviceKey = _crypto.randomBytes(32);
    final salt = _crypto.randomBytes(16);
    final master = _crypto.randomBytes(32);
    await _kv.write(_kDeviceKey, base64Encode(deviceKey));
    await _kv.write(_kPinSalt, base64Encode(salt));
    await _kv.write(
      _kPinVerifier,
      base64Encode(
        _crypto.pinVerifier(pin: pin, deviceKey: deviceKey, salt: salt),
      ),
    );
    final wrap = _crypto.wrapKeyFromPin(pin: pin, deviceKey: deviceKey, salt: salt);
    await _kv.write(
      _kWrappedPin,
      await _crypto.encryptUtf8(
        plaintext: base64Encode(master),
        keyBytes: wrap,
      ),
    );
    await _kv.write(
      _kWrappedBio,
      await _crypto.encryptUtf8(
        plaintext: base64Encode(master),
        keyBytes: deviceKey,
      ),
    );
    await _kv.write(_kHasVault, '1');
    await _kv.write(_kFailCount, '0');
    await persist(VaultData(), master);
  }

  Future<List<int>> unlockWithPin(String pin) async {
    final lockout = await lockoutRemaining();
    if (lockout != null) {
      throw VaultLockedOut(lockout);
    }
    final deviceKey = base64Decode(await _need(_kDeviceKey));
    final salt = base64Decode(await _need(_kPinSalt));
    final verifier = base64Decode(await _need(_kPinVerifier));
    final expected = _crypto.pinVerifier(pin: pin, deviceKey: deviceKey, salt: salt);
    if (!_crypto.constantTimeEquals(verifier, expected)) {
      await _registerFailure();
      throw const VaultAuthFailed();
    }
    await _kv.write(_kFailCount, '0');
    final wrap = _crypto.wrapKeyFromPin(pin: pin, deviceKey: deviceKey, salt: salt);
    final wrapped = await _need(_kWrappedPin);
    final masterB64 = await _crypto.decryptUtf8(payload: wrapped, keyBytes: wrap);
    return base64Decode(masterB64);
  }

  Future<List<int>> unlockWithBiometrics() async {
    final deviceKey = base64Decode(await _need(_kDeviceKey));
    final wrapped = await _need(_kWrappedBio);
    final masterB64 =
        await _crypto.decryptUtf8(payload: wrapped, keyBytes: deviceKey);
    return base64Decode(masterB64);
  }

  Future<void> changePin(String currentPin, String nextPin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(nextPin)) {
      throw const FormatException('PIN must be exactly 6 digits');
    }
    final master = await unlockWithPin(currentPin);
    final deviceKey = base64Decode(await _need(_kDeviceKey));
    final salt = _crypto.randomBytes(16);
    await _kv.write(_kPinSalt, base64Encode(salt));
    await _kv.write(
      _kPinVerifier,
      base64Encode(
        _crypto.pinVerifier(pin: nextPin, deviceKey: deviceKey, salt: salt),
      ),
    );
    final wrap =
        _crypto.wrapKeyFromPin(pin: nextPin, deviceKey: deviceKey, salt: salt);
    await _kv.write(
      _kWrappedPin,
      await _crypto.encryptUtf8(
        plaintext: base64Encode(master),
        keyBytes: wrap,
      ),
    );
  }

  Future<VaultData> load(List<int> master) async {
    final blob = await _readBlob();
    if (blob == null || blob.isEmpty) return VaultData();
    final json = await _crypto.decryptUtf8(payload: blob, keyBytes: master);
    return VaultData.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> persist(VaultData data, List<int> master) async {
    final blob = await _crypto.encryptUtf8(
      plaintext: jsonEncode(data.toJson()),
      keyBytes: master,
    );
    await _writeBlob(blob);
  }

  Future<String> exportBackup({
    required VaultData data,
    required String password,
  }) async {
    if (password.length < 8) {
      throw const FormatException('Backup password must be at least 8 characters');
    }
    final salt = _crypto.randomBytes(16);
    final key = await _crypto.deriveBackupKey(password: password, salt: salt);
    final inner = await _crypto.encryptUtf8(
      plaintext: jsonEncode(data.toJson()),
      keyBytes: key,
    );
    return jsonEncode({
      'format': 'safeauth.backup.v1',
      'salt': base64Encode(salt),
      'kdf': 'argon2id',
      'payload': inner,
    });
  }

  Future<VaultData> importBackup({
    required String file,
    required String password,
  }) async {
    final map = jsonDecode(file) as Map<String, dynamic>;
    if (map['format'] != 'safeauth.backup.v1') {
      throw const FormatException('Not an Auth No Ads backup');
    }
    final salt = base64Decode(map['salt'] as String);
    final key = await _crypto.deriveBackupKey(password: password, salt: salt);
    final json = await _crypto.decryptUtf8(
      payload: map['payload'] as String,
      keyBytes: key,
    );
    return VaultData.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> _registerFailure() async {
    final n = int.tryParse(await _kv.read(_kFailCount) ?? '0') ?? 0;
    final next = n + 1;
    await _kv.write(_kFailCount, '$next');
    if (next >= 5) {
      final seconds = 30 * (1 << (next - 5).clamp(0, 4));
      final until = DateTime.now().toUtc().add(Duration(seconds: seconds));
      await _kv.write(_kLockoutUntil, until.toIso8601String());
    }
  }

  Future<String> _need(String key) async {
    final value = await _kv.read(key);
    if (value == null || value.isEmpty) {
      throw const VaultCorrupt();
    }
    return value;
  }

  Future<String?> _readBlob() async {
    if (kIsWeb || _memoryOnly) return _kv.read(_kWebVault);
    final dir = await getApplicationSupportDirectory();
    return readVaultFile(joinPath(dir.path, 'vault.safeauth'));
  }

  Future<void> _writeBlob(String blob) async {
    if (kIsWeb || _memoryOnly) {
      await _kv.write(_kWebVault, blob);
      return;
    }
    final dir = await getApplicationSupportDirectory();
    await writeVaultFile(joinPath(dir.path, 'vault.safeauth'), blob);
  }
}

class VaultAuthFailed implements Exception {
  const VaultAuthFailed();
}

class VaultCorrupt implements Exception {
  const VaultCorrupt();
}

class VaultLockedOut implements Exception {
  const VaultLockedOut(this.remaining);
  final Duration remaining;
}
