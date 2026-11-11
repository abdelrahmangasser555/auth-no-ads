import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/services/linked_file.dart';
import 'package:safeauth/core/services/secret_kv.dart';
import 'package:safeauth/core/services/vault_store.dart';
import 'package:safeauth/state/app_controller.dart';

import 'helpers.dart';

class FakeLinkedFiles extends LinkedFileBridge {
  FakeLinkedFiles() : super(channel: const MethodChannel('test.import'));

  LinkedFileSnapshot? snapshot;

  @override
  bool get supported => true;

  @override
  Future<LinkedFileSnapshot?> read(String uri) async => snapshot;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('linked SafeAuth file syncs new accounts when the file changes', () async {
    final store = VaultStore(kv: MemorySecretKv());
    final files = FakeLinkedFiles();
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => AppController(
            store: store,
            biometrics: SilentBio(),
            files: files,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(appControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(appControllerProvider.notifier);
    await controller.createPin('259200');

    const first = '''
otpauth://totp/GitHub:me?secret=JBSWY3DPEHPK3PXP&issuer=GitHub
''';
    files.snapshot = const LinkedFileSnapshot(
      content: first,
      uri: 'content://safeauth/export',
      name: 'safeauth-export.txt',
    );
    final linked = await controller.importFileContent(
      first,
      uri: 'content://safeauth/export',
      name: 'safeauth-export.txt',
      link: true,
    );
    expect(linked.addedAccounts, 1);
    expect(linked.linked, isTrue);

    final unchanged = await controller.syncLinkedImport();
    expect(unchanged.unchanged, isTrue);
    expect(container.read(appControllerProvider).vault!.accounts.length, 1);

    const second = '''
otpauth://totp/GitHub:me?secret=JBSWY3DPEHPK3PXP&issuer=GitHub
otpauth://totp/Heroku:new?secret=GEZDGNBVGY3TQOJQ&issuer=Heroku
''';
    files.snapshot = const LinkedFileSnapshot(
      content: second,
      uri: 'content://safeauth/export',
      name: 'safeauth-export.txt',
    );
    final updated = await controller.syncLinkedImport();
    expect(updated.addedAccounts, 1);
    expect(
      container.read(appControllerProvider).vault!.accounts.map((a) => a.issuer),
      containsAll(['GitHub', 'Heroku']),
    );
  });
}
