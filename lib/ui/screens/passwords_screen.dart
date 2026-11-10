import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../widgets/brand_icon.dart';
import 'add_password_sheet.dart';

class PasswordsScreen extends ConsumerWidget {
  const PasswordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(appControllerProvider).vault;
    if (vault == null) return const SizedBox.shrink();
    final items = vault.passwords;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Password')),
      body: items.isEmpty
          ? _Empty(onAdd: () => _openEditor(context))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return FilledButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Password Now'),
                  );
                }
                final item = items[i - 1];
                return ListTile(
                  tileColor: AppColors.canvas,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: BrandIcon(
                    name: item.title,
                    extra: '${item.url} ${item.username}',
                    size: 40,
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: item.password));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password copied')),
                      );
                    },
                  ),
                  onTap: () => _openEditor(context, existing: item),
                  onLongPress: () => ref
                      .read(appControllerProvider.notifier)
                      .deletePassword(item.id),
                );
              },
            ),
    );
  }

  Future<void> _openEditor(BuildContext context, {PasswordEntry? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddPasswordSheet(existing: existing),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, compact ? 12 : 24, 28, 24),
      child: Column(
        children: [
          SizedBox(height: compact ? 8 : 36),
          CustomPaint(
            size: Size(compact ? 180 : 220, compact ? 100 : 140),
            painter: _LoginArtPainter(),
          ),
          SizedBox(height: compact ? 16 : 28),
          Text(
            'Autofill passwords for faster and\nsafer logins',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          SizedBox(height: compact ? 16 : 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onAdd,
              child: const Text('+  Add Password Now'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF0F2F5),
                foregroundColor: AppColors.text,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Create passwords here, then copy them into apps. A full Android Autofill service is on the experimental roadmap.',
                    ),
                  ),
                );
              },
              child: const Text('Import from Google/Microsoft'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = const Color(0xFF9AA3B2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final r = RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 8, 110, 118),
      const Radius.circular(10),
    );
    canvas.drawRRect(r, border);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(56, 28, 78, 16),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFE8EEF7),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(56, 52, 78, 16),
        const Radius.circular(6),
      ),
      border,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(70, 78, 50, 18),
        const Radius.circular(9),
      ),
      Paint()..color = AppColors.primary,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 70, 48, 54, 42),
        const Radius.circular(8),
      ),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
