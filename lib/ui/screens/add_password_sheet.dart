import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/password_generator.dart';
import '../../core/models/models.dart';
import '../../state/app_controller.dart';

class AddPasswordSheet extends ConsumerStatefulWidget {
  const AddPasswordSheet({super.key, this.existing});
  final PasswordEntry? existing;

  @override
  ConsumerState<AddPasswordSheet> createState() => _AddPasswordSheetState();
}

class _AddPasswordSheetState extends ConsumerState<AddPasswordSheet> {
  late final title = TextEditingController(text: widget.existing?.title);
  late final username = TextEditingController(text: widget.existing?.username);
  late final password = TextEditingController(text: widget.existing?.password);
  late final url = TextEditingController(text: widget.existing?.url);
  bool hide = true;

  @override
  Widget build(BuildContext context) {
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
              widget.existing == null ? 'Add password' : 'Edit password',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Website or app')),
            TextField(controller: username, decoration: const InputDecoration(labelText: 'Username or email')),
            TextField(
              controller: password,
              obscureText: hide,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => hide = !hide),
                ),
              ),
            ),
            TextField(controller: url, decoration: const InputDecoration(labelText: 'Website (optional)')),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  password.text = PasswordGenerator().generate();
                  setState(() {});
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate a strong password'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  final entry = widget.existing ??
                      PasswordEntry.create(
                        title: title.text.trim(),
                        username: username.text.trim(),
                        password: password.text,
                        url: url.text.trim(),
                      );
                  entry.title = title.text.trim();
                  entry.username = username.text.trim();
                  entry.password = password.text;
                  entry.url = url.text.trim();
                  entry.updatedAt = DateTime.now().toUtc();
                  if (widget.existing == null) {
                    await ref.read(appControllerProvider.notifier).addPassword(entry);
                  } else {
                    await ref.read(appControllerProvider.notifier).updatePassword(entry);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
