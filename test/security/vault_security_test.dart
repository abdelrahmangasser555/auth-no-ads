import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/crypto/vault_crypto.dart';
import 'package:safeauth/core/models/models.dart';
import 'package:safeauth/core/services/secret_kv.dart';
import 'package:safeauth/core/services/vault_store.dart';

void main() {
  late VaultStore store;
  late MemorySecretKv kv;
  late VaultCrypto crypto;

  setUp(() {
    kv = MemorySecretKv();
    crypto = VaultCrypto();
    store = VaultStore(kv: kv, crypto: crypto);
  });

  test('rejects PINs that are not exactly 6 digits', () async {
    await expectLater(store.createVault(pin: '123'), throwsFormatException);
    await expectLater(store.createVault(pin: 'abcdef'), throwsFormatException);
    await expectLater(store.createVault(pin: '1234567'), throwsFormatException);
    await expectLater(store.createVault(pin: ''), throwsFormatException);
  });

  test('wrong PIN never returns the master key', () async {
    await store.createVault(pin: '259200');
    await expectLater(store.unlockWithPin('000000'), throwsA(isA<VaultAuthFailed>()));
    final master = await store.unlockWithPin('259200');
    expect(master.length, 32);
  });

  test('lockout after five failed PIN attempts', () async {
    await store.createVault(pin: '259200');
    for (var i = 0; i < 5; i++) {
      await expectLater(
        store.unlockWithPin('111111'),
        throwsA(isA<VaultAuthFailed>()),
      );
    }
    await expectLater(
      store.unlockWithPin('111111'),
      throwsA(isA<VaultLockedOut>()),
    );
    await expectLater(
      store.unlockWithPin('259200'),
      throwsA(isA<VaultLockedOut>()),
    );
  });

  test('correct PIN after failures under five still unlocks', () async {
    await store.createVault(pin: '259200');
    await expectLater(store.unlockWithPin('111111'), throwsA(isA<VaultAuthFailed>()));
    await expectLater(store.unlockWithPin('111111'), throwsA(isA<VaultAuthFailed>()));
    final master = await store.unlockWithPin('259200');
    expect(master, isNotEmpty);
  });

  test('changing PIN keeps the same vault contents', () async {
    await store.createVault(pin: '259200');
    final master = await store.unlockWithPin('259200');
    final vault = VaultData()
      ..accounts.add(
        TotpAccount.create(
          issuer: 'GitHub',
          label: 'me',
          secret: 'JBSWY3DPEHPK3PXP',
        ),
      );
    await store.persist(vault, master);
    await store.changePin('259200', '462625');
    await expectLater(store.unlockWithPin('259200'), throwsA(isA<VaultAuthFailed>()));
    final next = await store.unlockWithPin('462625');
    final loaded = await store.load(next);
    expect(loaded.accounts.single.issuer, 'GitHub');
    expect(loaded.accounts.single.secret, 'JBSWY3DPEHPK3PXP');
  });

  test('PIN wrap is bound to the device key', () {
    final deviceA = crypto.randomBytes(32);
    final deviceB = crypto.randomBytes(32);
    final salt = crypto.randomBytes(16);
    final a = crypto.wrapKeyFromPin(pin: '259200', deviceKey: deviceA, salt: salt);
    final b = crypto.wrapKeyFromPin(pin: '259200', deviceKey: deviceB, salt: salt);
    expect(crypto.constantTimeEquals(a, b), isFalse);
  });

  test('verifier is not the wrap key', () {
    final device = crypto.randomBytes(32);
    final salt = crypto.randomBytes(16);
    final wrap = crypto.wrapKeyFromPin(pin: '259200', deviceKey: device, salt: salt);
    final verify = crypto.pinVerifier(pin: '259200', deviceKey: device, salt: salt);
    expect(crypto.constantTimeEquals(wrap, verify), isFalse);
  });

  test('constant-time compare rejects different lengths', () {
    expect(crypto.constantTimeEquals([1, 2], [1]), isFalse);
    expect(crypto.constantTimeEquals([], [0]), isFalse);
    expect(crypto.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
  });

  test('encrypting twice produces different ciphertext (fresh nonce)', () async {
    final key = crypto.randomBytes(32);
    const msg = 'same plaintext';
    final a = await crypto.encryptUtf8(plaintext: msg, keyBytes: key);
    final b = await crypto.encryptUtf8(plaintext: msg, keyBytes: key);
    expect(a, isNot(b));
    expect(await crypto.decryptUtf8(payload: a, keyBytes: key), msg);
    expect(await crypto.decryptUtf8(payload: b, keyBytes: key), msg);
  });

  test('tampered ciphertext fails closed', () async {
    final key = crypto.randomBytes(32);
    final packed = await crypto.encryptUtf8(plaintext: 'vault', keyBytes: key);
    final map = jsonDecode(packed) as Map<String, dynamic>;
    final c = base64Decode(map['c'] as String);
    c[0] = c[0] ^ 0xff;
    map['c'] = base64Encode(c);
    await expectLater(
      crypto.decryptUtf8(payload: jsonEncode(map), keyBytes: key),
      throwsA(anything),
    );
  });

  test('tampered GCM tag fails closed', () async {
    final key = crypto.randomBytes(32);
    final packed = await crypto.encryptUtf8(plaintext: 'vault', keyBytes: key);
    final map = jsonDecode(packed) as Map<String, dynamic>;
    final m = base64Decode(map['m'] as String);
    m[0] = m[0] ^ 0xff;
    map['m'] = base64Encode(m);
    await expectLater(
      crypto.decryptUtf8(payload: jsonEncode(map), keyBytes: key),
      throwsA(anything),
    );
  });

  test('vault blob is not stored as plaintext JSON', () async {
    await store.createVault(pin: '259200');
    final master = await store.unlockWithPin('259200');
    await store.persist(
      VaultData()
        ..accounts.add(
          TotpAccount.create(
            issuer: 'GitHub',
            label: 'secret-user',
            secret: 'JBSWY3DPEHPK3PXP',
          ),
        ),
      master,
    );
    final blob = kv.data.values.join(' | ');
    expect(blob.contains('JBSWY3DPEHPK3PXP'), isFalse);
    expect(blob.contains('secret-user'), isFalse);
  });

  test('biometric unwrap uses the device key, not the PIN wrap', () async {
    await store.createVault(pin: '259200');
    final fromPin = await store.unlockWithPin('259200');
    final fromBio = await store.unlockWithBiometrics();
    expect(fromBio, fromPin);
  });
}
