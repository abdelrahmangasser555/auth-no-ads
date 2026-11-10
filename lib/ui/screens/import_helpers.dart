import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/import_formats.dart';
import '../../state/app_controller.dart';

class ImportHelpers {
  static Future<void> pickAndImport(
    BuildContext context,
    WidgetRef ref, {
    bool link = false,
  }) async {
    final ctrl = ref.read(appControllerProvider.notifier);
    String? content;
    String? uri;
    String? name;

    if (link && ctrl.files.supported) {
      final picked = await ctrl.files.pickAndLink();
      if (picked == null) return;
      content = picked.content;
      uri = picked.uri;
      name = picked.name;
    } else {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.first.bytes;
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read that file')),
          );
        }
        return;
      }
      content = String.fromCharCodes(bytes);
      name = picked.files.first.name;
    }

    if (!context.mounted) return;
    await importContent(
      context,
      ref,
      content: content,
      uri: uri,
      name: name,
      link: link && uri != null,
    );
  }

  static Future<void> importContent(
    BuildContext context,
    WidgetRef ref, {
    required String content,
    String? uri,
    String? name,
    bool link = false,
    String? password,
  }) async {
    final ctrl = ref.read(appControllerProvider.notifier);
    var secret = password;
    if (ctrl.importer.looksEncrypted(content) && (secret == null || secret.isEmpty)) {
      if (!context.mounted) return;
      secret = await askSecret(
        context,
        title: 'File password',
        subtitle: 'The password you chose when you saved this file.',
      );
      if (secret == null) return;
    }
    try {
      final summary = await ctrl.importFileContent(
        content,
        password: secret,
        uri: uri,
        name: name,
        link: link,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(summary, name))),
      );
    } on ImportNeedsPassword {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That file needs a password')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not read that file. Use a .safeauth backup, otpauth list, or another authenticator export.',
          ),
        ),
      );
    }
  }

  static Future<String?> askSecret(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  static String _message(ImportSummary summary, String? name) {
    if (summary.unchanged) {
      return 'Already up to date';
    }
    final file = name == null || name.isEmpty ? 'that file' : name;
    if (summary.addedAccounts == 0 && summary.addedPasswords == 0) {
      return 'No new accounts in $file. Existing codes were kept.';
    }
    final parts = <String>[];
    if (summary.addedAccounts > 0) {
      parts.add(
        '${summary.addedAccounts} account${summary.addedAccounts == 1 ? '' : 's'}',
      );
    }
    if (summary.addedPasswords > 0) {
      parts.add(
        '${summary.addedPasswords} password${summary.addedPasswords == 1 ? '' : 's'}',
      );
    }
    final linked = summary.linked ? ' Linked for automatic sync.' : '';
    return 'Imported ${parts.join(' and ')} from $file.$linked';
  }
}
