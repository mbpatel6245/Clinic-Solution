import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/features/patients/presentation/patient_directory_view.dart';
import 'package:clinic_solution/features/patients/presentation/administrative_patient_profile.dart';
import 'package:clinic_solution/features/patients/presentation/registration_review.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';

void main() {
  const patient = PatientModel(
    id: 'patient-001',
    firstName: 'Synthetic',
    lastName: 'Patient',
    phone: '+919000000123',
    allergies: ['NEVER SHOW IN STAFF PROFILE'],
  );
  Widget app(Widget child, {String language = 'en', double scale = 1}) =>
      MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      );
  for (final width in [320.0, 768.0, 1512.0]) {
    for (final language in ['en', 'hi', 'gu']) {
      testWidgets(
        'directory and administrative profile fit $width $language at large text',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            app(
              PatientDirectoryView(
                patients: const [patient],
                onOpen: (_) {},
                onRegister: () {},
              ),
              language: language,
              scale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            app(
              const AdministrativePatientProfileView(patient: patient),
              language: language,
              scale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('NEVER SHOW IN STAFF PROFILE'), findsNothing);
        },
      );
    }
  }
  testWidgets(
    'review never enables save before independent consent and duplicate review',
    (tester) async {
      await tester.pumpWidget(
        app(
          RegistrationReview(
            patient: patient,
            patients: Stream.value(const [
              PatientModel(
                id: 'another-id',
                firstName: 'Other',
                phone: '+919000000123',
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.textContaining('shared phone'), findsOneWidget);
    },
  );
}
