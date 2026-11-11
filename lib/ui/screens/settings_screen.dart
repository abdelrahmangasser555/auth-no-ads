import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/hibp.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../../state/tab_index.dart';
import 'widget_accounts_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(appControllerProvider).vault;
    if (vault == null) return const SizedBox.shrink();
    final s = vault.settings;
    final score = _score(vault.accounts.length, vault.passwords.length,
        vault.profile.lastBackupAt != null, s.appLock);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Security Health',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        score.label,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${score.value}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text('Security',
                style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
          _card([
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  vault.profile.email.isEmpty
                      ? 'B'
                      : vault.profile.email[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: const Text('Backup file'),
              subtitle: Text(
                vault.profile.lastBackupAt == null
                    ? 'Save or open an encrypted file'
                    : 'Last saved',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ref.read(tabIndexProvider.notifier).state = 2,
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('App Lock'),
              subtitle: const Text('Fingerprint + PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _appLock(context, ref),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.screenshot_monitor_outlined),
              title: const Text('Allow Screenshots'),
              value: s.allowScreenshots,
              onChanged: (v) => ref
                  .read(appControllerProvider.notifier)
                  .patchSettings((x) => x.allowScreenshots = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide 2FA Codes'),
              value: s.hideCodes,
              onChanged: (v) => ref
                  .read(appControllerProvider.notifier)
                  .patchSettings((x) => x.hideCodes = v),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Password Leak Check'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _leakCheck(context, ref),
            ),
          ]),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text('Tools',
                style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
          _card([
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Home screen widget'),
              subtitle: Text(
                s.widgetAccountIds.isEmpty
                    ? 'Pick accounts to show without opening the app'
                    : '${s.widgetAccountIds.length} account${s.widgetAccountIds.length == 1 ? '' : 's'} on the widget',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WidgetAccountsScreen(),
                ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.key_outlined),
              title: Text('Autofill'),
              subtitle: Text('Copy from the Password tab for now'),
            ),
          ]),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Auth No Ads  ·  1.0.0  ·  no ads  ·  AES-256-GCM',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _card(List<Widget> children) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  static ({int value, String label}) _score(
    int codes,
    int passwords,
    bool backup,
    bool lock,
  ) {
    var v = 40;
    if (lock) v += 20;
    if (backup) v += 25;
    if (codes > 0) v += 10;
    if (passwords > 0) v += 5;
    final label = v >= 85
        ? 'Vault looks solid'
        : backup
            ? 'Add a fingerprint lock'
            : 'Back up before you lose this phone';
    return (value: v.clamp(0, 100), label: label);
  }

  static Future<void> _appLock(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appControllerProvider).vault!.settings;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            SwitchListTile(
              title: const Text('Require unlock'),
              value: s.appLock,
              onChanged: (v) {
                ref.read(appControllerProvider.notifier).patchSettings((x) => x.appLock = v);
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              title: const Text('Fingerprint unlock'),
              value: s.biometricUnlock,
              onChanged: (v) {
                ref
                    .read(appControllerProvider.notifier)
                    .patchSettings((x) => x.biometricUnlock = v);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Lock now'),
              leading: const Icon(Icons.lock_outline),
              onTap: () {
                Navigator.pop(context);
                ref.read(appControllerProvider.notifier).lock();
              },
            ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _leakCheck(BuildContext context, WidgetRef ref) async {
    final passwords = ref.read(appControllerProvider).vault?.passwords ?? [];
    if (passwords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a password first')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final client = HibpClient();
    var pwned = 0;
    try {
      for (final p in passwords) {
        pwned += await client.pwnedCount(p.password) > 0 ? 1 : 0;
      }
    } catch (_) {
      pwned = -1;
    }
    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Password leak check'),
        content: Text(
          pwned < 0
              ? 'Could not reach Have I Been Pwned. Try again online.'
              : pwned == 0
                  ? 'None of your saved passwords appear in known leaks.'
                  : '$pwned saved password(s) appeared in known leaks. Change them.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
