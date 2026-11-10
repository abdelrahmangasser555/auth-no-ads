import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/services/biometrics.dart';
import 'package:safeauth/core/services/secret_kv.dart';
import 'package:safeauth/core/services/vault_store.dart';
import 'package:safeauth/main.dart';
import 'package:safeauth/state/app_controller.dart';

class SilentBio extends BiometricGate {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({String reason = 'Unlock Auth No Ads'}) async => false;
}

VaultStore memoryStore([MemorySecretKv? kv]) =>
    VaultStore(kv: kv ?? MemorySecretKv());

Override testControllerOverride([VaultStore? store]) {
  final s = store ?? memoryStore();
  return appControllerProvider.overrideWith(
    () => AppController(store: s, biometrics: SilentBio()),
  );
}

Future<void> pumpSafeAuth(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  List<Override>? overrides,
  VaultStore? store,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('app.personal.safeauth/secure'),
    (_) async => null,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('app.personal.safeauth/widget'),
    (_) async => null,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('app.personal.safeauth/import'),
    (_) async => null,
  );

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 24, bottom: 16),
      ),
      child: ProviderScope(
        overrides: overrides ?? [testControllerOverride(store)],
        child: const SafeAuthApp(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Future<void> tapPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

Future<void> onboardWithPin(WidgetTester tester, {String pin = '259200'}) async {
  await tester.tap(find.text('Continue'));
  await pumpUi(tester);
  await tester.tap(find.text('Continue'));
  await pumpUi(tester);
  await tester.tap(find.text('Create my PIN'));
  await pumpUi(tester);
  await tapPin(tester, pin);
  await pumpUi(tester);
  await tapPin(tester, pin);
  await waitFor(tester, find.text('Home'));
  final ctrl = ProviderScope.containerOf(tester.element(find.text('Home')))
      .read(appControllerProvider.notifier);
  final disableLock = ctrl.patchSettings((s) => s.autoLockSeconds = 0);
  await pumpUi(tester);
  await tester.pump(const Duration(milliseconds: 200));
  await disableLock;
}

List<String> takeOverflows() {
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
  return caught;
}
