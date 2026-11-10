import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../widgets/brand_mark.dart';
import '../widgets/pin_pad.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String pin = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final snap = ref.read(appControllerProvider);
      if (snap.biometricAvailable) {
        ref.read(appControllerProvider.notifier).unlockBiometric();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(appControllerProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 640;
            return Column(
              children: [
                SizedBox(height: compact ? 16 : 36),
                const AuthNoAdsMark(light: false, size: 28),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Unlock to view your codes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
                if (snap.biometricAvailable) ...[
                  const SizedBox(height: 12),
                  IconButton(
                    iconSize: compact ? 48 : 64,
                    tooltip: 'Unlock with fingerprint',
                    color: AppColors.primary,
                    onPressed: () => ref
                        .read(appControllerProvider.notifier)
                        .unlockBiometric(),
                    icon: const Icon(Icons.fingerprint),
                  ),
                  const Text(
                    'Touch the fingerprint sensor',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
                const Spacer(),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.62,
                  ),
                  child: PinPad(
                    length: pin.length,
                    maxLength: 6,
                    error: snap.error,
                    onDigit: (d) async {
                      if (pin.length >= 6) return;
                      setState(() => pin += d);
                      if (pin.length == 6) {
                        await ref
                            .read(appControllerProvider.notifier)
                            .unlockPin(pin);
                        if (mounted) setState(() => pin = '');
                      }
                    },
                    onBackspace: () {
                      if (pin.isEmpty) return;
                      setState(
                          () => pin = pin.substring(0, pin.length - 1));
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}
