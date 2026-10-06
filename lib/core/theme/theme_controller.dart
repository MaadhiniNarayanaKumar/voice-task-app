import 'package:flutter/foundation.dart';

import 'theme_pack.dart';

/// Holds the active JSON theme pack and can switch by feature/id.
class ThemeController extends ChangeNotifier {
  ThemeController();

  ThemePack _pack = ThemePack.miaFallback;
  List<ThemeCatalogEntry> _catalog = const [];
  bool _ready = false;

  ThemePack get pack => _pack;
  List<ThemeCatalogEntry> get catalog => _catalog;
  bool get ready => _ready;

  Future<void> load({String themeId = 'mia'}) async {
    _catalog = await ThemePack.loadCatalog();
    final entry = _catalog.cast<ThemeCatalogEntry?>().firstWhere(
          (e) => e?.id == themeId,
          orElse: () => _catalog.isEmpty ? null : _catalog.first,
        );
    if (entry != null) {
      try {
        _pack = await ThemePack.loadAsset(entry.asset);
      } catch (_) {
        _pack = ThemePack.miaFallback;
      }
    } else {
      try {
        _pack = await ThemePack.loadAsset('assets/themes/mia.json');
      } catch (_) {
        _pack = ThemePack.miaFallback;
      }
    }
    ThemePack.current = _pack;
    _ready = true;
    notifyListeners();
  }

  /// Switch theme by catalog id (e.g. `mia`, `focus`).
  Future<void> setTheme(String themeId) async {
    final entry = _catalog.where((e) => e.id == themeId).firstOrNull;
    if (entry == null) return;
    try {
      _pack = await ThemePack.loadAsset(entry.asset);
      ThemePack.current = _pack;
      notifyListeners();
    } catch (_) {}
  }

  /// Switch theme by feature key from catalog.json (`tasks`, `focus`, …).
  Future<void> setThemeForFeature(String feature) async {
    final entry = _catalog.where((e) => e.feature == feature).firstOrNull;
    if (entry == null) return;
    await setTheme(entry.id);
  }
}
