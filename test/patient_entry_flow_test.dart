import 'dart:async';
import 'package:clinic_solution/core/design/app_theme.dart';
import 'package:clinic_solution/core/design/revamp_labels.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/data/datasources/patient_intake.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_entry_dialog.dart';
import 'package:clinic_solution/ui/views/home/revamp/appointment_booking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {String language = 'en', double scale = 1}) =>
    MaterialApp(
      theme: AppTheme.forLocale(Locale(language)),
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

void main() {
  testWidgets('small-screen intake stays usable while the keyboard is open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      app(
        PatientEntryDialog(
          patients: () => Stream.value([]),
          newPatientId: () => 'new',
          newAppointmentId: () => 'visit',
          onSubmit: (_) async => throw StateError('unused'),
        ),
        scale: 1.5,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  final patient = PatientModel(
    id: 'existing-one',
    firstName: 'Existing Demo',
    phone: '+919876543210',
    gender: 'other',
  );
  Widget entry(
    Future<PatientEntryResult> Function(PatientEntrySubmission) submit, {
    PatientEntryMode mode = PatientEntryMode.registration,
    DateTime? slot,
    Stream<List<PatientModel>>? patients,
  }) => PatientEntryDialog(
    mode: mode,
    slot: slot,
    patients: () => patients ?? Stream.value([patient]),
    newPatientId: () => 'new-profile',
    newAppointmentId: () => 'new-visit',
    onSubmit: submit,
  );
  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Patient name *'),
      'New Demo',
    );
    final gender = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(gender);
    await tester.tap(gender);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'new patient save returns an identified record; queue uses the same registration payload',
    (tester) async {
      for (final action in [
        PatientEntryAction.openRecord,
        PatientEntryAction.queue,
      ]) {
        PatientEntrySubmission? submitted;
        await tester.pumpWidget(
          app(
            entry((value) async {
              submitted = value;
              throw const PatientEntryException('saveError');
            }),
          ),
        );
        await fill(tester);
        final button = find.text(
          action == PatientEntryAction.queue
              ? 'Save & add to queue'
              : 'Save patient',
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(submitted?.isNew, isTrue);
        expect(submitted?.patient.id, 'new-profile');
        expect(submitted?.patient.fullName, 'New Demo');
        expect(submitted?.action, action);
        expect(submitted?.patient.notificationConsent, isFalse);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets(
    'existing patient search opens or queues the original ID without a new profile',
    (tester) async {
      PatientEntrySubmission? submitted;
      await tester.pumpWidget(
        app(
          entry((value) async {
            submitted = value;
            throw const PatientEntryException('saveError');
          }),
        ),
      );
      await tester.tap(find.text('Existing patient'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '987654');
      await tester.pumpAndSettle();
      expect(find.text('Existing Demo'), findsOneWidget);
      await tester.tap(find.text('Add to queue'));
      await tester.pumpAndSettle();
      expect(submitted?.patient.id, 'existing-one');
      expect(submitted?.isNew, isFalse);
      await tester.tap(find.text('Open record'));
      await tester.pumpAndSettle();
      expect(submitted?.action, PatientEntryAction.openRecord);
    },
  );
  testWidgets(
    'failed save keeps data and stable IDs; busy buttons reject duplicate submissions',
    (tester) async {
      final pending = Completer<PatientEntryResult>();
      final entries = <PatientEntrySubmission>[];
      await tester.pumpWidget(
        app(
          entry((value) {
            entries.add(value);
            return entries.length == 1
                ? pending.future
                : Future.error(const PatientEntryException('saveError'));
          }),
        ),
      );
      await fill(tester);
      await tester.tap(find.text('Save patient'));
      await tester.pump();
      await tester.tap(find.text('Save patient'));
      expect(entries, hasLength(1));
      pending.completeError(const PatientEntryException('saveError'));
      await tester.pumpAndSettle();
      expect(find.text('New Demo'), findsOneWidget);
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();
      expect(entries, hasLength(2));
      expect(entries[0].patient.id, entries[1].patient.id);
      expect(entries[0].appointmentId, entries[1].appointmentId);
    },
  );
  testWidgets(
    'slot booking defaults to existing patient and preserves exact selected instant',
    (tester) async {
      final slot = DateTime.utc(2030, 1, 7, 4);
      PatientEntrySubmission? submitted;
      await tester.pumpWidget(
        app(
          entry(
            (value) async {
              submitted = value;
              throw const PatientEntryException('slotUnavailable');
            },
            mode: PatientEntryMode.booking,
            slot: slot,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Existing');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Book'));
      await tester.pumpAndSettle();
      expect(submitted?.patient.id, patient.id);
      expect(submitted?.scheduledAt, slot);
      expect(submitted?.action, PatientEntryAction.booked);
      expect(submitted?.sendConfirmation, isFalse);
      expect(
        find.text(RevampLabels('en').text('slotUnavailable')),
        findsOneWidget,
      );
    },
  );
  testWidgets('search failures do not appear as no matches', (tester) async {
    await tester.pumpWidget(
      app(
        entry(
          (_) async => throw StateError('unused'),
          mode: PatientEntryMode.booking,
          patients: Stream.error(StateError('denied')),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Demo');
    await tester.pumpAndSettle();
    expect(find.text(RevampLabels('en').text('loadError')), findsOneWidget);
    expect(
      find.text(RevampLabels('en').text('noPatientMatches')),
      findsNothing,
    );
  });
  test(
    'clinic slots handle timezone, occupied times, closed days and past slots',
    () {
      const clinic = ClinicProfile(
        id: 'demo',
        name: 'Demo',
        openingTime: '09:00',
        closingTime: '10:00',
        workingDays: {1},
      );
      final now = DateTime.utc(2030, 1, 6);
      final slots = ClinicSchedule.slots(
        clinic,
        DateTime(2030, 1, 7),
        now: now,
      );
      expect(slots.first, DateTime.utc(2030, 1, 7, 3, 30));
      expect(appointmentSlotLabel(clinic, slots.first, 'en'), contains('9:00'));
      expect(slots, hasLength(4));
      expect(
        ClinicSchedule.slots(clinic, DateTime(2030, 1, 8), now: now),
        isEmpty,
      );
      final available = ClinicSchedule.slots(
        clinic,
        DateTime(2030, 1, 7),
        now: slots.first,
        appointments: [
          AppointmentModel(
            patientName: 'Demo',
            phone: '',
            scheduledAt: slots[1],
          ),
        ],
      );
      expect(available, slots.skip(2).toList());
    },
  );
  testWidgets(
    'slot confirm opens patient step and completed booking offers navigation',
    (tester) async {
      DateTime? chosen;
      PatientModel? opened;
      const clinic = ClinicProfile(
        id: 'demo',
        name: 'Demo',
        openingTime: '09:00',
        closingTime: '09:30',
      );
      await tester.pumpWidget(
        app(
          AppointmentBookingView(
            clinic: clinic,
            appointments: const [],
            now: DateTime.utc(2030, 1, 7),
            onOpenPatient: (p) => opened = p,
            onChooseSlot: (slot) async {
              chosen = slot;
              return PatientEntryResult(
                patient,
                PatientEntryAction.booked,
                appointment: AppointmentModel(
                  id: 'booked',
                  patientName: patient.fullName,
                  phone: patient.phone,
                  scheduledAt: slot,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final slotButton = find.textContaining('9:00');
      await tester.ensureVisible(slotButton);
      await tester.tap(slotButton);
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(chosen, DateTime.utc(2030, 1, 7, 3, 30));
      expect(find.text('Appointment booked'), findsOneWidget);
      await tester.tap(find.text('Open patient record'));
      expect(opened?.id, patient.id);
    },
  );
  for (final language in ['en', 'hi', 'gu']) {
    for (final width in [320.0, 768.0, 1440.0]) {
      testWidgets('$language intake and booking at $width with large text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            entry((_) async => throw StateError('unused')),
            language: language,
            scale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          app(
            AppointmentBookingView(
              clinic: const ClinicProfile(id: 'demo', name: 'Demo'),
              appointments: const [],
              now: DateTime.utc(2030, 1, 7),
              onChooseSlot: (_) async => null,
            ),
            language: language,
            scale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
