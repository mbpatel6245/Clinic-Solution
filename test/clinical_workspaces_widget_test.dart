import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clinic_solution/core/design/app_theme.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:clinic_solution/services/auth_services.dart';
import 'package:clinic_solution/services/firestore_services.dart';
import 'package:clinic_solution/services/session_controller.dart';
import 'package:clinic_solution/ui/views/home/new_prescription/tab_new_prescription.dart';
import 'package:clinic_solution/ui/views/home/revamp/clinical_workspaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _UnusedDatabase implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoAuthentication implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session extends SessionController {
  _Session() : super(auth: _NoAuthentication(), firestore: _UnusedDatabase());
}

class _Clinic extends FirebaseFireStore {
  _Clinic()
    : super(
        firestore: _UnusedDatabase(),
        authService: AuthService(auth: _NoAuthentication()),
      );
  PrescriptionModel? saved;
  String? privateNotes;
  bool? completed;
  @override
  String createPrescriptionId() => 'memory-rx';
  @override
  Future<String> savePrescription(
    PrescriptionModel value, {
    String? privateNotes,
    bool completeQueueVisit = false,
  }) async {
    saved = value;
    this.privateNotes = privateNotes;
    completed = completeQueueVisit;
    return value.id;
  }
}

Widget _app(Widget child, {_Clinic? clinic}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<FirebaseFireStore>.value(value: clinic ?? _Clinic()),
    ChangeNotifierProvider<SessionController>(create: (_) => _Session()),
  ],
  child: MaterialApp(
    theme: AppTheme.forLocale(const Locale('en')),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets(
    'saving a queued consultation preserves demographics and separates private notes',
    (tester) async {
      final clinic = _Clinic();
      final patient = PatientModel(
        id: 'patient',
        firstName: 'Demo',
        age: 6,
        ageUnit: 'months',
        dateOfBirth: DateTime(2026, 4, 1),
        email: 'demo@example.invalid',
        notificationConsent: true,
        locale: 'gu',
        allergies: const ['Example allergy'],
        abhaId: 'demo-reference',
      );
      await tester.pumpWidget(
        _app(
          TabNewPrescription(
            initialPatient: patient,
            queueAppointmentId: 'queue-entry',
          ),
          clinic: clinic,
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Diagnosis'),
        'Example documentation',
      );
      final note = find.widgetWithText(TextFormField, 'Private clinical notes');
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Private clinician context');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final save = find.text('Save prescription');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(clinic.saved?.patient.ageUnit, 'months');
      expect(clinic.saved?.patient.dateOfBirth, patient.dateOfBirth);
      expect(clinic.saved?.patient.notificationConsent, isTrue);
      expect(clinic.saved?.patient.allergies, patient.allergies);
      expect(clinic.saved?.patient.abhaId, 'demo-reference');
      expect(clinic.saved?.appointmentId, 'queue-entry');
      expect(clinic.completed, isTrue);
      expect(clinic.privateNotes, 'Private clinician context');
      expect(
        clinic.saved?.toMap('patient').keys,
        isNot(contains('private_notes')),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'template naming validates, returns a name and closes without controller errors',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const TemplateNamePrompt(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('This field is required'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), ' General protocol ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, 'General protocol');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'data failures stay visible instead of rendering an empty successful list',
    (tester) async {
      await tester.pumpWidget(
        _app(
          WorkflowList<String>(
            title: 'Records',
            hint: 'Clinic records',
            empty: 'No records',
            stream: Stream.error(StateError('denied')),
            itemBuilder: (s) => Text(s),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No records'), findsNothing);
      expect(
        find.text(
          'Some practice data could not be loaded. Check your connection and access.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );
}
