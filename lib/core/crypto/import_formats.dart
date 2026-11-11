import 'dart:convert';

import '../models/models.dart';
import 'base32.dart';
import 'migration.dart';
import 'otpauth_parser.dart';

class ImportNeedsPassword implements Exception {
  const ImportNeedsPassword(this.format);
  final String format;

  @override
  String toString() => 'This $format file is encrypted. Enter the password.';
}

class ImportBundle {
  const ImportBundle({
    required this.format,
    this.accounts = const [],
    this.passwords = const [],
  });

  final String format;
  final List<OtpAccountDraft> accounts;
  final List<PasswordEntry> passwords;
}

/// Parses authenticator export files so people can leave vendor-locked apps.
///
/// Handles this app's encrypted `.safeauth` backups, otpauth URI lists,
/// Google Authenticator migration payloads, 2FAS, Aegis (plain), andOTP,
/// Bitwarden TOTP fields, and generic JSON that still contains Base32 secrets
/// (the shape several SafeAuth-style clones write when you export locally).
class VaultFileImporter {
  const VaultFileImporter();

  bool isEncryptedSafeAuth(String content) {
    final map = _asJsonMap(content);
    return map != null && map['format'] == 'safeauth.backup.v1';
  }

  bool looksEncrypted(String content) {
    if (isEncryptedSafeAuth(content)) return true;
    final map = _asJsonMap(content);
    if (map == null) return false;
    final header = map['header'];
    if (header is Map && header['slots'] is List && (header['slots'] as List).isNotEmpty) {
      return true;
    }
    if (map['encrypted'] == true && map['servicesEncrypted'] is String) {
      return true;
    }
    return false;
  }

  /// [decryptedVault] is required when [content] is `safeauth.backup.v1`.
  ImportBundle parse(String content, {VaultData? decryptedVault}) {
    final trimmed = content.trim().replaceFirst(RegExp(r'^\uFEFF'), '');
    if (trimmed.isEmpty) {
      throw const FormatException('That file is empty');
    }

    if (isEncryptedSafeAuth(trimmed)) {
      if (decryptedVault == null) {
        throw const ImportNeedsPassword('SafeAuth backup');
      }
      return ImportBundle(
        format: 'safeauth.backup.v1',
        accounts: decryptedVault.accounts.map(_fromAccount).toList(),
        passwords: decryptedVault.passwords
            .map(
              (p) => PasswordEntry.create(
                title: p.title,
                username: p.username,
                password: p.password,
                url: p.url,
                notes: p.notes,
              ),
            )
            .toList(),
      );
    }

    if (trimmed.contains('otpauth-migration://')) {
      return _fromMigration(trimmed);
    }

    final otpauth = _otpauthLines(trimmed);
    if (otpauth.isNotEmpty && _asJsonMap(trimmed) == null && _asJsonList(trimmed) == null) {
      return ImportBundle(format: 'otpauth', accounts: otpauth);
    }

    final json = _tryJson(trimmed);
    if (json != null) {
      return _fromJson(json, otpauth);
    }

    if (otpauth.isNotEmpty) {
      return ImportBundle(format: 'otpauth', accounts: otpauth);
    }

    throw const FormatException(
      'Not a SafeAuth, otpauth, Google Authenticator, 2FAS, or Aegis file',
    );
  }

  ImportBundle _fromMigration(String raw) {
    final match = RegExp(r'otpauth-migration://[^\s"]+').firstMatch(raw);
    if (match == null) {
      throw const FormatException('Could not read Google Authenticator export');
    }
    final accounts = const GoogleMigrationParser().parse(match.group(0)!);
    if (accounts.isEmpty) {
      throw const FormatException('That Google export had no accounts');
    }
    return ImportBundle(format: 'google-migration', accounts: accounts);
  }

  ImportBundle _fromJson(Object json, List<OtpAccountDraft> extraUris) {
    if (json is Map<String, dynamic>) {
      if (json['db'] is Map || json['header'] is Map) {
        final aegis = _fromAegis(json);
        if (aegis.accounts.isNotEmpty) return _merge(aegis, extraUris);
      }
      if (json['services'] is List || json['schemaVersion'] != null) {
        final twoFas = _from2fas(json);
        if (twoFas.accounts.isNotEmpty) return _merge(twoFas, extraUris);
      }
      if (json['items'] is List) {
        final bitwarden = _fromBitwarden(json);
        if (bitwarden.accounts.isNotEmpty) return _merge(bitwarden, extraUris);
      }
      if (json['accounts'] is List || json['passwords'] is List) {
        final vault = _fromVaultShaped(json);
        if (vault.accounts.isNotEmpty || vault.passwords.isNotEmpty) {
          return _merge(vault, extraUris);
        }
      }
    }

    final walked = _walkSecrets(json);
    if (walked.isEmpty && extraUris.isEmpty) {
      throw const FormatException(
        'No authenticator secrets found in that file',
      );
    }
    final format = json is List ? 'andotp-or-list' : 'json-accounts';
    return _merge(ImportBundle(format: format, accounts: walked), extraUris);
  }

