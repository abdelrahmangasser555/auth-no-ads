import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/ui/widgets/account_card.dart';
import 'package:safeauth/ui/widgets/pin_pad.dart';
import 'package:safeauth/core/crypto/otp_engine.dart';
import 'package:safeauth/core/models/models.dart';
import 'package:safeauth/state/app_controller.dart';

import '../helpers.dart';

Future<List<String>> pumpAndCollectOverflows(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final caught = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed') || text.contains('OVERFLOWING')) {
      caught.add(text);
    } else {
      previous?.call(details);
    }
  };
  await body();
  FlutterError.onError = previous;
  return caught;
}

void main() {
  const phones = <String, Size>{
    'iPhone SE': Size(320, 568),
    'iPhone 8': Size(375, 667),
    'Pixel 5': Size(393, 851),
    'Galaxy compact': Size(360, 740),
    'Galaxy S22': Size(412, 915),
  };

  for (final entry in phones.entries) {
    testWidgets('onboarding fits ${entry.key}', (tester) async {
      final overflows = await pumpAndCollectOverflows(tester, () async {
        await pumpSafeAuth(tester, size: entry.value);
        await pumpUi(tester);
      });
      expect(overflows, isEmpty, reason: entry.key);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('home and PIN fit ${entry.key}', (tester) async {
      final overflows = await pumpAndCollectOverflows(tester, () async {
        await pumpSafeAuth(tester, size: entry.value);
        await onboardWithPin(tester);
      });
      expect(overflows, isEmpty, reason: entry.key);
      expect(find.text('Home'), findsOneWidget);
    });
  }

  testWidgets('home survives 1.3 text scale on a small phone', (tester) async {
    final overflows = await pumpAndCollectOverflows(tester, () async {
      await pumpSafeAuth(
        tester,
        size: const Size(360, 640),
        textScale: 1.3,
      );
      await onboardWithPin(tester);
    });
    expect(overflows, isEmpty);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('No accounts yet'), findsOneWidget);
  });

  testWidgets('every tab fits iPhone SE after onboarding', (tester) async {
    final overflows = await pumpAndCollectOverflows(tester, () async {
      await pumpSafeAuth(tester, size: const Size(320, 568));
      await onboardWithPin(tester);
      for (final tab in ['Password', 'Backup', 'Settings', 'Home']) {
        await tester.tap(find.text(tab));
        await pumpUi(tester);
      }
    });
    expect(overflows, isEmpty);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('lock screen fits a small phone', (tester) async {
    final overflows = await pumpAndCollectOverflows(tester, () async {
      await pumpSafeAuth(tester, size: const Size(320, 568));
      await onboardWithPin(tester);
      final ctx = tester.element(find.text('Home'));
      ProviderScope.containerOf(ctx).read(appControllerProvider.notifier).lock();
      await pumpUi(tester);
    });
    expect(overflows, isEmpty);
    expect(find.text('Unlock to view your codes'), findsOneWidget);
  });

  testWidgets('PIN pad has 48dp-class tap targets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinPad(
            length: 0,
            maxLength: 6,
            onDigit: (_) {},
            onBackspace: () {},
          ),
        ),
      ),
    );
    final key = tester.getSize(find.text('5'));
    expect(key.width, greaterThanOrEqualTo(20));
    final ink = tester.getSize(find.byType(Ink).first);
    expect(ink.shortestSide, greaterThanOrEqualTo(48));
  });

  testWidgets('long issuer names ellipsize instead of overflowing', (tester) async {
    final overflows = await pumpAndCollectOverflows(tester, () async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: AccountCard(
                account: TotpAccount.create(
                  issuer: 'A very very very long cloud provider name that should clip',
                  label: 'an-even-longer-account-label@example.invalid',
                  secret: 'JBSWY3DPEHPK3PXP',
                ),
                now: DateTime.utc(2024, 1, 1),
                hideCode: false,
                onCopy: () {},
                onMenu: () {},
                otp: const OtpEngine(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    });
    expect(overflows, isEmpty);
  });

  testWidgets('hidden codes do not copy until revealed', (tester) async {
    var copied = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountCard(
            account: TotpAccount.create(
              issuer: 'GitHub',
              label: 'me',
              secret: 'JBSWY3DPEHPK3PXP',
            ),
            now: DateTime.utc(2024, 1, 1),
            hideCode: true,
            onCopy: () => copied++,
            onMenu: () {},
            otp: const OtpEngine(),
          ),
        ),
      ),
    );
    expect(find.text('••• •••'), findsOneWidget);
    await tester.tap(find.byType(AccountCard));
    await tester.pump();
    expect(copied, 0);
    expect(find.text('••• •••'), findsNothing);
    await tester.tap(find.byType(AccountCard));
    await tester.pump();
    expect(copied, 1);
  });
}
