import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/services/secret_kv.dart';
import 'package:safeauth/core/services/vault_store.dart';
import 'package:safeauth/state/app_controller.dart';

import '../helpers.dart';

void main() {
  testWidgets('onboarding through PIN lands on Home', (tester) async {
    await pumpSafeAuth(tester);
    expect(find.text('Your codes, locked to you'), findsOneWidget);
    await onboardWithPin(tester);
    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('example cards, tabs, and add sheet', (tester) async {
    await pumpSafeAuth(tester, size: const Size(390, 844));
    await onboardWithPin(tester);

    expect(find.text('Show example cards'), findsOneWidget);
    final home = tester.element(find.text('Home'));
    await ProviderScope.containerOf(home)
        .read(appControllerProvider.notifier)
        .loadPreviewAccounts();
    await pumpUi(tester);
    expect(find.text('Amazon Web Services'), findsOneWidget);
    expect(find.text('GitHub'), findsWidgets);
    expect(find.text('Heroku'), findsOneWidget);

    await tester.tap(find.text('Password'));
    await pumpUi(tester);
    expect(find.text('GitHub'), findsWidgets);
    expect(find.text('Add Password Now'), findsOneWidget);

    await tester.tap(find.text('Backup'));
    await pumpUi(tester);
    expect(find.text('Save codes to a file'), findsOneWidget);
    expect(find.text('Open a backup file'), findsOneWidget);
    expect(find.text('How this works'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await pumpUi(tester);
    expect(find.text('Security Health'), findsOneWidget);
    expect(find.text('Backup file'), findsOneWidget);
    expect(find.text('App Lock'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await pumpUi(tester);
    await tester.tap(find.byTooltip('Add account'));
    await pumpUi(tester);
    expect(find.text('Scan QR code'), findsOneWidget);
    expect(find.text('Enter setup key'), findsOneWidget);
    expect(find.text('Paste otpauth:// link'), findsOneWidget);
  });

  testWidgets('lock and unlock with PIN', (tester) async {
    final store = VaultStore(kv: MemorySecretKv());
    await pumpSafeAuth(tester, store: store);
    await onboardWithPin(tester);
    expect(find.text('No accounts yet'), findsOneWidget);

    final ctx = tester.element(find.text('Home'));
    ProviderScope.containerOf(ctx).read(appControllerProvider.notifier).lock();
    await pumpUi(tester);
    expect(find.text('Unlock to view your codes'), findsOneWidget);

    await tapPin(tester, '259200');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No accounts yet'), findsOneWidget);
  });

  testWidgets('mismatched PIN confirm shows an error', (tester) async {
    await pumpSafeAuth(tester);
    await tester.tap(find.text('Continue'));
    await pumpUi(tester);
    await tester.tap(find.text('Continue'));
    await pumpUi(tester);
    await tester.tap(find.text('Create my PIN'));
    await pumpUi(tester);
    await tapPin(tester, '259200');
    await pumpUi(tester);
    await tapPin(tester, '111111');
    await pumpUi(tester);
    expect(find.text('PINs did not match'), findsOneWidget);
  });
}
