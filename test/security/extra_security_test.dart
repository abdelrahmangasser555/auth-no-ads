import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/crypto/base32.dart';
import 'package:safeauth/core/crypto/otp_engine.dart';
import 'package:safeauth/core/crypto/otpauth_parser.dart';
import 'package:safeauth/core/crypto/vault_crypto.dart';
import 'package:safeauth/core/models/models.dart';
import 'package:safeauth/core/services/secret_kv.dart';
import 'package:safeauth/core/services/vault_store.dart';
import 'package:safeauth/state/app_controller.dart';

import '../helpers.dart';

void main() {
  const engine = OtpEngine();
  const parser = OtpAuthParser();

  test('RFC 6238 SHA512 8-digit vectors', () {
    final secret =
        ascii.encode('1234567890123456789012345678901234567890123456789012345678901234');
    const vectors = <int, String>{
      59: '90693936',
      1111111109: '25091201',
      1111111111: '99943326',
      1234567890: '93441116',
      2000000000: '38618901',
    };
    for (final entry in vectors.entries) {
      final time = DateTime.fromMillisecondsSinceEpoch(
        entry.key * 1000,
        isUtc: true,
      );
      expect(
        engine.totp(
          secret: secret,
          time: time,
          digits: 8,
          period: 30,
          algorithm: 'SHA512',
        ),
        entry.value,
      );
    }
  });

  test('unknown HMAC algorithm falls back to SHA1 instead of a weak hash', () {
    final secret = ascii.encode('12345678901234567890');
    final time = DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true);
    expect(
      engine.totp(
        secret: secret,
        time: time,
        digits: 8,
        algorithm: 'MD5',
      ),
      engine.totp(
        secret: secret,
        time: time,
        digits: 8,
        algorithm: 'SHA1',
      ),
    );
  });

  test('parser rejects file, ftp, and javascript URIs', () {
    expect(() => parser.parse('file:///etc/passwd'), throwsFormatException);
    expect(() => parser.parse('ftp://evil.test/otp'), throwsFormatException);
    expect(() => parser.parse('otpauth://totp/'), throwsFormatException);
  });

  test('parser clamps unknown algorithms and negative HOTP counters', () {
    final draft = parser.parse(
      'otpauth://hotp/GitHub:me?secret=JBSWY3DPEHPK3PXP&algorithm=MD5&counter=-9',
    );
    expect(draft.algorithm, 'SHA1');
    expect(draft.counter, 0);
    expect(draft.type, 'hotp');
  });

  test('parser accepts SHA256 and SHA-512 names', () {
    expect(
      parser
          .parse(
            'otpauth://totp/X:y?secret=JBSWY3DPEHPK3PXP&algorithm=SHA256',
          )
          .algorithm,
      'SHA256',
    );
    expect(
      parser
          .parse(
            'otpauth://totp/X:y?secret=JBSWY3DPEHPK3PXP&algorithm=SHA-512',
          )
          .algorithm,
      'SHA512',
    );
  });

  test('Base32 rejects oversized secrets', () {
    expect(Base32.isValid('A' * 129), isFalse);
    expect(() => Base32.decode('A' * 129), throwsFormatException);
  });

  test('wrong master key cannot decrypt the vault blob', () async {
    final store = VaultStore(kv: MemorySecretKv());
    await store.createVault(pin: '259200');
    final master = await store.unlockWithPin('259200');
    await store.persist(
      VaultData()
        ..accounts.add(
          TotpAccount.create(
            issuer: 'GitHub',
            label: 'me',
            secret: 'JBSWY3DPEHPK3PXP',
          ),
        ),
      master,
    );
    final evil = List<int>.from(master);
    evil[0] = evil[0] ^ 0xff;
    await expectLater(store.load(evil), throwsA(anything));
  });

  test('invalid next PIN leaves the current PIN working', () async {
    final store = VaultStore(kv: MemorySecretKv());
    await store.createVault(pin: '259200');
    await expectLater(store.changePin('259200', '12'), throwsFormatException);
    final master = await store.unlockWithPin('259200');
    expect(master.length, 32);
  });

  test('PIN with spaces or letters is rejected', () async {
    final store = VaultStore(kv: MemorySecretKv());
    await expectLater(store.createVault(pin: '259 200'), throwsFormatException);
    await expectLater(store.createVault(pin: '25920a'), throwsFormatException);
    await expectLater(store.createVault(pin: '259200\n'), throwsFormatException);
  });

  test('leading-zero PIN is a real 6-digit PIN', () async {
    final store = VaultStore(kv: MemorySecretKv());
    await store.createVault(pin: '000001');
    expect(await store.unlockWithPin('000001'), isNotEmpty);
    await expectLater(store.unlockWithPin('000000'), throwsA(isA<VaultAuthFailed>()));
  });

  test('backup missing salt or payload fails closed', () async {
    final store = VaultStore(kv: MemorySecretKv());
    await expectLater(
      store.importBackup(
        file: jsonEncode({'format': 'safeauth.backup.v1'}),
        password: 'correct-horse',
      ),
      throwsA(anything),
    );
  });

  test('lock zeroes the in-memory master key', () async {
    final container = ProviderContainer(
      overrides: [testControllerOverride()],
    );
    addTearDown(container.dispose);
    container.read(appControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final c = container.read(appControllerProvider.notifier);
    await c.createPin('259200');
    final master = container.read(appControllerProvider).master!;
    expect(master.any((b) => b != 0), isTrue);
    c.lock();
    expect(master.every((b) => b == 0), isTrue);
    expect(container.read(appControllerProvider).master, isNull);
  });

  test('Argon2id backup params stay at OWASP-class memory', () {
    expect(VaultCrypto.argonMemory, greaterThanOrEqualTo(19 * 1024));
    expect(VaultCrypto.argonIterations, greaterThanOrEqualTo(2));
  });
}
