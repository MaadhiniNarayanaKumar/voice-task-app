import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// JSON-driven brand pack. Load from assets (or later a remote URL).
class ThemePack {
  const ThemePack({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.primarySoft,
    required this.tint,
    required this.background,
    required this.card,
    required this.text,
    required this.muted,
    required this.softBlue,
    required this.softGreen,
    required this.softAmber,
    required this.softRed,
    required this.low,
    required this.medium,
    required this.high,
    required this.palette,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
  });

  final String id;
  final String name;
  final String description;
  final Color primary;
  final Color primarySoft;
  final Color tint;
  final Color background;
  final Color card;
  final Color text;
  final Color muted;
  final Color softBlue;
  final Color softGreen;
  final Color softAmber;
  final Color softRed;
  final Color low;
  final Color medium;
  final Color high;
  final List<Color> palette;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;

  /// Active pack used by [AppColors] getters.
  static ThemePack current = miaFallback;

  static final ThemePack miaFallback = ThemePack(
    id: 'mia',
    name: 'Mia',
    description: 'Default purple voice-task theme',
    primary: const Color(0xFF4F46E5),
    primarySoft: const Color(0xFF818CF8),
    tint: const Color(0xFFEEF2FF),
    background: const Color(0xFFF3F0FA),
    card: Colors.white,
    text: const Color(0xFF111827),
    muted: const Color(0xFF4B5563),
    softBlue: const Color(0xFFE0F2FE),
    softGreen: const Color(0xFFDCFCE7),
    softAmber: const Color(0xFFFEF3C7),
    softRed: const Color(0xFFFEE2E2),
    low: const Color(0xFF16A34A),
    medium: const Color(0xFFD97706),
    high: const Color(0xFFDC2626),
    palette: const [
      Color(0xFF4F46E5),
      Color(0xFF7C3AED),
      Color(0xFF0284C7),
      Color(0xFF16A34A),
      Color(0xFFD97706),
      Color(0xFFDB2777),
    ],
    radiusSm: 14,
    radiusMd: 16,
    radiusLg: 20,
    radiusXl: 24,
  );

  factory ThemePack.fromJson(Map<String, dynamic> json) {
    final radii = (json['radii'] as Map<String, dynamic>?) ?? const {};
    final paletteJson = (json['palette'] as List?) ?? const [];
    return ThemePack(
      id: json['id'] as String? ?? 'custom',
      name: json['name'] as String? ?? 'Custom',
      description: json['description'] as String? ?? '',
      primary: _color(json['primary'], const Color(0xFF4F46E5)),
      primarySoft: _color(json['primarySoft'], const Color(0xFF818CF8)),
      tint: _color(json['tint'], const Color(0xFFEEF2FF)),
      background: _color(json['background'], const Color(0xFFF3F0FA)),
      card: _color(json['card'], Colors.white),
      text: _color(json['text'], const Color(0xFF111827)),
      muted: _color(json['muted'], const Color(0xFF6B7280)),
      softBlue: _color(json['softBlue'], const Color(0xFFE0F2FE)),
      softGreen: _color(json['softGreen'], const Color(0xFFDCFCE7)),
      softAmber: _color(json['softAmber'], const Color(0xFFFEF3C7)),
      softRed: _color(json['softRed'], const Color(0xFFFEE2E2)),
      low: _color(json['low'], const Color(0xFF16A34A)),
      medium: _color(json['medium'], const Color(0xFFD97706)),
      high: _color(json['high'], const Color(0xFFDC2626)),
      palette: paletteJson
          .map((e) => _color(e, const Color(0xFF4F46E5)))
          .toList(growable: false),
      radiusSm: (radii['sm'] as num?)?.toDouble() ?? 14,
      radiusMd: (radii['md'] as num?)?.toDouble() ?? 16,
      radiusLg: (radii['lg'] as num?)?.toDouble() ?? 20,
      radiusXl: (radii['xl'] as num?)?.toDouble() ?? 24,
    );
  }

  static Color _color(dynamic value, Color fallback) {
    if (value is! String || value.isEmpty) return fallback;
    var hex = value.replaceFirst('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;
    return Color(int.parse(hex, radix: 16));
  }

  static Future<ThemePack> loadAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return ThemePack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<List<ThemeCatalogEntry>> loadCatalog() async {
    try {
      final raw = await rootBundle.loadString('assets/themes/catalog.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = (map['themes'] as List?) ?? const [];
      return list
          .map((e) => ThemeCatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [
        ThemeCatalogEntry(
          id: 'mia',
          asset: 'assets/themes/mia.json',
          feature: 'tasks',
        ),
      ];
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'primary': _hex(primary),
        'primarySoft': _hex(primarySoft),
        'tint': _hex(tint),
        'background': _hex(background),
        'card': _hex(card),
        'text': _hex(text),
        'muted': _hex(muted),
        'softBlue': _hex(softBlue),
        'softGreen': _hex(softGreen),
        'softAmber': _hex(softAmber),
        'softRed': _hex(softRed),
        'low': _hex(low),
        'medium': _hex(medium),
        'high': _hex(high),
        'palette': palette.map(_hex).toList(),
        'radii': {
          'sm': radiusSm,
          'md': radiusMd,
          'lg': radiusLg,
          'xl': radiusXl,
        },
      };

  static String _hex(Color c) {
    final value = c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.substring(2)}';
  }
}

class ThemeCatalogEntry {
  const ThemeCatalogEntry({
    required this.id,
    required this.asset,
    required this.feature,
  });

  final String id;
  final String asset;
  final String feature;

  factory ThemeCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ThemeCatalogEntry(
      id: json['id'] as String,
      asset: json['asset'] as String,
      feature: json['feature'] as String? ?? json['id'] as String,
    );
  }
}
