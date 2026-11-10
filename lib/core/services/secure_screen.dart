import 'package:flutter/services.dart';

class SecureScreen {
  static const _channel = MethodChannel('app.personal.safeauth/secure');

  static Future<void> setAllowed(bool allowed) async {
    try {
      await _channel.invokeMethod('setSecure', {'secure': !allowed});
    } on MissingPluginException {
      // Web / desktop preview — nothing to do.
    } catch (_) {
      // Never crash the vault over a screenshot flag.
    }
  }
}
