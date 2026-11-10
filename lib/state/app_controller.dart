import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/crypto/base32.dart';
import '../core/crypto/otp_engine.dart';
import '../core/crypto/otpauth_parser.dart';
import '../core/models/models.dart';
import '../core/services/biometrics.dart';
import '../core/services/secure_screen.dart';
import '../core/services/vault_store.dart';

enum AppPhase { loading, onboarding, locked, ready }

class AppSnapshot {
  const AppSnapshot({
    required this.phase,
    this.vault,
    this.master,
    this.error,
    this.lockout,
    this.biometricAvailable = false,
  });

  final AppPhase phase;
  final VaultData? vault;
  final List<int>? master;
  final String? error;
  final Duration? lockout;
  final bool biometricAvailable;

  AppSnapshot copyWith({
    AppPhase? phase,
    VaultData? vault,
    List<int>? master,
    String? error,
    Duration? lockout,
    bool? biometricAvailable,
    bool clearError = false,
  }) {
    return AppSnapshot(
      phase: phase ?? this.phase,
      vault: vault ?? this.vault,
      master: master ?? this.master,
      error: clearError ? null : (error ?? this.error),
      lockout: lockout ?? this.lockout,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    );
  }
}

class AppController extends Notifier<AppSnapshot> {
  final VaultStore store;
  final BiometricGate biometrics;
  final OtpEngine otp;

  AppController({
    VaultStore? store,
    BiometricGate? biometrics,
    OtpEngine? otp,
  })  : store = store ?? VaultStore(),
        biometrics = biometrics ?? BiometricGate(),
        otp = otp ?? const OtpEngine();

  Timer? _lockTimer;

  @override
  AppSnapshot build() {
    ref.onDispose(() => _lockTimer?.cancel());
    Future.microtask(bootstrap);
    return const AppSnapshot(phase: AppPhase.loading);
  }

  Future<void> bootstrap() async {
    final bio = await biometrics.isAvailable();
    final exists = await store.hasVault();
    if (!exists) {
      state = AppSnapshot(
        phase: AppPhase.onboarding,
        biometricAvailable: bio,
      );
      return;
    }
    state = AppSnapshot(
      phase: AppPhase.locked,
      biometricAvailable: bio,
    );
    if (bio) {
      await unlockBiometric();
    }
  }

  Future<void> createPin(String pin) async {
    await store.createVault(pin: pin);
    final master = await store.unlockWithPin(pin);
    final vault = await store.load(master);
    state = AppSnapshot(
      phase: AppPhase.ready,
      vault: vault,
      master: master,
      biometricAvailable: state.biometricAvailable,
    );
    await SecureScreen.setAllowed(vault.settings.allowScreenshots);
    _armAutoLock();
  }

  Future<void> unlockPin(String pin) async {
    try {
      final master = await store.unlockWithPin(pin);
      final vault = await store.load(master);
      state = AppSnapshot(
        phase: AppPhase.ready,
        vault: vault,
        master: master,
        biometricAvailable: state.biometricAvailable,
      );
      await SecureScreen.setAllowed(vault.settings.allowScreenshots);
      _armAutoLock();
    } on VaultLockedOut catch (e) {
      state = state.copyWith(
        error: 'Too many attempts. Try again in ${e.remaining.inSeconds}s',
        lockout: e.remaining,
      );
    } on VaultAuthFailed {
      state = state.copyWith(error: 'Wrong PIN. Try fingerprint or wait.');
    } catch (e) {
      state = state.copyWith(error: 'Could not unlock ($e)');
    }
  }

  Future<void> unlockBiometric() async {
    final ok = await biometrics.authenticate();
    if (!ok) return;
    try {
      final master = await store.unlockWithBiometrics();
      final vault = await store.load(master);
      state = AppSnapshot(
        phase: AppPhase.ready,
        vault: vault,
        master: master,
        biometricAvailable: true,
      );
      await SecureScreen.setAllowed(vault.settings.allowScreenshots);
      _armAutoLock();
    } catch (e) {
      state = state.copyWith(error: 'Fingerprint unlock failed. Use your PIN.');
    }
  }

  void lock() {
    _lockTimer?.cancel();
    final master = state.master;
    if (master != null) {
      for (var i = 0; i < master.length; i++) {
        master[i] = 0;
      }
    }
    state = AppSnapshot(
      phase: AppPhase.locked,
      biometricAvailable: state.biometricAvailable,
    );
  }

  void _armAutoLock() {
    _lockTimer?.cancel();
    final seconds = state.vault?.settings.autoLockSeconds ?? 180;
    if (seconds <= 0) return;
    _lockTimer = Timer(Duration(seconds: seconds), lock);
  }

  void bumpActivity() => _armAutoLock();

  Future<void> _save(VaultData vault) async {
    final master = state.master;
    if (master == null) return;
    await store.persist(vault, master);
    state = state.copyWith(vault: vault);
    await SecureScreen.setAllowed(vault.settings.allowScreenshots);
    _armAutoLock();
  }

