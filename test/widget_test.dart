import 'package:clinic_solution/core/utils/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('locale changes without rebuilding the application services', () {
    final localeProvider = LocaleProvider();

    expect(localeProvider.locale.languageCode, 'en');

    localeProvider.setLocale(const Locale('hi'));
    expect(localeProvider.locale.languageCode, 'hi');

    localeProvider.setLocale(const Locale('gu'));
    expect(localeProvider.locale.languageCode, 'gu');
  });
}
