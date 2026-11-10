import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/crypto/base32.dart';
import 'package:safeauth/core/crypto/otpauth_parser.dart';

void main() {
  const parser = OtpAuthParser();

  test('parses a GitHub-style otpauth URI', () {
    final draft = parser.parse(
      'otpauth://totp/GitHub:abdelrahmangasser555?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA1&digits=6&period=30',
    );
    expect(draft.issuer, 'GitHub');
    expect(draft.label, 'abdelrahmangasser555');
    expect(draft.secret, 'JBSWY3DPEHPK3PXP');
    expect(draft.digits, 6);
    expect(draft.period, 30);
    expect(Base32.decode(draft.secret), isNotEmpty);
  });

  test('rejects garbage', () {
    expect(() => parser.parse('https://example.com'), throwsFormatException);
  });
}
