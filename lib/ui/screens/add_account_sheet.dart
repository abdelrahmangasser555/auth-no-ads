import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/otpauth_parser.dart';
import '../../state/app_controller.dart';

class AddAccountSheet extends ConsumerStatefulWidget {
  const AddAccountSheet({super.key, required this.mode});
  final String mode;

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final issuer = TextEditingController();
  final label = TextEditingController();
  final secret = TextEditingController();
  String? error;
  String category = 'Uncategorized';

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(appControllerProvider).vault?.categories ?? ['Uncategorized'];
    final paste = widget.mode == 'paste';
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              paste ? 'Paste authenticator link' : 'Enter setup key',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (paste)
              TextField(
                controller: secret,
                decoration: const InputDecoration(
                  labelText: 'otpauth:// or otpauth-migration://',
                ),
                minLines: 2,
                maxLines: 4,
              )
            else ...[
              TextField(
                controller: issuer,
                decoration: const InputDecoration(labelText: 'Service (GitHub, Google…)'),
              ),
              TextField(
                controller: label,
                decoration: const InputDecoration(labelText: 'Account (email or username)'),
              ),
              TextField(
                controller: secret,
                decoration: const InputDecoration(labelText: 'Setup key'),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: cats.contains(category) ? category : cats.first,
              items: [
                for (final c in cats) DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => category = v ?? 'Uncategorized'),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Add account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      final ctrl = ref.read(appControllerProvider.notifier);
      if (widget.mode == 'paste') {
        final raw = secret.text.trim();
        if (raw.startsWith('otpauth-migration://')) {
          throw const FormatException('Open Scan and point at the Google export QR instead.');
        }
        final draft = const OtpAuthParser().parse(raw);
        await ctrl.addAccount(draft, category: category);
      } else {
        await ctrl.addManualAccount(
          issuer: issuer.text.trim().isEmpty ? 'Account' : issuer.text.trim(),
          label: label.text.trim().isEmpty ? 'personal' : label.text.trim(),
          secret: secret.text,
          category: category,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString().replaceAll('FormatException: ', ''));
    }
  }
}
