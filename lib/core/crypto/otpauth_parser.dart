import 'base32.dart';

class OtpAccountDraft {
  const OtpAccountDraft({
    required this.type,
    required this.secret,
    required this.issuer,
    required this.label,
    this.algorithm = 'SHA1',
    this.digits = 6,
    this.period = 30,
    this.counter = 0,
  });

  final String type;
  final String secret;
  final String issuer;
  final String label;
  final String algorithm;
  final int digits;
  final int period;
  final int counter;
}

/// Parses `otpauth://totp/...` URIs from QR codes and paste.
class OtpAuthParser {
  const OtpAuthParser();

  OtpAccountDraft parse(String raw) {
    final uri = Uri.parse(raw.trim());
    if (uri.scheme.toLowerCase() != 'otpauth') {
      throw const FormatException('Not an otpauth:// QR code');
    }
    final type = uri.host.toLowerCase();
    if (type != 'totp' && type != 'hotp') {
      throw FormatException('Unsupported OTP type: $type');
    }

    final params = uri.queryParameters;
    final secret = (params['secret'] ?? '').replaceAll(' ', '');
    if (!Base32.isValid(secret)) {
      throw const FormatException('Missing or invalid secret');
    }

    final path = Uri.decodeComponent(uri.path).replaceFirst('/', '');
    String issuer = params['issuer'] ?? '';
    String label = path;
    if (path.contains(':')) {
      final parts = path.split(':');
      issuer = issuer.isEmpty ? parts.first.trim() : issuer;
      label = parts.sublist(1).join(':').trim();
    }
    if (issuer.isEmpty) issuer = 'Account';
    if (label.isEmpty) label = issuer;

    var algorithm = (params['algorithm'] ?? 'SHA1').toUpperCase().replaceAll('-', '');
    if (algorithm != 'SHA1' && algorithm != 'SHA256' && algorithm != 'SHA512') {
      algorithm = 'SHA1';
    }
    var digits = int.tryParse(params['digits'] ?? '6') ?? 6;
    var period = int.tryParse(params['period'] ?? '30') ?? 30;
    var counter = int.tryParse(params['counter'] ?? '0') ?? 0;
    if (digits != 6 && digits != 8) digits = 6;
    if (period < 10 || period > 120) period = 30;
    if (counter < 0) counter = 0;

    return OtpAccountDraft(
      type: type,
      secret: secret.replaceAll('=', '').toUpperCase(),
      issuer: issuer,
      label: label,
      algorithm: algorithm,
      digits: digits,
      period: period,
      counter: counter,
    );
  }
}
