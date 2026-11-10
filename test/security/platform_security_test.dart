import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android backup and cloud extraction stay disabled', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('android:allowBackup="false"'), isTrue);
    expect(manifest.contains('android:fullBackupContent="false"'), isTrue);
    expect(manifest.contains('data_extraction_rules'), isTrue);
    expect(manifest.contains('networkSecurityConfig'), isTrue);

    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    expect(rules.contains('<exclude domain="sharedpref"'), isTrue);
    expect(rules.contains('<exclude domain="file"'), isTrue);

    final net = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();
    expect(net.contains('cleartextTrafficPermitted="false"'), isTrue);
  });
}
