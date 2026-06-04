import 'dart:io';
import 'dart:typed_data';

/// Saves bytes to a temp file. Returns the file path for user feedback (empty on web).
Future<String> downloadBytes(Uint8List bytes, String filename) async {
  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}
