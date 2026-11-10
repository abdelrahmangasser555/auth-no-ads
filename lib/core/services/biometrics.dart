import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class BiometricGate {
  BiometricGate({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final can = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (!can && !supported) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty || supported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Unlock Auth No Ads'}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Unlock Auth No Ads',
            biometricHint: 'Touch the fingerprint sensor',
            biometricNotRecognized: 'Fingerprint not recognized',
            biometricSuccess: 'Unlocked',
            cancelButton: 'Use PIN',
            biometricRequiredTitle: 'Fingerprint required',
            deviceCredentialsRequiredTitle: 'Unlock your phone',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