  ImportBundle _fromVaultShaped(Map<String, dynamic> json) {
    final accounts = <OtpAccountDraft>[];
    for (final raw in (json['accounts'] as List? ?? const [])) {
      if (raw is Map) {
        final draft = _draftFromMap(Map<String, dynamic>.from(raw));
        if (draft != null) accounts.add(draft);
      }
    }
    final passwords = <PasswordEntry>[];
    for (final raw in (json['passwords'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final password = '${map['password'] ?? ''}';
      if (password.isEmpty) continue;
      passwords.add(
        PasswordEntry.create(
          title: '${map['title'] ?? map['name'] ?? 'Login'}',
          username: '${map['username'] ?? map['user'] ?? ''}',
          password: password,
          url: '${map['url'] ?? ''}',
          notes: '${map['notes'] ?? ''}',
        ),
      );
    }
    return ImportBundle(
      format: 'safeauth-json',
      accounts: accounts,
      passwords: passwords,
    );
  }

  ImportBundle _fromAegis(Map<String, dynamic> json) {
    final header = json['header'];
    if (header is Map && header['slots'] is List && (header['slots'] as List).isNotEmpty) {
      throw const ImportNeedsPassword('Aegis');
    }
    final db = json['db'];
    final entries = db is Map ? db['entries'] : json['entries'];
    final accounts = <OtpAccountDraft>[];
    if (entries is List) {
      for (final raw in entries) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final info = map['info'] is Map
            ? Map<String, dynamic>.from(map['info'] as Map)
            : map;
        final merged = {
          ...map,
          ...info,
          'secret': info['secret'] ?? map['secret'],
          'issuer': map['issuer'] ?? info['issuer'],
          'label': map['name'] ?? map['label'],
          'algorithm': info['algo'] ?? info['algorithm'] ?? map['algorithm'],
          'type': map['type'] ?? info['type'],
        };
        final draft = _draftFromMap(merged);
        if (draft != null) accounts.add(draft);
      }
    }
    return ImportBundle(format: 'aegis', accounts: accounts);
  }

  ImportBundle _from2fas(Map<String, dynamic> json) {
    if (json['servicesEncrypted'] is String &&
        (json['servicesEncrypted'] as String).isNotEmpty) {
      throw const ImportNeedsPassword('2FAS');
    }
    final accounts = <OtpAccountDraft>[];
    for (final raw in (json['services'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final otp = map['otp'] is Map
          ? Map<String, dynamic>.from(map['otp'] as Map)
          : const <String, dynamic>{};
      final merged = {
        ...map,
        ...otp,
        'secret': map['secret'] ?? otp['secret'],
        'issuer': otp['issuer'] ?? map['issuer'] ?? map['name'],
        'label': otp['account'] ?? map['name'] ?? map['label'],
        'type': otp['tokenType'] ?? otp['type'] ?? map['type'],
      };
      final draft = _draftFromMap(merged);
      if (draft != null) accounts.add(draft);
    }
    return ImportBundle(format: '2fas', accounts: accounts);
  }

  ImportBundle _fromBitwarden(Map<String, dynamic> json) {
    final accounts = <OtpAccountDraft>[];
    for (final raw in (json['items'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final login = item['login'] is Map
          ? Map<String, dynamic>.from(item['login'] as Map)
          : null;
      final totp = '${login?['totp'] ?? item['totp'] ?? ''}';
      if (totp.isEmpty) continue;
      if (totp.startsWith('otpauth://')) {
        try {
          accounts.add(const OtpAuthParser().parse(totp));
        } catch (_) {}
        continue;
      }
      final draft = _draftFromMap({
        'issuer': item['name'] ?? 'Account',
        'label': login?['username'] ?? item['name'] ?? 'account',
        'secret': totp,
      });
      if (draft != null) accounts.add(draft);
    }
    return ImportBundle(format: 'bitwarden', accounts: accounts);
  }

  List<OtpAccountDraft> _walkSecrets(Object? node) {
    final out = <OtpAccountDraft>[];
    final seen = <String>{};

    void add(OtpAccountDraft draft) {
      final key = draft.secret.replaceAll(' ', '').toUpperCase();
      if (seen.add(key)) out.add(draft);
    }

    void walk(Object? value, Map<String, dynamic>? current) {
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final draft = _draftFromMap(map);
        if (draft != null) add(draft);
        for (final nested in map.values) {
          walk(nested, map);
        }
      } else if (value is List) {
        for (final nested in value) {
          walk(nested, current);
        }
      } else if (value is String) {
        final text = value.trim();
        if (text.startsWith('otpauth://')) {
          try {
            add(const OtpAuthParser().parse(text));
          } catch (_) {}
        }
      }
    }

    walk(node, null);
    return out;
  }

  OtpAccountDraft? _draftFromMap(Map<String, dynamic> map) {
    String? secret;
    for (final key in map.keys) {
      final lower = key.toLowerCase().replaceAll('_', '');
      if (lower.contains('encrypted')) continue;
      final value = map[key];
      if (value is String && value.trim().startsWith('otpauth://')) {
        try {
          return const OtpAuthParser().parse(value.trim());
        } catch (_) {}
      }
      if (value is! String) continue;
      if (lower == 'secret' ||
          lower == 'secretkey' ||
          lower == 'otpsecret' ||
          lower == 'otpkey' ||
          lower == 'seed' ||
          lower == 'setupkey' ||
          lower == 'privatekey') {
        if (Base32.isValid(value)) {
          secret = value;
          break;
        }
      }
    }
    secret ??= () {
      for (final key in ['secret', 'secretKey', 'secret_key', 'key']) {
        final value = map[key];
        if (value is String && Base32.isValid(value)) return value;
      }
      return null;
    }();
    if (secret == null) return null;

    String pick(List<String> keys, String fallback) {
      for (final key in keys) {
        for (final entry in map.entries) {
          if (entry.key.toLowerCase() == key.toLowerCase() &&
              entry.value != null &&
              '${entry.value}'.trim().isNotEmpty) {
            return '${entry.value}'.trim();
          }
        }
      }
      return fallback;
    }

    final issuer = pick(
      ['issuer', 'provider', 'service', 'site', 'title', 'name'],
      'Account',
    );
    var label = pick(
      ['label', 'account', 'accountname', 'username', 'email', 'user', 'login'],
      issuer,
    );
    if (label == issuer) {
      label = pick(['name'], issuer);
    }
    var algorithm = pick(['algorithm', 'algo', 'hash'], 'SHA1').toUpperCase();
    algorithm = algorithm.replaceAll('-', '');
    if (algorithm != 'SHA1' && algorithm != 'SHA256' && algorithm != 'SHA512') {
      algorithm = 'SHA1';
    }
    final digits = _asInt(map['digits']) ?? 6;
    final period = _asInt(map['period']) ?? _asInt(map['time']) ?? 30;
    final counter = _asInt(map['counter']) ?? 0;
    var type = pick(['type', 'tokentype', 'tokenType', 'otpType'], 'totp')
        .toLowerCase();
    if (type.contains('hotp')) {
      type = 'hotp';
    } else {
      type = 'totp';
    }
    return OtpAccountDraft(
      type: type,
      secret: secret.replaceAll(' ', '').replaceAll('=', '').toUpperCase(),
      issuer: issuer.isEmpty ? 'Account' : issuer,
      label: label.isEmpty ? issuer : label,
      algorithm: algorithm,
      digits: (digits == 8) ? 8 : 6,
      period: (period >= 10 && period <= 120) ? period : 30,
      counter: counter < 0 ? 0 : counter,
    );
  }

  OtpAccountDraft _fromAccount(TotpAccount account) {
    return OtpAccountDraft(
      type: account.type,
      secret: account.secret,
      issuer: account.issuer,
      label: account.label,
      algorithm: account.algorithm,
      digits: account.digits,
      period: account.period,
      counter: account.counter,
    );
  }

  List<OtpAccountDraft> _otpauthLines(String content) {
    final out = <OtpAccountDraft>[];
    for (final match in RegExp(r'otpauth://[^\s"]+').allMatches(content)) {
      try {
        out.add(const OtpAuthParser().parse(match.group(0)!));
      } catch (_) {}
    }
    return out;
  }

  ImportBundle _merge(ImportBundle base, List<OtpAccountDraft> extra) {
    if (extra.isEmpty) return base;
    final seen = base.accounts
        .map((a) => a.secret.replaceAll(' ', '').toUpperCase())
        .toSet();
    final accounts = [...base.accounts];
    for (final draft in extra) {
      final key = draft.secret.replaceAll(' ', '').toUpperCase();
      if (seen.add(key)) accounts.add(draft);
    }
    return ImportBundle(
      format: base.format,
      accounts: accounts,
      passwords: base.passwords,
    );
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  Map<String, dynamic>? _asJsonMap(String content) {
    final json = _tryJson(content);
    if (json is Map<String, dynamic>) return json;
    return null;
  }

  List<dynamic>? _asJsonList(String content) {
    final json = _tryJson(content);
    if (json is List) return json;
    return null;
  }

  Object? _tryJson(String content) {
    try {
      return jsonDecode(content);
    } catch (_) {
      return null;
    }
  }
}
