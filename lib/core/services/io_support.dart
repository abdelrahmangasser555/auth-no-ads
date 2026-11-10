import 'dart:io';

Future<void> writeVaultFile(String path, String blob) {
  return File(path).writeAsString(blob, flush: true);
}

Future<String?> readVaultFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsString();
}

String joinPath(String dir, String name) => '$dir${Platform.pathSeparator}$name';
