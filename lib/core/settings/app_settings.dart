import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../prefs/local_flags.dart';

/// App-wide settings (parent / general). Mia reads its slice from here.
class AppSettings extends ChangeNotifier {
  AppSettings();

  ThemeMode _themeMode = ThemeMode.system;
  String _themePackId = 'mia';
  bool _hapticsEnabled = true;
  String _miaDefaultPriority = 'medium';
  bool _miaVoiceTips = true;
  String? _calDefaultCalendarId;

  ThemeMode get themeMode => _themeMode;
  String get themePackId => _themePackId;
  bool get hapticsEnabled => _hapticsEnabled;
  String get miaDefaultPriority => _miaDefaultPriority;
  bool get miaVoiceTips => _miaVoiceTips;

  /// Preferred calendar for new events (Phase 7). Empty = primary.
  String? get calDefaultCalendarId => _calDefaultCalendarId;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'app_settings.json'));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _themeMode = _parseThemeMode(map['themeMode'] as String?);
      _themePackId = map['themePackId'] as String? ?? 'mia';
      _hapticsEnabled = map['hapticsEnabled'] as bool? ?? true;
      _miaDefaultPriority = map['miaDefaultPriority'] as String? ?? 'medium';
      _miaVoiceTips = map['miaVoiceTips'] as bool? ?? true;
      _calDefaultCalendarId = map['calDefaultCalendarId'] as String?;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          'themeMode': _themeMode.name,
          'themePackId': _themePackId,
          'hapticsEnabled': _hapticsEnabled,
          'miaDefaultPriority': _miaDefaultPriority,
          'miaVoiceTips': _miaVoiceTips,
          'calDefaultCalendarId': _calDefaultCalendarId,
        }),
      );
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _persist();
  }

  Future<void> setThemePackId(String id) async {
    _themePackId = id;
    notifyListeners();
    await _persist();
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setMiaDefaultPriority(String value) async {
    _miaDefaultPriority = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setMiaVoiceTips(bool value) async {
    _miaVoiceTips = value;
    if (!value) {
      await LocalFlags.set(LocalFlags.micTipDismissed);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> resetMiaVoiceTip() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, LocalFlags.micTipDismissed));
      if (await file.exists()) await file.delete();
    } catch (_) {}
    _miaVoiceTips = true;
    notifyListeners();
    await _persist();
  }

  Future<void> setCalDefaultCalendarId(String? id) async {
    _calDefaultCalendarId = id;
    notifyListeners();
    await _persist();
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
