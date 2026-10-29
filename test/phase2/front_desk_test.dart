import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/features/front_desk/presentation/front_desk_overview.dart';
import 'package:clinic_solution/features/front_desk/presentation/front_desk_queue.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';

Widget _app(Widget child, {String language = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    );
final _now = DateTime(2026, 10, 28);
const _clinic = ClinicProfile(id: 'synthetic', name: 'Synthetic Clinic');
final _items = [
  AppointmentModel(
    id: 'one',
    patientId: 'patient-a',
    patientName: 'Synthetic Patient',
    phone: '+919000000001',
    scheduledAt: DateTime(2026, 10, 28, 9),
    practitionerName: 'Synthetic Doctor',
  ),
];
void main() {
  for (final language in ['en', 'hi', 'gu']) {
    for (final width in [320.0, 768.0, 1512.0]) {
      testWidgets('front desk and queue fit $width $language at 200% text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            FrontDeskOverview(
              appointments: _items,
              invoices: const [],
              available: const {
                AppFeature.appointments,
                AppFeature.patients,
                AppFeature.billing,
                AppFeature.reception,
              },
              onOpen: (_) {},
              clinic: _clinic,
              now: _now,
            ),
            language: language,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          _app(
            FrontDeskQueue(
              items: _items,
              onAction: (_, _) async {},
              clinic: _clinic,
              now: _now,
            ),
            language: language,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'arrival requires three independent acknowledgements and sends selected ID once',
    (tester) async {
      tester.view.physicalSize = const Size(1512, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      await tester.pumpWidget(
        _app(
          FrontDeskQueue(
            items: _items,
            onAction: (_, _) async => fail('Unreviewed action'),
            onReviewedArrival: (a) async {
              expect(a.id, 'one');
              calls++;
            },
            clinic: _clinic,
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('desk-confirm-arrival'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      for (var index = 0; index < 3; index++) {
        final checkbox = find.byType(CheckboxListTile).at(index);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Patient'), findsNothing);
    },
  );
}
