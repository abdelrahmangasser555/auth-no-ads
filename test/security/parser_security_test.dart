import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/crypto/base32.dart';
import 'package:safeauth/core/crypto/migration.dart';
import 'package:safeauth/core/crypto/otpauth_parser.dart';
import 'package:safeauth/core/crypto/password_generator.dart';

void main() {
  const parser = OtpAuthParser();
  const migration = GoogleMigrationParser();

  test('rejects non-otpauth schemes including javascript', () {
    expect(() => parser.parse('javascript:alert(1)'), throwsFormatException);
    expect(() => parser.parse('https://evil.test/?secret=AAAA'), throwsFormatException);
    expect(() => parser.parse('data:text/html,hi'), throwsFormatException);
    expect(() => parser.parse('otpauth-migration://offline?data=xx'), throwsFormatException);
  });

  test('rejects missing or invalid secrets', () {
    expect(
      () => parser.parse('otpauth://totp/GitHub:me?issuer=GitHub'),
      throwsFormatException,
    );
    expect(
      () => parser.parse('otpauth://totp/GitHub:me?secret=NOT*VALID'),
      throwsFormatException,
    );
  });

  test('clamps absurd digits and period', () {
    final draft = parser.parse(
      'otpauth://totp/GitHub:me?secret=JBSWY3DPEHPK3PXP&digits=99&period=0',
    );
    expect(draft.digits, 6);
    expect(draft.period, 30);
  });

  test('does not execute HTML in issuer or label', () {
    final draft = parser.parse(
      'otpauth://totp/<script>alert(1)</script>:me?secret=JBSWY3DPEHPK3PXP&issuer=<img src=x>',
    );
    expect(draft.issuer, contains('img'));
    expect(draft.issuer.contains('<'), isTrue);
  });

  test('unsupported OTP type is rejected', () {
    expect(
      () => parser.parse('otpauth://steam/Game:me?secret=JBSWY3DPEHPK3PXP'),
      throwsFormatException,
    );
  });

  test('Base32 rejects empty and junk', () {
    expect(Base32.isValid(''), isFalse);
    expect(Base32.isValid('!!!!'), isFalse);
    expect(Base32.isValid('JBSWY3DPEHPK3PXP'), isTrue);
    expect(Base32.decode('MFRGGZDF'), isNotEmpty);
  });

  test('Base32 encode/decode roundtrip', () {
    const raw = [1, 2, 3, 4, 5, 250, 255];
    expect(Base32.decode(Base32.encode(raw)), raw);
  });

  test('migration parser rejects garbage', () {
    expect(() => migration.parse('not-a-uri'), throwsA(anything));
    expect(
      () => migration.parse('otpauth-migration://offline?data='),
      throwsFormatException,
    );
    expect(
      () => migration.parse('otpauth-migration://offline?data=@@@'),
      throwsA(anything),
    );
  });

  test('password generator never emits lookalike 0/O/1/l/I', () {
    final gen = PasswordGenerator();
    for (var i = 0; i < 20; i++) {
      final p = gen.generate(length: 24);
      expect(p.contains('0'), isFalse);
      expect(p.contains('O'), isFalse);
      expect(p.contains('1'), isFalse);
      expect(p.contains('l'), isFalse);
      expect(p.contains('I'), isFalse);
    }
  });

  test('password generator rejects empty class sets', () {
    expect(
      () => PasswordGenerator().generate(
        upper: false,
        lower: false,
        numbers: false,
        symbolsEnabled: false,
      ),
      throwsArgumentError,
    );
  });
}
