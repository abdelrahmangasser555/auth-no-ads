import 'package:flutter/material.dart';

import 'brand_catalog.dart';

class BrandStyle {
  const BrandStyle({
    required this.color,
    required this.letter,
    this.asset,
  });

  final Color color;
  final String letter;
  final String? asset;

  bool get hasIcon => asset != null;
}

BrandStyle brandFor(String issuer, [String extra = '']) {
  final hay = _normalize('$issuer $extra');
  BrandDef? best;
  var bestLen = -1;
  for (final def in brandCatalog) {
    for (final alias in def.aliases) {
      if (alias.isEmpty) continue;
      if (_matches(hay, alias) && alias.length > bestLen) {
        best = def;
        bestLen = alias.length;
      }
    }
  }
  if (best != null) {
    return BrandStyle(
      color: Color(best.color),
      letter: best.letter,
      asset: best.asset,
    );
  }
  final hue = (issuer.hashCode.abs() % 360).toDouble();
  return BrandStyle(
    color: HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor(),
    letter: issuer.trim().isEmpty ? '?' : issuer.trim()[0].toUpperCase(),
  );
}

String _normalize(String raw) {
  return raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _matches(String hay, String alias) {
  if (hay == alias) return true;
  var start = 0;
  while (true) {
    final i = hay.indexOf(alias, start);
    if (i < 0) return false;
    final beforeOk = i == 0 || !_isToken(hay.codeUnitAt(i - 1));
    final after = i + alias.length;
    final afterOk =
        after >= hay.length || !_isToken(hay.codeUnitAt(after));
    if (beforeOk && afterOk) return true;
    start = i + 1;
  }
}

bool _isToken(int code) {
  final isDigit = code >= 48 && code <= 57;
  final isLower = code >= 97 && code <= 122;
  return isDigit || isLower;
}
