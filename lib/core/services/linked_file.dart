import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LinkedFileSnapshot {
  const LinkedFileSnapshot({
    required this.content,
    this.uri,
    this.name,
    this.missing = false,
  });

  final String content;
  final String? uri;
  final String? name;
  final bool missing;
}

/// Android Storage Access Framework bridge so a chosen SafeAuth file
/// can be re-read later without opening the system picker again.
class LinkedFileBridge {
  LinkedFileBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.personal.safeauth/import');

  final MethodChannel _channel;

  static LinkedFileBridge instance = LinkedFileBridge();

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<LinkedFileSnapshot?> pickAndLink() async {
    if (!supported) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>('pickAndLink');
      return _parse(raw);
    } on PlatformException catch (e) {
      if (e.code == 'canceled') return null;
      rethrow;
    }
  }

  Future<LinkedFileSnapshot?> read(String uri) async {
    if (!supported) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>('readLinked', {'uri': uri});
      return _parse(raw);
    } catch (_) {
      return LinkedFileSnapshot(content: '', uri: uri, missing: true);
    }
  }

  Future<void> unlink(String uri) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('unlink', {'uri': uri});
    } catch (_) {}
  }

  Future<LinkedFileSnapshot?> takeIncoming() async {
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>('takeIncoming');
      return _parse(raw);
    } catch (_) {
      return null;
    }
  }

  LinkedFileSnapshot? _parse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final content = '${map['content'] ?? ''}';
    final missing = map['missing'] == true;
    if (content.isEmpty && !missing) return null;
    return LinkedFileSnapshot(
      content: content,
      uri: map['uri'] as String?,
      name: map['name'] as String?,
      missing: missing,
    );
  }
}
