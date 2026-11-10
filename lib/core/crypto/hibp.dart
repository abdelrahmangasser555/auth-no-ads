import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Have I Been Pwned k-anonymity API.
/// Only the first 5 hex chars of the SHA-1 hash leave the device.
class HibpClient {
  HibpClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _endpoint = 'https://api.pwnedpasswords.com/range/';

  Future<int> pwnedCount(String password) async {
    final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    final prefix = hash.substring(0, 5);
    final suffix = hash.substring(5);
    final response = await _client.get(
      Uri.parse('$_endpoint$prefix'),
      headers: const {
        'Add-Padding': 'true',
        'User-Agent': 'AuthNoAds/1.0',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Leak check is unavailable right now');
    }
    for (final line in response.body.split('\n')) {
      final parts = line.trim().split(':');
      if (parts.length == 2 && parts[0].toUpperCase() == suffix) {
        return int.tryParse(parts[1].trim()) ?? 0;
      }
    }
    return 0;
  }
}
