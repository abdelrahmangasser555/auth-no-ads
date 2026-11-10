import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class TotpAccount {
  TotpAccount({
    required this.id,
    required this.issuer,
    required this.label,
    required this.secret,
    this.algorithm = 'SHA1',
    this.digits = 6,
    this.period = 30,
    this.type = 'totp',
    this.counter = 0,
    this.category = 'Uncategorized',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final String id;
  String issuer;
  String label;
  String secret;
  String algorithm;
  int digits;
  int period;
  String type;
  int counter;
  String category;
  final DateTime createdAt;

  factory TotpAccount.create({
    required String issuer,
    required String label,
    required String secret,
    String algorithm = 'SHA1',
    int digits = 6,
    int period = 30,
    String type = 'totp',
    int counter = 0,
    String category = 'Uncategorized',
  }) {
    return TotpAccount(
      id: _uuid.v4(),
      issuer: issuer,
      label: label,
      secret: secret.replaceAll(' ', '').toUpperCase(),
      algorithm: algorithm,
      digits: digits,
      period: period,
      type: type,
      counter: counter,
      category: category,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'issuer': issuer,
        'label': label,
        'secret': secret,
        'algorithm': algorithm,
        'digits': digits,
        'period': period,
        'type': type,
        'counter': counter,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TotpAccount.fromJson(Map<String, dynamic> json) {
    return TotpAccount(
      id: json['id'] as String,
      issuer: json['issuer'] as String,
      label: json['label'] as String,
      secret: json['secret'] as String,
      algorithm: json['algorithm'] as String? ?? 'SHA1',
      digits: json['digits'] as int? ?? 6,
      period: json['period'] as int? ?? 30,
      type: json['type'] as String? ?? 'totp',
      counter: json['counter'] as int? ?? 0,
      category: json['category'] as String? ?? 'Uncategorized',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class PasswordEntry {
  PasswordEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url = '',
    this.notes = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  final String id;
  String title;
  String username;
  String password;
  String url;
  String notes;
  DateTime updatedAt;

  factory PasswordEntry.create({
    required String title,
    required String username,
    required String password,
    String url = '',
    String notes = '',
  }) {
    return PasswordEntry(
      id: _uuid.v4(),
      title: title,
      username: username,
      password: password,
      url: url,
      notes: notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) {
    return PasswordEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      username: json['username'] as String? ?? '',
      password: json['password'] as String,
      url: json['url'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class VaultProfile {
  VaultProfile({
    this.email = '',
    this.displayName = 'You',
    this.lastBackupAt,
    this.backupDestination = '',
    this.lastImportAt,
    this.lastImportFormat = '',
    this.lastImportCount = 0,
    this.linkedImportName = '',
  });

  String email;
  String displayName;
  DateTime? lastBackupAt;
  String backupDestination;
  DateTime? lastImportAt;
  String lastImportFormat;
  int lastImportCount;
  String linkedImportName;

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'lastBackupAt': lastBackupAt?.toIso8601String(),
        'backupDestination': backupDestination,
        'lastImportAt': lastImportAt?.toIso8601String(),
        'lastImportFormat': lastImportFormat,
        'lastImportCount': lastImportCount,
        'linkedImportName': linkedImportName,
      };

  factory VaultProfile.fromJson(Map<String, dynamic> json) {
    return VaultProfile(
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'You',
      lastBackupAt: DateTime.tryParse(json['lastBackupAt'] as String? ?? ''),
      backupDestination: json['backupDestination'] as String? ?? '',
      lastImportAt: DateTime.tryParse(json['lastImportAt'] as String? ?? ''),
      lastImportFormat: json['lastImportFormat'] as String? ?? '',
      lastImportCount: json['lastImportCount'] as int? ?? 0,
      linkedImportName: json['linkedImportName'] as String? ?? '',
    );
  }
}

class AppSettings {
  AppSettings({
    this.appLock = true,
    this.allowScreenshots = false,
    this.hideCodes = false,
    this.biometricUnlock = true,
    this.autoLockSeconds = 180,
    List<String>? widgetAccountIds,
  }) : widgetAccountIds = widgetAccountIds ?? [];

  bool appLock;
  bool allowScreenshots;
  bool hideCodes;
  bool biometricUnlock;
  int autoLockSeconds;
  List<String> widgetAccountIds;

  Map<String, dynamic> toJson() => {
        'appLock': appLock,
        'allowScreenshots': allowScreenshots,
        'hideCodes': hideCodes,
        'biometricUnlock': biometricUnlock,
        'autoLockSeconds': autoLockSeconds,
        'widgetAccountIds': widgetAccountIds,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      appLock: json['appLock'] as bool? ?? true,
      allowScreenshots: json['allowScreenshots'] as bool? ?? false,
      hideCodes: json['hideCodes'] as bool? ?? false,
      biometricUnlock: json['biometricUnlock'] as bool? ?? true,
      autoLockSeconds: json['autoLockSeconds'] as int? ?? 180,
      widgetAccountIds: ((json['widgetAccountIds'] as List?) ?? const [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

class VaultData {
  VaultData({
    List<TotpAccount>? accounts,
    List<PasswordEntry>? passwords,
    List<String>? categories,
    VaultProfile? profile,
    AppSettings? settings,
  })  : accounts = accounts ?? [],
        passwords = passwords ?? [],
        categories = categories ?? ['Uncategorized', 'Work'],
        profile = profile ?? VaultProfile(),
        settings = settings ?? AppSettings();

  final List<TotpAccount> accounts;
  final List<PasswordEntry> passwords;
  final List<String> categories;
  final VaultProfile profile;
  final AppSettings settings;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'passwords': passwords.map((e) => e.toJson()).toList(),
        'categories': categories,
        'profile': profile.toJson(),
        'settings': settings.toJson(),
      };

  factory VaultData.fromJson(Map<String, dynamic> json) {
    return VaultData(
      accounts: (json['accounts'] as List? ?? [])
          .map((e) => TotpAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
      passwords: (json['passwords'] as List? ?? [])
          .map((e) => PasswordEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: ((json['categories'] as List?) ?? ['Uncategorized', 'Work'])
          .cast<String>(),
      profile: json['profile'] is Map<String, dynamic>
          ? VaultProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : VaultProfile(),
      settings: json['settings'] is Map<String, dynamic>
          ? AppSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : AppSettings(),
    );
  }
}
