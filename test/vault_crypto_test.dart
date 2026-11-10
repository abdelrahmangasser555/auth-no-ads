import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/crypto/password_generator.dart';
import 'package:safeauth/core/crypto/vault_crypto.dart';

void main() {
  test('AES-256-GCM roundtrip', () async {
    final crypto = VaultCrypto();
    final key = crypto.randomBytes(32);
    const message = '{"accounts":[]}';
    final packed = await crypto.encryptUtf8(plaintext: message, keyBytes: key);
    final out = await crypto.decryptUtf8(payload: packed, keyBytes: key);
    expect(out, message);
  });

  test('wrong key fails closed', () async {
    final crypto = VaultCrypto();
    final packed = await crypto.encryptUtf8(
      plaintext: 'secret',
      keyBytes: crypto.randomBytes(32),
    );
    expect(
      crypto.decryptUtf8(payload: packed, keyBytes: crypto.randomBytes(32)),
      throwsA(anything),
    );
  });

  test('PIN wrapping is deterministic and device-bound', () {
    final crypto = VaultCrypto();
    final device = crypto.randomBytes(32);
    final salt = crypto.randomBytes(16);
    final a = crypto.wrapKeyFromPin(pin: '259200', deviceKey: device, salt: salt);
    final b = crypto.wrapKeyFromPin(pin: '259200', deviceKey: device, salt: salt);
    final c = crypto.wrapKeyFromPin(pin: '000000', deviceKey: device, salt: salt);
    expect(a, b);
    expect(crypto.constantTimeEquals(a, c), isFalse);
  });

  test('password generator meets length and class rules', () {
    final password = PasswordGenerator().generate(length: 20);
    expect(password.length, 20);
    expect(password.contains(RegExp(r'[A-Z]')), isTrue);
    expect(password.contains(RegExp(r'[a-z]')), isTrue);
    expect(password.contains(RegExp(r'[0-9]')), isTrue);
  });
}
