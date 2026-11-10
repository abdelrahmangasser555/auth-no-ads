import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safeauth/core/crypto/hibp.dart';

void main() {
  test('HIBP k-anonymity only sends the first 5 hash characters', () async {
    const password = 'hunter2-unique-passphrase';
    final full = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    final prefix = full.substring(0, 5);
    final suffix = full.substring(5);
    late Uri seen;

    final client = MockClient((request) async {
      seen = request.url;
      expect(request.url.toString().contains(password), isFalse);
      expect(request.url.toString().contains(full), isFalse);
      expect(request.url.toString().contains(suffix), isFalse);
      expect(request.headers['Add-Padding'], 'true');
      return http.Response('$suffix:12\r\nAAAAAA:1\n', 200);
    });

    final count = await HibpClient(client: client).pwnedCount(password);
    expect(count, 12);
    expect(seen.path, endsWith('/range/$prefix'));
    expect(seen.host, 'api.pwnedpasswords.com');
    expect(seen.scheme, 'https');
  });

  test('HIBP hashes UTF-8, not Dart code units', () async {
    const password = 'päss';
    final expected =
        sha1.convert(utf8.encode(password)).toString().toUpperCase();
    late Uri seen;
    final client = MockClient((request) async {
      seen = request.url;
      return http.Response('DEAD:1\n', 200);
    });
    await HibpClient(client: client).pwnedCount(password);
    expect(seen.path, endsWith('/range/${expected.substring(0, 5)}'));
  });

  test('HIBP returns zero when the suffix is absent', () async {
    final client = MockClient(
      (_) async => http.Response('FFFFFF:9\n', 200),
    );
    expect(await HibpClient(client: client).pwnedCount('unique-never'), 0);
  });

  test('HIBP fails closed on HTTP errors', () async {
    final client = MockClient((_) async => http.Response('nope', 503));
    await expectLater(
      HibpClient(client: client).pwnedCount('x'),
      throwsA(anything),
    );
  });
}
