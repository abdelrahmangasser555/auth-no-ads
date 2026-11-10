import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../widgets/brand_mark.dart';
import '../widgets/pin_pad.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int page = 0;
  String pin = '';
  String confirm = '';
  String? error;
  bool confirming = false;

  @override
  Widget build(BuildContext context) {
    if (page < 3) return _intro();
    return _pin();
  }

  Widget _intro() {
    final slides = [
      (
        Icons.fingerprint,
        'Your codes, locked to you',
        'Fingerprint unlock on your Galaxy, plus a PIN fallback. Secrets never leave this phone unless you export an encrypted backup.'
      ),
      (
        Icons.qr_code_scanner,
        'Same flow you already know',
        'Scan a QR code or type a setup key. Codes refresh every 30 seconds, grouped by category, ready to copy with one tap.'
      ),
      (
        Icons.file_present_outlined,
        'One file is your backup',
        'No cloud account and no database. Save an encrypted file, send it to yourself, and open it on another phone. Same password, all your codes.'
      ),
    ];
    final slide = slides[page];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: AuthNoAdsMark(light: false, size: 26),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: Icon(slide.$1, size: 40, color: AppColors.primary),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          slide.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Container(
                    width: i == page ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == page ? AppColors.primary : AppColors.chipIdle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => setState(() => page++),
                  child: Text(page == 2 ? 'Create my PIN' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pin() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        titleTextStyle: const TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        title: Text(confirming ? 'Confirm PIN' : 'Create a 6-digit PIN'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    confirming
                        ? 'Enter the same PIN once more'
                        : 'This PIN unlocks Auth No Ads if fingerprint is not available.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.78,
                      ),
                      child: PinPad(
                        length: confirming ? confirm.length : pin.length,
                        maxLength: 6,
                        error: error,
                        onDigit: _onDigit,
                        onBackspace: () {
                          setState(() {
                            error = null;
                            if (confirming) {
                              if (confirm.isNotEmpty) {
                                confirm =
                                    confirm.substring(0, confirm.length - 1);
                              }
                            } else if (pin.isNotEmpty) {
                              pin = pin.substring(0, pin.length - 1);
                            }
                          });
                        },
                      ),
                    ),
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

  Future<void> _onDigit(String d) async {
    setState(() => error = null);
    if (confirming) {
      if (confirm.length >= 6) return;
      confirm += d;
      if (confirm.length == 6) {
        if (confirm != pin) {
          setState(() {
            error = 'PINs did not match';
            confirm = '';
          });
          return;
        }
        await ref.read(appControllerProvider.notifier).createPin(pin);
      }
    } else {
      if (pin.length >= 6) return;
      pin += d;
      if (pin.length == 6) {
        setState(() => confirming = true);
      }
    }
    setState(() {});
  }
}
