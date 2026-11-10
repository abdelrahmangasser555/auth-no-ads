import 'package:flutter_test/flutter_test.dart';
import 'package:safeauth/core/brand_catalog.dart';
import 'package:safeauth/core/brands.dart';

void main() {
  test('scanned GitHub, AWS, and Google issuers get bundled SVGL icons', () {
    expect(brandFor('GitHub').asset, 'assets/brands/github.svg');
    expect(brandFor('Amazon Web Services').asset, 'assets/brands/aws.svg');
    expect(brandFor('Google').asset, 'assets/brands/google.svg');
    expect(brandFor('gmail').asset, 'assets/brands/gmail.svg');
    expect(brandFor('Heroku').hasIcon, isTrue);
  });

  test('more specific names win over generic ones', () {
    expect(brandFor('Google Calendar').asset, 'assets/brands/google-calendar.svg');
    expect(brandFor('Microsoft Outlook').asset, 'assets/brands/outlook.svg');
    expect(brandFor('Proton Mail').asset, 'assets/brands/proton-mail.svg');
  });

  test('git does not steal GitHub, and unknown issuers fall back to a letter', () {
    expect(brandFor('GitHub').asset, isNot(brandFor('Git').asset));
    final unknown = brandFor('TotallyUnknownBank');
    expect(unknown.hasIcon, isFalse);
    expect(unknown.letter, 'T');
  });

  test('password titles and URLs can resolve an icon', () {
    expect(brandFor('Login', 'https://github.com/me').asset, 'assets/brands/github.svg');
    expect(brandFor('Discord').hasIcon, isTrue);
  });

  test('catalog points at local assets, not the network', () {
    expect(brandCatalog, isNotEmpty);
    for (final def in brandCatalog) {
      expect(def.asset, startsWith('assets/brands/'));
      expect(def.asset, endsWith('.svg'));
    }
  });
}
