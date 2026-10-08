import 'package:flutter/material.dart';

/// FuelFlow theme system — "Latte" (light) and "Mocha" (dark).
/// Warm, coffee-inspired palette with a professional business feel.
class AppTheme {
  AppTheme._();

  // ---------- LATTE (Light) PALETTE ----------
  static const Color latteBackground = Color(0xFFF7F1EA);
  static const Color latteSurface = Color(0xFFFFFFFF);
  static const Color lattePrimary = Color(0xFF6F4E37); // coffee brown
  static const Color latteSecondary = Color(0xFFC08552); // caramel
  static const Color latteError = Color(0xFFB3261E);
  static const Color latteOnPrimary = Color(0xFFFFFFFF);
  static const Color latteText = Color(0xFF2B2119);

  // ---------- MOCHA (Dark) PALETTE ----------
  static const Color mochaBackground = Color(0xFF1E1712);
  static const Color mochaSurface = Color(0xFF2A2019);
  static const Color mochaPrimary = Color(0xFFD8A26E); // latte foam gold
  static const Color mochaSecondary = Color(0xFFA47148); // roasted caramel
  static const Color mochaError = Color(0xFFFFB4AB);
  static const Color mochaOnPrimary = Color(0xFF3A2A1A);
  static const Color mochaText = Color(0xFFEDE0D4);

  static ThemeData get latteTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: lattePrimary,
      brightness: Brightness.light,
      primary: lattePrimary,
      secondary: latteSecondary,
      error: latteError,
      surface: latteSurface,
      onPrimary: latteOnPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: latteBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: latteBackground,
        foregroundColor: latteText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(color: latteText, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      textTheme: _textTheme(latteText),
      cardTheme: CardThemeData(
        color: latteSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lattePrimary,
          foregroundColor: latteOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: latteSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lattePrimary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lattePrimary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lattePrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: latteError),
        ),
      ),
      dividerColor: lattePrimary.withValues(alpha: 0.12),
    );
  }

  static ThemeData get mochaTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: mochaPrimary,
      brightness: Brightness.dark,
      primary: mochaPrimary,
      secondary: mochaSecondary,
      error: mochaError,
      surface: mochaSurface,
      onPrimary: mochaOnPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: mochaBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: mochaBackground,
        foregroundColor: mochaText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(color: mochaText, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      textTheme: _textTheme(mochaText),
      cardTheme: CardThemeData(
        color: mochaSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mochaPrimary,
          foregroundColor: mochaOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mochaSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mochaPrimary.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mochaPrimary.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mochaPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mochaError),
        ),
      ),
      dividerColor: mochaPrimary.withValues(alpha: 0.16),
    );
  }

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      headlineMedium: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w400),
    );
  }
}
