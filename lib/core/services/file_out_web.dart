import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadTextFile(String name, String contents) async {
  final bytes = utf8.encode(contents);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', name)
    ..click();
  html.Url.revokeObjectUrl(url);
}
