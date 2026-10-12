import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/core/design/app_theme.dart';
import 'package:clinic_solution/core/design/clinic_brand.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('shared footer wraps and persists across routes at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forLocale(const Locale('gu')),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: BrandedAppFrame(child: child!),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const ClinicLogo()),
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const Scaffold(body: Text('Appointments')),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text(ClinicBrand.copyright), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text(ClinicBrand.copyright), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
