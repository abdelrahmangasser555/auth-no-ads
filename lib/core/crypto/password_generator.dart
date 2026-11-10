import 'dart:math';

class PasswordGenerator {
  PasswordGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  static const lettersLower = 'abcdefghijkmnopqrstuvwxyz';
  static const lettersUpper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const digits = '23456789';
  static const symbols = r'!@#$%^&*()-_=+[]{}';

  String generate({
    int length = 20,
    bool upper = true,
    bool lower = true,
    bool numbers = true,
    bool symbolsEnabled = true,
  }) {
    final pools = <String>[
      if (lower) lettersLower,
      if (upper) lettersUpper,
      if (numbers) digits,
      if (symbolsEnabled) symbols,
    ];
    if (pools.isEmpty || length < 4) {
      throw ArgumentError('Invalid generator settings');
    }
    final all = pools.join();
    final chars = <String>[
      for (final pool in pools) pool[_random.nextInt(pool.length)],
    ];
    while (chars.length < length) {
      chars.add(all[_random.nextInt(all.length)]);
    }
    chars.shuffle(_random);
    return chars.join();
  }
}
