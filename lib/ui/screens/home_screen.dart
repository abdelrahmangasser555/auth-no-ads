import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../../state/tab_index.dart';
import '../widgets/account_card.dart';
import '../widgets/brand_mark.dart';
import 'add_account_sheet.dart';
import 'scan_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final ticker = createTicker((_) {
    if (mounted) setState(() => now = DateTime.now().toUtc());
  });
  DateTime now = DateTime.now().toUtc();
  String category = 'All';
  String query = '';
  bool searching = false;

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(appControllerProvider);
    final vault = snap.vault;
    if (vault == null) return const SizedBox.shrink();
    final cats = ['All', ...vault.categories];
    var accounts = vault.accounts.toList();
    if (category != 'All') {
      accounts = accounts.where((a) => a.category == category).toList();
    }
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      accounts = accounts
          .where((a) =>
              a.issuer.toLowerCase().contains(q) ||
              a.label.toLowerCase().contains(q))
          .toList();
    }
    accounts.sort((a, b) => a.issuer.compareTo(b.issuer));
    final grouped = <String, int>{};
    for (final a in accounts) {
      grouped[a.category] = (grouped[a.category] ?? 0) + 1;
    }
    final backedUp = vault.profile.lastBackupAt != null;
    final compact = MediaQuery.sizeOf(context).height < 700;
    if (vault.accounts.isNotEmpty) {
      if (!ticker.isTicking) ticker.start();
    } else if (ticker.isTicking) {
      ticker.stop();
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: searching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Search accounts',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => query = v),
              )
            : const AuthNoAdsMark(),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.diamond_outlined, color: AppColors.gold),
          ),
          IconButton(
            tooltip: 'How this app works',
            onPressed: () => _help(context),
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () => setState(() {
              searching = !searching;
              if (!searching) query = '';
            }),
            icon: Icon(searching ? Icons.close : Icons.search),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Semantics(
          button: true,
          label: 'Add account',
          child: FloatingActionButton(
            tooltip: 'Add account',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => _add(context),
            child: const Icon(Icons.add, size: 30),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          if (!backedUp)
            TextButton(
              onPressed: () => ref.read(tabIndexProvider.notifier).state = 2,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Save a backup file so you never lose these codes.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: category == c,
                      label: Text(c),
                      selectedColor: const Color(0xFF2B2F36),
                      labelStyle: TextStyle(
                        color: category == c ? Colors.white : AppColors.chipTextIdle,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: AppColors.chipIdle,
                      side: BorderSide.none,
                      onSelected: (_) => setState(() => category = c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: compact ? 8 : 20),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: compact ? 36 : 48,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  const Text(
                    'No accounts yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap + and scan the QR code from GitHub, Google, AWS, or any site that shows an authenticator code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref
                        .read(appControllerProvider.notifier)
                        .loadPreviewAccounts(),
                    child: const Text('Show example cards'),
                  ),
                ],
              ),
            ),
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(
                '${entry.key} (${entry.value})',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final account
                in accounts.where((a) => a.category == entry.key)) ...[
              AccountCard(
                account: account,
                now: now,
                hideCode: vault.settings.hideCodes,
                otp: ref.read(appControllerProvider.notifier).otp,
                onCopy: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied')),
                  );
                },
                onMenu: () => _menu(account.id, account.issuer),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  void _help(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to add an account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 10),
              Text(
                '1. Open the website or app you want to protect (GitHub, Google, AWS…).\n'
                '2. Find “Authenticator app” or “2-step verification”.\n'
                '3. Tap + here and scan the QR code, or type the setup key.\n'
                '4. Copy the 6-digit code and paste it back on the website.\n\n'
                'Codes work offline. Keep an encrypted backup so you never get locked out.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
              title: const Text('Scan QR code'),
              onTap: () => Navigator.pop(context, 'scan'),
            ),
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined, color: AppColors.primary),
              title: const Text('Enter setup key'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste, color: AppColors.primary),
              title: const Text('Paste otpauth:// link'),
              onTap: () => Navigator.pop(context, 'paste'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'scan') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddAccountSheet(mode: choice),
      );
    }
  }

  Future<void> _menu(String id, String issuer) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: Text('Edit $issuer'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete $issuer'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'delete') {
      await ref.read(appControllerProvider.notifier).deleteAccount(id);
    }
    if (action == 'edit') {
      await _edit(id);
    }
  }

  Future<void> _edit(String id) async {
    final vault = ref.read(appControllerProvider).vault;
    if (vault == null) return;
    final matches = vault.accounts.where((a) => a.id == id);
    if (matches.isEmpty) return;
    final account = matches.first;
    final issuer = TextEditingController(text: account.issuer);
    final label = TextEditingController(text: account.label);
    final cats = vault.categories;
    var category = account.category;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Edit account',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  TextField(
                    controller: issuer,
                    decoration: const InputDecoration(labelText: 'Service'),
                  ),
                  TextField(
                    controller: label,
                    decoration: const InputDecoration(labelText: 'Account'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: cats.contains(category) ? category : cats.first,
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setLocal(() => category = v ?? category),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok == true) {
      account.issuer = issuer.text.trim();
      account.label = label.text.trim();
      account.category = category;
      await ref.read(appControllerProvider.notifier).updateAccount(account);
    }
  }
}
