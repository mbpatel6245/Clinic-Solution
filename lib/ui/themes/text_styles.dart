import 'package:flutter/material.dart';

class AppTextStyles {
  static double getFontSize(Locale locale, double baseSize) {
    switch (locale.languageCode) {
      case 'gu': // Example for Arabic
        return baseSize * 1.1; // Slightly larger for readability
      case 'hi': // Example for Chinese
        return baseSize * 0.9; // Slightly smaller for compact scripts
      default:
        return baseSize;
    }
  }

  static TextStyle getRegularTextStyle(Locale locale) {
    switch (locale.languageCode) {
      case 'hi':
        return TextStyle(
            fontSize: getFontSize(locale, 20),
            fontWeight: FontWeight.w400,
            fontFamily: "Noto Sans",
            color: Colors.black87);
      case 'gu':
        return TextStyle(
            fontSize: getFontSize(locale, 20),
            fontWeight: FontWeight.w400,
            fontFamily: '"Noto Sans"',
            color: Colors.black87);
      // Add more cases for other locales if needed
      default:
        return TextStyle(
            fontSize: getFontSize(locale, 20),
            fontWeight: FontWeight.w400,
            fontFamily: "Noto Sans",
            color: Colors.black87);
    }
  }

  static TextStyle getSemiBoldTextStyle(Locale locale) {
    switch (locale.languageCode) {
      case 'hi':
        return TextStyle(
            fontSize: getFontSize(locale, 20),
            fontWeight: FontWeight.w600,
            fontFamily: "Noto Sans",
            color: Colors.black87);
      case 'gu':
        return TextStyle(
            fontSize: getFontSize(locale, 20),
            fontWeight: FontWeight.w600,
            fontFamily: '"Noto Sans"',
            color: Colors.black87);
      // Add more cases for other locales if needed
      default:
        return TextStyle(
            fontSize: getFontSize(locale, 20),
            fontWeight: FontWeight.w600,
            fontFamily: "Noto Sans",
            color: Colors.black87);
    }
  }

  static TextStyle getBoldTextStyle(Locale locale) {
    switch (locale.languageCode) {
      case 'hi':
        return TextStyle(
            fontSize: getFontSize(locale, 20),
            fontWeight: FontWeight.w700,
            fontFamily: "Noto Sans",
            color: Colors.black87);
      case 'gu':
        return TextStyle(
            fontSize: getFontSize(locale, 20),
            fontWeight: FontWeight.w700,
            fontFamily: '"Noto Sans"',
            color: Colors.black87);
      // Add more cases for other locales if needed
      default:
        return TextStyle(
            fontSize: getFontSize(locale, 20),
            fontWeight: FontWeight.w700,
            fontFamily: "Noto Sans",
            color: Colors.black87);
    }
  }
}
