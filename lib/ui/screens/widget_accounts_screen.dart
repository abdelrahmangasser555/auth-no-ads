import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../widgets/brand_icon.dart';

class WidgetAccountsScreen extends ConsumerWidget {
  const WidgetAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(appControllerProvider).vault;
    if (vault == null) return const SizedBox.shrink();
    final selected = vault.settings.widgetAccountIds.toSet();
    final accounts = [...vault.accounts]
      ..sort((a, b) => a.issuer.compareTo(b.issuer));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Home screen widget')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
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
                  'Codes on the home screen',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Add the Auth No Ads widget, then pick up to 8 accounts here. '
                  'Those codes stay on the home screen so you do not have to open the app. '
                  'Tap a row on the widget to copy the current code.',
                  style: TextStyle(height: 1.45, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Add a 2FA account first, then come back and pin it to the widget.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < accounts.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    SwitchListTile(
                      secondary: BrandIcon(
                        name: accounts[i].issuer,
                        extra: accounts[i].label,
                        size: 32,
                      ),
                      title: Text(accounts[i].issuer),
                      subtitle: Text(accounts[i].label),
                      value: selected.contains(accounts[i].id),
                      onChanged: (on) async {
                        if (on && selected.length >= 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'The widget shows up to 8 accounts. Turn one off first.',
                              ),
                            ),
                          );
                          return;
                        }
                        await ref
                            .read(appControllerProvider.notifier)
                            .toggleWidgetAccount(accounts[i].id, on);
                      },
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            selected.isEmpty
                ? 'Nothing selected. The widget will ask you to choose accounts.'
                : '${selected.length} account${selected.length == 1 ? '' : 's'} on the widget.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
