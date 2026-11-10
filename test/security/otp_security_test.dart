import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/crypto/base32.dart';
import 'package:safeauth/core/crypto/otp_engine.dart';

void main() {
  const engine = OtpEngine();

  test('RFC 6238 SHA256 8-digit vectors', () {
    final secret = ascii.encode('12345678901234567890123456789012');
    const vectors = <int, String>{
      59: '46119246',
      1111111109: '68084774',
      1111111111: '67062674',
      1234567890: '91819424',
      2000000000: '90698825',
    };
    for (final entry in vectors.entries) {
      final time = DateTime.fromMillisecondsSinceEpoch(
        entry.key * 1000,
        isUtc: true,
      );
      expect(
        engine.totp(
          secret: secret,
          time: time,
          digits: 8,
          period: 30,
          algorithm: 'SHA256',
        ),
        entry.value,
      );
    }
  });

  test('period 0 does not divide by zero', () {
    final secret = ascii.encode('12345678901234567890');
    expect(
      engine.totp(secret: secret, period: 0, digits: 6),
      matches(RegExp(r'^\d{6}$')),
    );
    expect(engine.remainingSeconds(period: 0), inInclusiveRange(1, 30));
    expect(engine.progress(period: 0), inInclusiveRange(0, 1));
  });

  test('digits are clamped to 6-8', () {
    final secret = ascii.encode('12345678901234567890');
    expect(engine.hotp(secret: secret, counter: 0, digits: 1).length, 6);
    expect(engine.hotp(secret: secret, counter: 0, digits: 99).length, 8);
  });

  test('negative HOTP counter is treated as zero', () {
    final secret = ascii.encode('12345678901234567890');
    expect(
      engine.hotp(secret: secret, counter: -5, digits: 6),
      engine.hotp(secret: secret, counter: 0, digits: 6),
    );
  });

  test('the well-known sample secret produces a 6-digit code', () {
    final secret = Base32.decode('JBSWY3DPEHPK3PXP');
    final code = engine.totp(secret: secret);
    expect(code, matches(RegExp(r'^\d{6}$')));
  });

  test('codes change across a 30-second window', () {
    final secret = ascii.encode('12345678901234567890');
    final a = engine.totp(
      secret: secret,
      time: DateTime.utc(1970, 1, 1, 0, 0, 59),
    );
    final b = engine.totp(
      secret: secret,
      time: DateTime.utc(1970, 1, 1, 0, 1, 30),
    );
    expect(a, isNot(b));
  });
}
