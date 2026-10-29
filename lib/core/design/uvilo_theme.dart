import 'package:flutter/material.dart';

/// Figma tokens: opt-in until a feature completes its visual migration.
abstract final class UviloTheme {
  static const primary = Color(0xFF007C83);
  static const ink = Color(0xFF1F3A3D);
  static const muted = Color(0xFF536D72);
  static const canvas = Color(0xFFF4FBFB);
  static const border = Color(0xFFB9DDE0);
  static const soft = Color(0xFFE5F3F4);
  static ThemeData get light {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      fontFamilyFallback: const [
        'Noto Sans',
        'Noto Sans Devanagari',
        'Noto Sans Gujarati',
      ],
      colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: ink,
        outline: border,
        secondaryContainer: soft,
      ),
      scaffoldBackgroundColor: canvas,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      dividerTheme: const DividerThemeData(color: border),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: soft,
      ),
    );
  }
}
