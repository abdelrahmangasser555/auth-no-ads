import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/crypto/migration.dart';
import '../../core/crypto/otpauth_parser.dart';
import '../../state/app_controller.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool handling = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Scan QR code')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                error ?? 'Point the camera at the authenticator QR code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: error == null ? Colors.white : Colors.orange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (handling) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;
    handling = true;
    try {
      final ctrl = ref.read(appControllerProvider.notifier);
      if (raw.startsWith('otpauth-migration://')) {
        final accounts = const GoogleMigrationParser().parse(raw);
        for (final draft in accounts) {
          await ctrl.addAccount(draft);
        }
      } else {
        await ctrl.addAccount(const OtpAuthParser().parse(raw));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        error = 'That QR is not a 2FA code.';
        handling = false;
      });
    }
  }
}
