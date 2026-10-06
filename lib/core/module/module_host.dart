/// Lightweight namespace helpers for feature modules.
class ModuleHost {
  const ModuleHost({
    required this.id,
    required this.displayName,
    this.themeFeatureId,
  });

  final String id;
  final String displayName;

  /// Theme pack feature key (e.g. `"tasks"` → Mia pack).
  final String? themeFeatureId;
}

/// Known module ids.
class Modules {
  Modules._();

  static const mia = ModuleHost(
    id: 'mia',
    displayName: 'Mia',
    themeFeatureId: 'tasks',
  );
}
