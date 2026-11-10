import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/ui/widgets/brand_mark.dart';

void main() {
  testWidgets('Auth No Ads brand mark renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AuthNoAdsMark(light: false))),
    );
    expect(find.textContaining('Auth'), findsWidgets);
    expect(find.textContaining('No Ads'), findsWidgets);
  });
}
