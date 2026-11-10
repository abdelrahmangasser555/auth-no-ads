import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// On a computer, show the app at phone width so it looks like the Galaxy.
class PhoneShell extends StatelessWidget {
  const PhoneShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    final width = MediaQuery.sizeOf(context).width;
    if (width < 500) return child;
    return ColoredBox(
      color: const Color(0xFF0E1116),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 880),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D24),
                borderRadius: BorderRadius.circular(42),
                border: Border.all(color: const Color(0xFF2A2F3A), width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 40,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(38),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
