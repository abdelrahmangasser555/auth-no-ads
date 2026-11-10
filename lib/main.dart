import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'ui/phone_frame.dart';
import 'ui/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  runApp(const ProviderScope(child: SafeAuthApp()));
}

class SafeAuthApp extends StatelessWidget {
  const SafeAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth No Ads',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => PhoneShell(child: child ?? const SizedBox.shrink()),
      home: const AppShell(),
    );
  }
}
