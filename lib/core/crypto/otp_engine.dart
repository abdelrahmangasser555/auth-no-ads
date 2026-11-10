import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 4226 HOTP + RFC 6238 TOTP. Compatible with Google, Microsoft,
/// GitHub, AWS, and every standard authenticator QR code.
class OtpEngine {
  const OtpEngine();

  String totp({
    required List<int> secret,
    DateTime? time,
    int digits = 6,
    int period = 30,
    String algorithm = 'SHA1',
  }) {
    final seconds =
        ((time ?? DateTime.now().toUtc()).millisecondsSinceEpoch / 1000)
            .floor();
    if (period <= 0) period = 30;
    final counter = seconds ~/ period;
    return hotp(
      secret: secret,
      counter: counter,
      digits: digits,
      algorithm: algorithm,
    );
  }

  String hotp({
    required List<int> secret,
    required int counter,
    int digits = 6,
    String algorithm = 'SHA1',
  }) {
    if (digits < 6) digits = 6;
    if (digits > 8) digits = 8;
    if (counter < 0) counter = 0;
    // Write the 8-byte counter without Uint64 — dart2js (web) has no setUint64.
    final data = Uint8List(8);
    var value = counter;
    for (var i = 7; i >= 0; i--) {
      data[i] = value & 0xff;
      value >>= 8;
    }
    final digest = _hmac(algorithm, secret, data);
    final offset = digest[digest.length - 1] & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);
    final otp = binary % pow(10, digits).toInt();
    return otp.toString().padLeft(digits, '0');
  }

  int remainingSeconds({DateTime? time, int period = 30}) {
    if (period <= 0) period = 30;
    final seconds =
        ((time ?? DateTime.now().toUtc()).millisecondsSinceEpoch / 1000)
            .floor();
    return period - (seconds % period);
  }

  double progress({DateTime? time, int period = 30}) {
    if (period <= 0) period = 30;
    final now = time ?? DateTime.now().toUtc();
    final ms = now.millisecondsSinceEpoch;
    final window = period * 1000;
    return (ms % window) / window;
  }

  String formatCode(String code) {
    if (code.length == 6) {
      return '${code.substring(0, 3)} ${code.substring(3)}';
    }
    if (code.length == 8) {
      return '${code.substring(0, 4)} ${code.substring(4)}';
    }
    if (code.length == 7) {
      return '${code.substring(0, 3)} ${code.substring(3)}';
    }
    return code;
  }

  List<int> _hmac(String algorithm, List<int> key, List<int> data) {
    final normalized = algorithm.toUpperCase().replaceAll('-', '');
    final Hash hash = switch (normalized) {
      'SHA256' => sha256,
      'SHA512' => sha512,
      _ => sha1,
    };
    return Hmac(hash, key).convert(data).bytes;
  }
}
