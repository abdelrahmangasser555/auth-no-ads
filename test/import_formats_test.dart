import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/crypto/import_formats.dart';
import 'package:safeauth/core/crypto/otpauth_parser.dart';
import 'package:safeauth/core/models/models.dart';

void main() {
  const importer = VaultFileImporter();

  test('parses otpauth URI lists', () {
    const file = '''
otpauth://totp/GitHub:me?secret=JBSWY3DPEHPK3PXP&issuer=GitHub
otpauth://totp/Heroku:you?secret=GEZDGNBVGY3TQOJQ&issuer=Heroku
''';
    final bundle = importer.parse(file);
    expect(bundle.format, 'otpauth');
    expect(bundle.accounts.map((a) => a.issuer), ['GitHub', 'Heroku']);
    expect(bundle.accounts.first.secret, 'JBSWY3DPEHPK3PXP');
  });

  test('parses Google Authenticator migration payloads', () {
    const uri =
        'otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU6YWxpY2VAZ29vZ2xlLmNvbRoHRXhhbXBsZTAC';
    final bundle = importer.parse(uri);
    expect(bundle.format, 'google-migration');
    expect(bundle.accounts, isNotEmpty);
    expect(bundle.accounts.first.secret, 'JBSWY3DPEHPK3PXP');
  });

  test('parses 2FAS JSON', () {
    final file = jsonEncode({
      'schemaVersion': 4,
      'services': [
        {
          'name': 'GitHub',
          'secret': 'JBSWY3DPEHPK3PXP',
          'otp': {
            'account': 'you@example.com',
            'issuer': 'GitHub',
            'digits': 6,
            'period': 30,
            'algorithm': 'SHA1',
            'tokenType': 'TOTP',
          },
        },
      ],
    });
    final bundle = importer.parse(file);
    expect(bundle.format, '2fas');
    expect(bundle.accounts.single.issuer, 'GitHub');
    expect(bundle.accounts.single.label, 'you@example.com');
  });

  test('parses Aegis JSON', () {
    final file = jsonEncode({
      'version': 1,
      'header': {'slots': null, 'params': null},
      'db': {
        'version': 2,
        'entries': [
          {
            'type': 'totp',
            'name': 'root',
            'issuer': 'Amazon Web Services',
            'info': {
              'secret': 'GEZDGNBVGY3TQOJQ',
              'algo': 'SHA1',
              'digits': 6,
              'period': 30,
            },
          },
        ],
      },
    });
    final bundle = importer.parse(file);
    expect(bundle.format, 'aegis');
    expect(bundle.accounts.single.issuer, 'Amazon Web Services');
    expect(bundle.accounts.single.label, 'root');
  });

  test('parses andOTP-style arrays and SafeAuth clone JSON', () {
    final andotp = jsonEncode([
      {
        'secret': 'JBSWY3DPEHPK3PXP',
        'label': 'me',
        'issuer': 'GitHub',
        'digits': 6,
        'type': 'TOTP',
        'algorithm': 'SHA1',
        'period': 30,
      },
    ]);
    expect(importer.parse(andotp).accounts.single.issuer, 'GitHub');

    final clone = jsonEncode({
      'otp_list': [
        {
          'name': 'Google',
          'username': 'ada@example.com',
          'secretKey': 'JBSWY3DPEHPK3PXP',
          'issuer': 'Google',
        },
      ],
    });
    final bundle = importer.parse(clone);
    expect(bundle.accounts.single.issuer, 'Google');
    expect(bundle.accounts.single.label, 'ada@example.com');
  });

  test('parses this app\'s unencrypted vault JSON', () {
    final vault = VaultData()
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
          username: 'you',
          password: 'hunter2-not-real',
        ),
      );
    final bundle = importer.parse(jsonEncode(vault.toJson()));
    expect(bundle.format, 'safeauth-json');
    expect(bundle.accounts.single.issuer, 'GitHub');
    expect(bundle.passwords.single.password, 'hunter2-not-real');
  });

  test('encrypted SafeAuth backups need the password', () {
    final content = jsonEncode({
      'format': 'safeauth.backup.v1',
      'salt': 'AA==',
      'payload': '{}',
    });
    expect(importer.isEncryptedSafeAuth(content), isTrue);
    expect(
      () => importer.parse(content),
      throwsA(isA<ImportNeedsPassword>()),
    );
  });

  test('uses decrypted SafeAuth vault when provided', () {
    final vault = VaultData()
      ..accounts.add(
        TotpAccount.create(
          issuer: 'Heroku',
          label: 'new',
          secret: 'GEZDGNBVGY3TQOJQ',
        ),
      );
    final content = jsonEncode({
      'format': 'safeauth.backup.v1',
      'salt': 'AA==',
      'payload': 'cipher',
    });
    final bundle = importer.parse(content, decryptedVault: vault);
    expect(bundle.format, 'safeauth.backup.v1');
    expect(bundle.accounts.single.issuer, 'Heroku');
  });

  test('rejects files with no secrets', () {
    expect(
      () => importer.parse(jsonEncode({'hello': 'world'})),
      throwsFormatException,
    );
  });

  test('otpauth parser still accepts a single URI', () {
    final draft = const OtpAuthParser().parse(
      'otpauth://totp/GitHub:abdelrahmangasser555?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
    );
    expect(draft.label, 'abdelrahmangasser555');
  });
}
