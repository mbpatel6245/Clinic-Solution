import 'package:flutter/material.dart';

/// Keep the complete line box, including Indic vowel marks and descenders.
abstract final class AppTypography {
  static const fallback = ['Noto Sans Devanagari', 'Noto Sans Gujarati'];
  static String family(Locale locale) => switch (locale.languageCode) {
    'hi' => 'Noto Sans Devanagari',
    'gu' => 'Noto Sans Gujarati',
    _ => 'Noto Sans',
  };
  static TextStyle style(
    Locale locale, {
    double fontSize = 16,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: family(locale),
    fontFamilyFallback: fallback,
    fontSize: fontSize,
    fontWeight: weight,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    color: Colors.black87,
  );
}
