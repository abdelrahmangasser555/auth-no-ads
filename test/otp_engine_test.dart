import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/crypto/otp_engine.dart';

void main() {
  const engine = OtpEngine();
  final secret = ascii.encode('12345678901234567890');

  test('RFC 4226 HOTP test vectors', () {
    const expected = {
      0: '755224',
      1: '287082',
      2: '359152',
      3: '969429',
      4: '338314',
      5: '254676',
      6: '287922',
      7: '162583',
      8: '399871',
      9: '520489',
    };
    for (final entry in expected.entries) {
      expect(
        engine.hotp(secret: secret, counter: entry.key, digits: 6),
        entry.value,
      );
    }
  });

  test('RFC 6238 TOTP SHA1 8-digit vectors', () {
    const vectors = <int, String>{
      59: '94287082',
      1111111109: '07081804',
      1111111111: '14050471',
      1234567890: '89005924',
      2000000000: '69279037',
    };
    for (final entry in vectors.entries) {
      final time = DateTime.fromMillisecondsSinceEpoch(
        entry.key * 1000,
        isUtc: true,
      );
      expect(
        engine.totp(secret: secret, time: time, digits: 8, period: 30),
        entry.value,
      );
    }
  });

  test('formats 6-digit codes with a space', () {
    expect(engine.formatCode('259200'), '259 200');
    expect(engine.formatCode('462625'), '462 625');
  });

  test('remaining seconds wraps inside the period', () {
    final time = DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true);
    expect(engine.remainingSeconds(time: time, period: 30), 1);
  });
}
