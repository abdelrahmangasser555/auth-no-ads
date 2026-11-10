import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

/// AES-256-GCM vault encryption.
/// Portable backups use Argon2id. On-device unlock mixes the PIN with a
/// Keystore-backed device key so a stolen file cannot be cracked from PIN alone.
class VaultCrypto {
  VaultCrypto({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  final AesGcm _aes = AesGcm.with256bits();

  static const argonMemory = 19 * 1024;
  static const argonIterations = 2;
  static const argonParallelism = 1;

  List<int> randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  Future<String> encryptUtf8({
    required String plaintext,
    required List<int> keyBytes,
  }) async {
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(keyBytes),
      nonce: _aes.newNonce(),
    );
    return jsonEncode({
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    });
  }

  Future<String> decryptUtf8({
    required String payload,
    required List<int> keyBytes,
  }) async {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final box = SecretBox(
      base64Decode(map['c'] as String),
      nonce: base64Decode(map['n'] as String),
      mac: Mac(base64Decode(map['m'] as String)),
    );
    final clear = await _aes.decrypt(box, secretKey: SecretKey(keyBytes));
    return utf8.decode(clear);
  }

  Future<List<int>> deriveBackupKey({
    required String password,
    required List<int> salt,
  }) async {
    final argon = Argon2id(
      parallelism: argonParallelism,
      memory: argonMemory,
      iterations: argonIterations,
      hashLength: 32,
    );
    final key = await argon.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  List<int> wrapKeyFromPin({
    required String pin,
    required List<int> deviceKey,
    required List<int> salt,
  }) {
    return sha256.convert([...utf8.encode(pin), ...deviceKey, ...salt]).bytes;
  }

  List<int> pinVerifier({
    required String pin,
    required List<int> deviceKey,
    required List<int> salt,
  }) {
    return sha256
        .convert([...utf8.encode('verify:$pin'), ...deviceKey, ...salt]).bytes;
  }

  bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
