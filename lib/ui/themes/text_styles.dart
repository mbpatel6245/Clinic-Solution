import 'package:flutter/material.dart';
import '../../core/design/app_typography.dart';

class AppTextStyles {
  static double getFontSize(Locale locale, double baseSize) => baseSize;
  static TextStyle getRegularTextStyle(Locale locale, {double fontSize = 20}) =>
      AppTypography.style(locale, fontSize: fontSize);
  static TextStyle getSemiBoldTextStyle(
    Locale locale, {
    double fontSize = 20,
  }) =>
      AppTypography.style(locale, fontSize: fontSize, weight: FontWeight.w600);
  static TextStyle getBoldTextStyle(Locale locale, {double fontSize = 20}) =>
      AppTypography.style(locale, fontSize: fontSize, weight: FontWeight.w700);
}
