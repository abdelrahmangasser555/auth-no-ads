/// RFC 4648 Base32 (no padding required). Secrets from authenticator QR codes
/// are almost always Base32.
class Base32 {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static List<int> decode(String input) {
    final cleaned = input
        .trim()
        .replaceAll('=', '')
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .toUpperCase();
    if (cleaned.isEmpty) {
      throw const FormatException('Empty secret');
    }
    if (cleaned.length < 8) {
      throw const FormatException('Secret is too short');
    }
    if (cleaned.length > 128) {
      throw const FormatException('Secret is too long');
    }
    var buffer = 0;
    var bits = 0;
    final out = <int>[];
    for (final rune in cleaned.runes) {
      final char = String.fromCharCode(rune);
      final val = _alphabet.indexOf(char);
      if (val < 0) {
        throw FormatException('Invalid Base32 character: $char');
      }
      buffer = (buffer << 5) | val;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xFF);
      }
    }
    return out;
  }

  static String encode(List<int> bytes) {
    if (bytes.isEmpty) return '';
    var buffer = 0;
    var bits = 0;
    final out = StringBuffer();
    for (final byte in bytes) {
      buffer = (buffer << 8) | (byte & 0xFF);
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(_alphabet[(buffer >> bits) & 31]);
      }
    }
    if (bits > 0) {
      out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    }
    return out.toString();
  }

  static bool isValid(String input) {
    try {
      final bytes = decode(input);
      return bytes.length >= 5;
    } catch (_) {
      return false;
    }
  }
}