  Future<void> addAccount(OtpAccountDraft draft, {String category = 'Uncategorized'}) async {
    final vault = state.vault;
    if (vault == null) return;
    final account = TotpAccount.create(
      issuer: draft.issuer,
      label: draft.label,
      secret: draft.secret,
      algorithm: draft.algorithm,
      digits: draft.digits,
      period: draft.period,
      type: draft.type,
      counter: draft.counter,
      category: category,
    );
    vault.accounts.add(account);
    if (!vault.categories.contains(category)) {
      vault.categories.add(category);
    }
    await _save(vault);
  }

  Future<void> addManualAccount({
    required String issuer,
    required String label,
    required String secret,
    String category = 'Uncategorized',
  }) async {
    if (!Base32.isValid(secret)) {
      throw const FormatException('That setup key is not valid Base32');
    }
    await addAccount(
      OtpAccountDraft(
        type: 'totp',
        secret: secret,
        issuer: issuer,
        label: label,
        algorithm: 'SHA1',
        digits: 6,
        period: 30,
      ),
      category: category,
    );
  }

  Future<void> loadPreviewAccounts() async {
    if ((state.vault?.accounts.isNotEmpty) ?? true) return;
    const sample = 'JBSWY3DPEHPK3PXP';
    await addManualAccount(
      issuer: 'GitHub',
      label: 'you@example.com',
      secret: sample,
      category: 'Work',
    );
    await addManualAccount(
      issuer: 'Amazon Web Services',
      label: 'root · example',
      secret: sample,
      category: 'Work',
    );
    await addManualAccount(
      issuer: 'Heroku',
      label: 'you@example.com',
      secret: sample,
    );
    final vault = state.vault;
    if (vault != null && vault.passwords.isEmpty) {
      vault.passwords.add(
        PasswordEntry.create(
          title: 'GitHub',
          username: 'you@example.com',
          password: 'example-only',
          url: 'https://github.com',
          notes: 'Demo card. Replace with a real login.',
        ),
      );
      await _save(vault);
    }
  }

  Future<void> deleteAccount(String id) async {
    final vault = state.vault;
    if (vault == null) return;
    vault.accounts.removeWhere((a) => a.id == id);
    await _save(vault);
  }

  Future<void> updateAccount(TotpAccount account) async {
    final vault = state.vault;
    if (vault == null) return;
    final i = vault.accounts.indexWhere((a) => a.id == account.id);
    if (i < 0) return;
    vault.accounts[i] = account;
    await _save(vault);
  }

  Future<void> addPassword(PasswordEntry entry) async {
    final vault = state.vault;
    if (vault == null) return;
    vault.passwords.add(entry);
    await _save(vault);
  }

  Future<void> updatePassword(PasswordEntry entry) async {
    final vault = state.vault;
    if (vault == null) return;
    final i = vault.passwords.indexWhere((p) => p.id == entry.id);
    if (i < 0) return;
    vault.passwords[i] = entry;
    await _save(vault);
  }

  Future<void> deletePassword(String id) async {
    final vault = state.vault;
    if (vault == null) return;
    vault.passwords.removeWhere((p) => p.id == id);
    await _save(vault);
  }

  Future<void> setProfile({required String email, required String name}) async {
    final vault = state.vault;
    if (vault == null) return;
    vault.profile.email = email;
    vault.profile.displayName = name;
    await _save(vault);
  }

  Future<void> markBackedUp() async {
    final vault = state.vault;
    if (vault == null) return;
    vault.profile.lastBackupAt = DateTime.now().toUtc();
    await _save(vault);
  }

  Future<void> patchSettings(void Function(AppSettings s) edit) async {
    final vault = state.vault;
    if (vault == null) return;
    edit(vault.settings);
    await _save(vault);
  }

  Future<String> makeBackup(String password) {
    return store.exportBackup(data: state.vault!, password: password);
  }

  Future<void> restoreBackup(String file, String password) async {
    final imported = await store.importBackup(file: file, password: password);
    final vault = state.vault;
    if (vault == null) {
      await _save(imported);
      return;
    }
    for (final account in imported.accounts) {
      final dup = vault.accounts.any((a) => a.secret == account.secret);
      if (!dup) vault.accounts.add(account);
    }
    for (final password in imported.passwords) {
      final dup = vault.passwords.any(
        (p) => p.title == password.title && p.username == password.username,
      );
      if (!dup) vault.passwords.add(password);
    }
    imported.profile.lastBackupAt = DateTime.now().toUtc();
    vault.profile.lastBackupAt = DateTime.now().toUtc();
    if (vault.profile.email.isEmpty) {
      vault.profile.email = imported.profile.email;
    }
    await _save(vault);
  }
}

final appControllerProvider =
    NotifierProvider<AppController, AppSnapshot>(AppController.new);
