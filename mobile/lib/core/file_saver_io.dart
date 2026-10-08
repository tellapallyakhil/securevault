import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<String> saveDecryptedBytes(String filename, List<int> bytes) async {
  // 1. Try public Download folder on Android
  if (Platform.isAndroid) {
    try {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (publicDownloads.existsSync()) {
        final f = File('${publicDownloads.path}/$filename');
        await f.writeAsBytes(bytes, flush: true);
        debugPrint('Saved to public Downloads: ${f.path}');
        return f.path;
      }
    } catch (e) {
      debugPrint('Public download folder write note: $e');
    }

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final f = File('${extDir.path}/$filename');
        await f.writeAsBytes(bytes, flush: true);
        debugPrint('Saved to external storage: ${f.path}');
        return f.path;
      }
    } catch (e) {
      debugPrint('External storage write note: $e');
    }
  }

  // 2. Application documents directory (always writable)
  final appDir = await getApplicationDocumentsDirectory();
  final downloadDir = Directory('${appDir.path}/downloads');
  if (!downloadDir.existsSync()) {
    await downloadDir.create(recursive: true);
  }
  final f = File('${downloadDir.path}/$filename');
  await f.writeAsBytes(bytes, flush: true);
  debugPrint('Saved to app documents: ${f.path}');
  return f.path;
}
