import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Saves bytes to an app-private directory (not shared system temp).
Future<String> downloadBytes(Uint8List bytes, String filename) async {
  final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
  final baseDir = await getApplicationDocumentsDirectory();
  final dir = Directory('${baseDir.path}/secure_downloads');
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
