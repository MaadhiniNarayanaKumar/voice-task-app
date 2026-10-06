import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Tiny file-backed flags for one-time UI tips.
class LocalFlags {
  LocalFlags._();

  static const micTipDismissed = 'mia_mic_tip_dismissed';

  static Future<File> _file(String key) async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, key));
  }

  static Future<bool> isSet(String key) async {
    try {
      return (await _file(key)).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> set(String key) async {
    try {
      final file = await _file(key);
      await file.writeAsString('1');
    } catch (_) {}
  }
}
