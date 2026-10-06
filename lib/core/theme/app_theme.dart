import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_pack.dart';

/// Brand colors always read from the active [ThemePack] (JSON-driven).
class AppColors {
  static ThemePack get _p => ThemePack.current;

  static Color get indigo => _p.primary;
  static Color get indigoSoft => _p.primarySoft;
  static Color get tint => _p.tint;
  static Color get softBlue => _p.softBlue;
  static Color get softGreen => _p.softGreen;
  static Color get softAmber => _p.softAmber;
  static Color get softRed => _p.softRed;
  static Color get background => _p.background;
  static Color get card => _p.card;
  static Color get text => _p.text;
  static Color get muted => _p.muted;
  static Color get low => _p.low;
  static Color get medium => _p.medium;
  static Color get high => _p.high;

  static Color priority(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return high;
      case 'medium':
        return medium;
      default:
        return low;
    }
  }

  static List<Color> get palette => _p.palette;

  static Color categoryDot(String name) {
    final colors = palette;
    if (colors.isEmpty) return indigo;
    return colors[name.hashCode.abs() % colors.length];
  }

  static Color categoryColor(int index) {
    final colors = palette;
    if (colors.isEmpty) return indigo;
    return colors[index.abs() % colors.length];
  }
}

class AppRadii {
  static ThemePack get _p => ThemePack.current;
  static double get sm => _p.radiusSm;
  static double get md => _p.radiusMd;
  static double get lg => _p.radiusLg;
  static double get xl => _p.radiusXl;
  /// Pills, chips, and circular buttons.
  static const pill = 999.0;
}

class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppTheme {
  static ThemeData light([ThemePack? pack]) {
    final p = pack ?? ThemePack.current;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        primary: p.primary,
        surface: p.card,
      ),
      scaffoldBackgroundColor: p.background,
    );

    final text = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: p.text,
      displayColor: p.text,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.35),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: p.text,
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: p.card),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(p.radiusLg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.tint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.radiusSm),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: p.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(p.radiusMd),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: p.primarySoft.withValues(alpha: 0.55)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(p.radiusMd),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.muted,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(p.radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        showDragHandle: true,
        dragHandleColor: const Color(0xFFD1D5DB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(p.radiusXl)),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.8),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return Colors.transparent;
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );
  }

  static ThemeData dark([ThemePack? pack]) {
    final p = pack ?? ThemePack.current;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: Brightness.dark,
        primary: p.primarySoft,
      ),
      scaffoldBackgroundColor: const Color(0xFF111827),
    );
    final text = GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1F2937),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(p.radiusLg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF374151),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.radiusSm),
          borderSide: BorderSide(color: p.primarySoft, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(p.radiusMd),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(p.radiusXl)),
        ),
      ),
    );
  }

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF111827).withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.indigo.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];
}
