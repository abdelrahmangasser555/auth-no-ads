import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/services/file_out_stub.dart'
    if (dart.library.html) '../../core/services/file_out_web.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import 'import_helpers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  String device = 'this device';

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        if (mounted) setState(() => device = 'this computer');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await info.androidInfo;
        if (mounted) setState(() => device = '${a.brand} ${a.model}');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(appControllerProvider).vault;
    if (vault == null) return const SizedBox.shrink();
    final profile = vault.profile;
    final last = profile.lastBackupAt;
    final email = profile.email.isEmpty ? 'Tap to add your name' : profile.email;
    final backedUp = last != null;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _editProfile(context),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          (profile.displayName.isEmpty
                                  ? 'Y'
                                  : profile.displayName[0])
                              .toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              backedUp ? 'File saved' : 'Not backed up yet',
                              style: TextStyle(
                                color: backedUp
                                    ? AppColors.success
                                    : AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.expand_more, color: AppColors.muted),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _dot(
                  'Last file saved:',
                  last == null
                      ? '-'
                      : DateFormat.yMMMd().add_jm().format(last.toLocal()),
                ),
                const SizedBox(height: 12),
                _dot('In this vault:', ''),
                Padding(
                  padding: const EdgeInsets.only(left: 22, top: 4),
                  child: Text(
                    '2FA codes: ${vault.accounts.length}\nPasswords: ${vault.passwords.length}',
                    style: const TextStyle(height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                _dot('Device:', device),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _sync(context),
                    icon: const Icon(Icons.download),
                    label: const Text('Save codes to a file'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => ImportHelpers.pickAndImport(
                      context,
                      ref,
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Open a backup file'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _migrateCard(context, vault),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How this works',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'There is no cloud account and no database. You get one encrypted .safeauth file.\n\n'
                  '1. Tap Save codes to a file and pick a password.\n'
                  '2. Send that file to yourself (Drive, Telegram, USB).\n'
                  '3. On a new phone, install Auth No Ads, then tap Open a backup file.\n'
                  '4. Enter the same password. All codes appear.\n\n'
                  'Leaving SafeAuth: export or share their file into this app. '
                  'On Android you can link that file so new accounts sync when it changes.',
                  style: TextStyle(height: 1.45, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Icon(Icons.shield_outlined,
              size: 64, color: AppColors.primary.withValues(alpha: 0.85)),
          const SizedBox(height: 8),
          const Text(
            'Without a backup file, clearing app data or reinstalling will lose your codes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _dot(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 8, color: AppColors.success),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (value.isNotEmpty)
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final vault = ref.read(appControllerProvider).vault!;
    final email = TextEditingController(text: vault.profile.email);
    final name = TextEditingController(text: vault.profile.displayName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(appControllerProvider.notifier).setProfile(
            email: email.text.trim(),
            name: name.text.trim(),
          );
    }
  }

  Future<void> _sync(BuildContext context) async {
    final password = await _askSecret(
      context,
      title: 'Password for this file',
      subtitle:
          'You will need this password to open the file later. Use at least 8 characters.',
    );
    if (password == null || password.length < 8) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use at least 8 characters')),
        );
      }
      return;
    }
    final blob =
        await ref.read(appControllerProvider.notifier).makeBackup(password);
    if (kIsWeb) {
      await downloadTextFile('auth-no-ads-backup.safeauth', blob);
    } else {
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(blob.codeUnits),
            mimeType: 'application/json',
            name: 'auth-no-ads-backup.safeauth',
          ),
        ],
        text: 'Encrypted Auth No Ads backup',
      );
    }
    await ref.read(appControllerProvider.notifier).markBackedUp();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('File ready. Keep it somewhere safe with the password.')),
      );
    }
  }

  Widget _migrateCard(BuildContext context, VaultData vault) {
    final profile = vault.profile;
    final linkedName = profile.linkedImportName;
    final lastImport = profile.lastImportAt;
    final hasLink = linkedName.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave SafeAuth',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'SafeAuth keeps codes behind their cloud account. Put a .safeauth file, '
            'otpauth list, Google transfer payload, or another authenticator export '
            'in this app. Accounts merge in. Link the file on Android and it syncs '
            'again whenever the file changes — no need to re-open SafeAuth.',
            style: TextStyle(height: 1.45, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          if (hasLink) ...[
            Text(
              'Syncing $linkedName',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              lastImport == null
                  ? 'Waiting for the first sync'
                  : 'Last sync ${DateFormat.yMMMd().add_jm().format(lastImport.toLocal())}'
                      '${profile.lastImportCount > 0 ? ' · ${profile.lastImportCount} new' : ''}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final summary = await ref
                          .read(appControllerProvider.notifier)
                          .syncLinkedImport();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            summary.unchanged && summary.addedAccounts == 0
                                ? 'Linked file is already in sync'
                                : 'Synced ${summary.addedAccounts} new account(s)',
                          ),
                        ),
                      );
                    },
                    child: const Text('Sync now'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(appControllerProvider.notifier).unlinkImport();
                  },
                  child: const Text('Unlink'),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => ImportHelpers.pickAndImport(
                context,
                ref,
                link: true,
              ),
              icon: const Icon(Icons.link),
              label: Text(
                hasLink ? 'Link a different file' : 'Put a SafeAuth file in the app',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askSecret(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
