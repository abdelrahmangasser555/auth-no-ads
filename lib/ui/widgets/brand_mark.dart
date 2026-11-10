import 'package:flutter/material.dart';

class AuthNoAdsMark extends StatelessWidget {
  const AuthNoAdsMark({super.key, this.size = 22, this.light = true});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : const Color(0xFF1A6DFF);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1,
          ),
          children: [
            const TextSpan(text: 'Auth'),
            TextSpan(
              text: ' No Ads',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: size * 0.82,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef SafeAuthMark = AuthNoAdsMark;
