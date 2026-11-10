import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../state/app_controller.dart';
import '../state/tab_index.dart';
import 'screens/backup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/passwords_screen.dart';
import 'screens/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final snap = ref.read(appControllerProvider);
      if (snap.phase == AppPhase.ready &&
          (snap.vault?.settings.appLock ?? true)) {
        ref.read(appControllerProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(appControllerProvider);
    return switch (snap.phase) {
      AppPhase.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AppPhase.onboarding => const OnboardingScreen(),
      AppPhase.locked => const LockScreen(),
      AppPhase.ready => const _ReadyShell(),
    };
  }
}

class _ReadyShell extends ConsumerWidget {
  const _ReadyShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabIndexProvider);
    final vault = ref.watch(appControllerProvider).vault;
    final needsBackup = vault?.profile.lastBackupAt == null;
    const pages = [
      HomeScreen(),
      PasswordsScreen(),
      BackupScreen(),
      SettingsScreen(),
    ];

    return Listener(
      onPointerDown: (_) =>
          ref.read(appControllerProvider.notifier).bumpActivity(),
      child: Scaffold(
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: Material(
              color: Colors.white,
              elevation: 0,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      _NavTab(
                        label: 'Home',
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        selected: index == 0,
                        onTap: () => _go(ref, 0),
                      ),
                      _NavTab(
                        label: 'Password',
                        icon: Icons.vpn_key_outlined,
                        selectedIcon: Icons.vpn_key,
                        selected: index == 1,
                        onTap: () => _go(ref, 1),
                      ),
                      _NavTab(
                        label: 'Backup',
                        icon: Icons.cloud_outlined,
                        selectedIcon: Icons.cloud,
                        selected: index == 2,
                        badge: needsBackup,
                        onTap: () => _go(ref, 2),
                      ),
                      _NavTab(
                        label: 'Settings',
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        selected: index == 3,
                        onTap: () => _go(ref, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }

  void _go(WidgetRef ref, int i) {
    ref.read(appControllerProvider.notifier).bumpActivity();
    ref.read(tabIndexProvider.notifier).state = i;
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.navInactive;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: color,
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badge,
                  smallSize: 8,
                  backgroundColor: AppColors.warning,
                  child: Icon(selected ? selectedIcon : icon, color: color, size: 22),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
