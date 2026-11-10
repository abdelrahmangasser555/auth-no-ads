import 'dart:convert';
import 'dart:typed_data';

import 'base32.dart';
import 'otpauth_parser.dart';

/// Minimal protobuf decoder for Google Authenticator
/// `otpauth-migration://offline?data=` payloads.
class GoogleMigrationParser {
  const GoogleMigrationParser();

  List<OtpAccountDraft> parse(String raw) {
    final uri = Uri.parse(raw.trim());
    if (uri.scheme != 'otpauth-migration') {
      throw const FormatException('Not a Google Authenticator export');
    }
    final data = uri.queryParameters['data'];
    if (data == null || data.isEmpty) {
      throw const FormatException('Missing migration data');
    }
    final bytes = base64.decode(data.replaceAll(' ', '+'));
    return _readPayload(bytes);
  }

  List<OtpAccountDraft> _readPayload(List<int> bytes) {
    final accounts = <OtpAccountDraft>[];
    var i = 0;
    while (i < bytes.length) {
      final key = bytes[i++];
      final field = key >> 3;
      final wire = key & 0x7;
      if (wire == 0) {
        final skip = _readVarint(bytes, i);
        i = skip.next;
      } else if (wire == 2) {
        final len = _readVarint(bytes, i);
        i = len.next;
        final slice = bytes.sublist(i, i + len.value);
        i += len.value;
        if (field == 1) {
          accounts.add(_readParameters(slice));
        }
      } else {
        break;
      }
    }
    return accounts;
  }

  OtpAccountDraft _readParameters(List<int> bytes) {
    List<int> secret = const [];
    var name = '';
    var issuer = '';
    var algorithm = 'SHA1';
    var digits = 6;
    var type = 'totp';
    var counter = 0;
    var i = 0;
    while (i < bytes.length) {
      final key = bytes[i++];
      final field = key >> 3;
      final wire = key & 0x7;
      if (wire == 0) {
        final v = _readVarint(bytes, i);
        i = v.next;
        if (field == 4) {
          algorithm = switch (v.value) {
            2 => 'SHA256',
            3 => 'SHA512',
            _ => 'SHA1',
          };
        } else if (field == 5) {
          digits = v.value == 2 ? 8 : 6;
        } else if (field == 6) {
          type = v.value == 1 ? 'hotp' : 'totp';
        } else if (field == 7) {
          counter = v.value;
        }
      } else if (wire == 2) {
        final len = _readVarint(bytes, i);
        i = len.next;
        final slice = bytes.sublist(i, i + len.value);
        i += len.value;
        if (field == 1) secret = slice;
        if (field == 2) name = utf8.decode(slice);
        if (field == 3) issuer = utf8.decode(slice);
      } else {
        break;
      }
    }
    if (secret.isEmpty) {
      throw const FormatException('Migration entry missing secret');
    }
    var label = name;
    if (name.contains(':')) {
      final parts = name.split(':');
      if (issuer.isEmpty) issuer = parts.first.trim();
      label = parts.sublist(1).join(':').trim();
    }
    if (issuer.isEmpty) issuer = 'Account';
    if (label.isEmpty) label = issuer;
    return OtpAccountDraft(
      type: type,
      secret: Base32.encode(secret),
      issuer: issuer,
      label: label,
      algorithm: algorithm,
      digits: digits,
      period: 30,
      counter: counter,
    );
  }

  _Varint _readVarint(List<int> bytes, int start) {
    var result = 0;
    var shift = 0;
    var i = start;
    while (i < bytes.length) {
      final b = bytes[i++];
      result |= (b & 0x7f) << shift;
      if (b & 0x80 == 0) break;
      shift += 7;
    }
    return _Varint(result, i);
  }
}

class _Varint {
  const _Varint(this.value, this.next);
  final int value;
  final int next;
}

Uint8List asBytes(List<int> data) => Uint8List.fromList(data);
