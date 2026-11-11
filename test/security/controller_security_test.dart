import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/services/secret_kv.dart';
import 'package:safeauth/core/services/vault_store.dart';
import 'package:safeauth/state/app_controller.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late VaultStore store;

  setUp(() {
    store = VaultStore(kv: MemorySecretKv());
    container = ProviderContainer(
      overrides: [testControllerOverride(store)],
    );
    container.read(appControllerProvider);
  });

  tearDown(() => container.dispose());

  Future<AppController> ready() async {
    await Future<void>.delayed(Duration.zero);
    final c = container.read(appControllerProvider.notifier);
    await c.createPin('259200');
    return c;
  }

  test('rejects invalid Base32 secrets', () async {
    final c = await ready();
    await expectLater(
      c.addManualAccount(issuer: 'X', label: 'y', secret: 'not*valid!!'),
      throwsFormatException,
    );
    expect(container.read(appControllerProvider).vault!.accounts, isEmpty);
  });

  test('lock clears vault from memory', () async {
    final c = await ready();
    await c.addManualAccount(
      issuer: 'GitHub',
      label: 'me',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    expect(container.read(appControllerProvider).vault, isNotNull);
    expect(container.read(appControllerProvider).master, isNotNull);
    c.lock();
    expect(container.read(appControllerProvider).phase, AppPhase.locked);
    expect(container.read(appControllerProvider).vault, isNull);
    expect(container.read(appControllerProvider).master, isNull);
  });

  test('screenshots stay blocked by default', () async {
    await ready();
    expect(
      container.read(appControllerProvider).vault!.settings.allowScreenshots,
      isFalse,
    );
  });

  test('app lock is on by default', () async {
    await ready();
    expect(container.read(appControllerProvider).vault!.settings.appLock, isTrue);
  });

  test('wrong unlock PIN does not open the vault', () async {
    final c = await ready();
    c.lock();
    await c.unlockPin('000000');
    expect(container.read(appControllerProvider).phase, AppPhase.locked);
    expect(container.read(appControllerProvider).error, isNotNull);
  });

  test('deleting an account removes it from the vault', () async {
    final c = await ready();
    await c.addManualAccount(
      issuer: 'GitHub',
      label: 'me',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    final id = container.read(appControllerProvider).vault!.accounts.single.id;
    await c.deleteAccount(id);
    expect(container.read(appControllerProvider).vault!.accounts, isEmpty);
  });

  test('preview accounts refuse to run twice', () async {
    final c = await ready();
    await c.loadPreviewAccounts();
    await c.loadPreviewAccounts();
    expect(container.read(appControllerProvider).vault!.accounts.length, 3);
  });

  test('widget selection is capped and dropped when the account is deleted', () async {
    final c = await ready();
    await c.addManualAccount(
      issuer: 'GitHub',
      label: 'me',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    final id = container.read(appControllerProvider).vault!.accounts.single.id;
    await c.toggleWidgetAccount(id, true);
    expect(
      container.read(appControllerProvider).vault!.settings.widgetAccountIds,
      [id],
    );
    await c.deleteAccount(id);
    expect(
      container.read(appControllerProvider).vault!.settings.widgetAccountIds,
      isEmpty,
    );
  });

  test('imports a SafeAuth-style JSON file without duplicating secrets', () async {
    final c = await ready();
    await c.addManualAccount(
      issuer: 'GitHub',
      label: 'me',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    final summary = await c.importFileContent(
      jsonEncode({
        'otp_list': [
          {
            'issuer': 'GitHub',
            'username': 'dup',
            'secretKey': 'JBSWY3DPEHPK3PXP',
          },
          {
            'issuer': 'Heroku',
            'username': 'new',
            'secretKey': 'GEZDGNBVGY3TQOJQ',
          },
        ],
      }),
    );
    expect(summary.addedAccounts, 1);
    expect(container.read(appControllerProvider).vault!.accounts.length, 2);
    expect(
      container.read(appControllerProvider).vault!.accounts.map((a) => a.issuer),
      containsAll(['GitHub', 'Heroku']),
    );
    expect(
      container
          .read(appControllerProvider)
          .vault!
          .accounts
          .where((a) => a.issuer == 'Heroku')
          .single
          .category,
      'Imported',
    );
  });
}
