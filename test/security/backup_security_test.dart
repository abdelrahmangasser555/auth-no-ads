import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/models/models.dart';
import 'package:safeauth/core/services/secret_kv.dart';
import 'package:safeauth/core/services/vault_store.dart';
import 'package:safeauth/state/app_controller.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VaultData sample() {
    return VaultData()
      ..accounts.add(
        TotpAccount.create(
          issuer: 'GitHub',
          label: 'you@example.com',
          secret: 'JBSWY3DPEHPK3PXP',
        ),
      )
      ..passwords.add(
        PasswordEntry.create(
          title: 'GitHub',
          username: 'you@example.com',
          password: 'hunter2-not-real',
        ),
      );
  }

  test('backup roundtrip restores accounts and passwords', () async {
    final store = VaultStore(kv: MemorySecretKv());
    final file = await store.exportBackup(data: sample(), password: 'correct-horse');
    final loaded = await store.importBackup(file: file, password: 'correct-horse');
    expect(loaded.accounts.single.secret, 'JBSWY3DPEHPK3PXP');
    expect(loaded.passwords.single.password, 'hunter2-not-real');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('wrong backup password fails closed', () async {
    final store = VaultStore(kv: MemorySecretKv());
    final file = await store.exportBackup(data: sample(), password: 'correct-horse');
    await expectLater(
      store.importBackup(file: file, password: 'wrong-password'),
      throwsA(anything),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('backup file does not contain secrets in plaintext', () async {
    final store = VaultStore(kv: MemorySecretKv());
    final file = await store.exportBackup(data: sample(), password: 'correct-horse');
    expect(file.contains('JBSWY3DPEHPK3PXP'), isFalse);
    expect(file.contains('hunter2-not-real'), isFalse);
    expect(file.contains('safeauth.backup.v1'), isTrue);
    expect(file.contains('argon2id'), isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('tampered backup payload fails closed', () async {
    final store = VaultStore(kv: MemorySecretKv());
    final file = await store.exportBackup(data: sample(), password: 'correct-horse');
    final map = jsonDecode(file) as Map<String, dynamic>;
    map['payload'] = '${map['payload']}x';
    await expectLater(
      store.importBackup(file: jsonEncode(map), password: 'correct-horse'),
      throwsA(anything),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('unknown backup format is rejected', () async {
    final store = VaultStore(kv: MemorySecretKv());
    await expectLater(
      store.importBackup(
        file: jsonEncode({'format': 'evil.v1', 'payload': '{}'}),
        password: 'correct-horse',
      ),
      throwsFormatException,
    );
  });

  test('short backup passwords are rejected', () async {
    final store = VaultStore(kv: MemorySecretKv());
    await expectLater(
      store.exportBackup(data: sample(), password: 'short'),
      throwsFormatException,
    );
  });

  test('restore merges new accounts and skips duplicate secrets', () async {
    final store = VaultStore(kv: MemorySecretKv());
    final container = ProviderContainer(
      overrides: [testControllerOverride(store)],
    );
    addTearDown(container.dispose);
    container.read(appControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(appControllerProvider.notifier);
    await controller.createPin('259200');
    await controller.addManualAccount(
      issuer: 'GitHub',
      label: 'me',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    final incoming = VaultData()
      ..accounts.add(
        TotpAccount.create(
          issuer: 'GitHub',
          label: 'dup',
          secret: 'JBSWY3DPEHPK3PXP',
        ),
      )
      ..accounts.add(
        TotpAccount.create(
          issuer: 'Heroku',
          label: 'new',
          secret: 'GEZDGNBVGY3TQOJQ',
        ),
      );
    final file =
        await store.exportBackup(data: incoming, password: 'correct-horse');
    await controller.restoreBackup(file, 'correct-horse');
    expect(container.read(appControllerProvider).vault!.accounts.length, 2);
    expect(
      container.read(appControllerProvider).vault!.accounts.map((a) => a.issuer),
      containsAll(['GitHub', 'Heroku']),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
