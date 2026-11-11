import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// Pushes selected TOTP accounts to the native Android home-screen widget.
class WidgetBridge {
  WidgetBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.personal.safeauth/widget');

  final MethodChannel _channel;

  static WidgetBridge instance = WidgetBridge();

  Future<void> syncAccounts(List<TotpAccount> accounts) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('syncAccounts', {
        'accounts': [
          for (final account in accounts)
            {
              'id': account.id,
              'issuer': account.issuer,
              'label': account.label,
              'secret': account.secret,
              'algorithm': account.algorithm,
              'digits': account.digits,
              'period': account.period,
            },
        ],
      });
    } catch (_) {
      // Widget updates are best-effort; the vault is the source of truth.
    }
  }

  Future<String?> takeLaunchAction() async {
    if (kIsWeb) return null;
    try {
      return await _channel.invokeMethod<String>('takeLaunch');
    } catch (_) {
      return null;
    }
  }
}
