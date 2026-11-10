import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.maxLength,
    required this.onDigit,
    required this.onBackspace,
    this.error,
  });

  final int length;
  final int maxLength;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 460.0;
        final scale = min(1.0, max(0.62, maxH / 430));
        final keySize = 72.0 * scale;
        final gap = 8.0 * scale;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxLength, (i) {
                  final filled = i < length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color:
                            error != null ? AppColors.danger : AppColors.primary,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 22,
              child: Text(
                error ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', '⌫'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((key) {
                  if (key.isEmpty) {
                    return SizedBox(width: keySize, height: keySize);
                  }
                  return Padding(
                    padding: EdgeInsets.all(gap),
                    child: Semantics(
                      button: true,
                      label: key == '⌫' ? 'Backspace' : key,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (key == '⌫') {
                            onBackspace();
                          } else {
                            onDigit(key);
                          }
                        },
                        child: Ink(
                          width: keySize,
                          height: keySize,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F3F6),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: key == '⌫'
                                ? Icon(Icons.backspace_outlined,
                                    size: 22 * scale)
                                : Text(
                                    key,
                                    style: TextStyle(
                                      fontSize: 26 * scale,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }
}
