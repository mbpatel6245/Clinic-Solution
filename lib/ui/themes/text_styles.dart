import 'package:flutter/material.dart';

import '../../core/utils/responsive_text_util.dart';
import '../../main.dart';

class AppTextStyles {
  static double getFontSize(Locale locale, double baseSize) {
    switch (locale.languageCode) {
      case 'gu': // Example for Arabic
        return baseSize * 1.1; // Slightly larger for readability
      case 'hi': // Example for Chinese
        return baseSize * 1.05; // Slightly smaller for compact scripts
      default:
        return baseSize;
    }
  }

  static TextStyle getRegularTextStyle(Locale locale, {double fontSize = 20}) {
    switch (locale.languageCode) {
      case 'hi':
        return TextStyle(
            fontSize: ResponsiveTextUtil.getResponsiveFontSize(
                navigatorKey.currentContext!,
                baseFontSize: getFontSize(locale, fontSize)),
            fontWeight: FontWeight.w400,
            fontFamily: "Noto Sans",
            color: Colors.black87);
      case 'gu':
        return TextStyle(
            fontSize: ResponsiveTextUtil.getResponsiveFontSize(
                navigatorKey.currentContext!,
                baseFontSize: getFontSize(locale, fontSize)),
            fontWeight: FontWeight.w400,
            fontFamily: '"Noto Sans"',
            color: Colors.black87);
      // Add more cases for other locales if needed
      default:
        return TextStyle(
            fontSize: ResponsiveTextUtil.getResponsiveFontSize(
                navigatorKey.currentContext!,
                baseFontSize: getFontSize(locale, fontSize)),
            fontWeight: FontWeight.w400,
            fontFamily: "Noto Sans",
            color: Colors.black87);
    }
  }

  static TextStyle getSemiBoldTextStyle(Locale locale, {double fontSize = 20}) {
    switch (locale.languageCode) {
      case 'hi':
        return TextStyle(
            fontSize: ResponsiveTextUtil.getResponsiveFontSize(
                navigatorKey.currentContext!,
                baseFontSize: getFontSize(locale, fontSize)),
            fontWeight: FontWeight.w600,
            fontFamily: "Noto Sans",
            color: Colors.black87);
      case 'gu':
        return TextStyle(
            fontSize: ResponsiveTextUtil.getResponsiveFontSize(
                navigatorKey.currentContext!,
                baseFontSize: getFontSize(locale, fontSize)),
            fontWeight: FontWeight.w600,
            fontFamily: '"Noto Sans"',
            color: Colors.black87);
      // Add more cases for other locales if needed
      default:
        return TextStyle(
            fontSize: ResponsiveTextUtil.getResponsiveFontSize(
                navigatorKey.currentContext!,
                baseFontSize: getFontSize(locale, fontSize)),
            fontWeight: FontWeight.w600,
            fontFamily: "Noto Sans",
            color: Colors.black87);
    }
  }

  static TextStyle getBoldTextStyle(Locale locale,{double fontSize = 20}) {
    switch (locale.languageCode) {
      case 'hi':
        return TextStyle(
            fontSize: ResponsiveTextUtil.getResponsiveFontSize(
                navigatorKey.currentContext!,
                baseFontSize: getFontSize(locale, fontSize)),
            fontWeight: FontWeight.w700,
            fontFamily: "Noto Sans",
            color: Colors.black87);
      case 'gu':
        return TextStyle(
            fontSize: ResponsiveTextUtil.getResponsiveFontSize(
                navigatorKey.currentContext!,
                baseFontSize: getFontSize(locale, fontSize)),
            fontWeight: FontWeight.w700,
            fontFamily: '"Noto Sans"',
            color: Colors.black87);
      // Add more cases for other locales if needed
      default:
        return TextStyle(
            fontSize: ResponsiveTextUtil.getResponsiveFontSize(
                navigatorKey.currentContext!,
                baseFontSize: getFontSize(locale, fontSize)),
            fontWeight: FontWeight.w700,
            fontFamily: "Noto Sans",
            color: Colors.black87);
    }
  }
}
