import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/features/appointments/data/operational_repository.dart';
import 'package:clinic_solution/features/appointments/presentation/operational_schedule.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:clinic_solution/shared/presentation/guarded_dialog_content.dart';

class _Repository implements OperationalRepository {
  final calls = <Map<String, Object?>>[];
  @override
  Future<List<Practitioner>> practitioners() async => const [
    Practitioner('doctor', 'Synthetic Doctor'),
  ];
  @override
  Stream<List<AppointmentModel>> appointments({String? doctorId}) =>
      Stream.value(const []);
  @override
  Future<void> command(Map<String, Object?> input) async {
    calls.add(Map.of(input));
    if (calls.length == 1) {
      throw const OperationalFailure('unknown', unknown: true);
    }
  }

  @override
  String newOperationId() => 'stable-request';
}

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);
Widget _schedule(_Repository repository) => OperationalScheduleView(
  clinic: const ClinicProfile(id: 'demo', name: 'Synthetic Clinic'),
  repository: repository,
  patients: Stream.value(const [
    PatientModel(id: 'patient', firstName: 'Synthetic Patient'),
  ]),
);
void main() {
  testWidgets(
    'removing a selected patient disables new booking without breaking the form',
    (tester) async {
      tester.view.physicalSize = const Size(1512, 1244);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final patients = StreamController<List<PatientModel>>();
      addTearDown(patients.close);
      final repository = _Repository();
      await tester.pumpWidget(
        _app(
          OperationalScheduleView(
            clinic: const ClinicProfile(id: 'demo', name: 'Synthetic Clinic'),
            repository: repository,
            patients: patients.stream,
          ),
        ),
      );
      patients.add(const [
        PatientModel(id: 'patient', firstName: 'Synthetic Patient'),
      ]);
      await tester.pumpAndSettle();
      final picker = find.byKey(const ValueKey('operational-patient'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic Patient · patient').last);
      await tester.pumpAndSettle();
      patients.add(const []);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('operational-confirm')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.calls, isEmpty);
    },
  );
  for (final width in [320.0, 768.0, 1512.0]) {
    testWidgets('calendar adapts at $width and 200% text', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(_schedule(_Repository()), scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'uncertain confirmation freezes details and retries the same command',
    (tester) async {
      tester.view.physicalSize = const Size(1512, 1244);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      await tester.pumpWidget(_app(_schedule(repository)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('operational-patient')),
      );
      await tester.tap(find.byKey(const ValueKey('operational-patient')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic Patient · patient').last);
      await tester.pumpAndSettle();
      final confirm = find.byKey(const ValueKey('operational-confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.calls.length, 1);
      expect(find.text('Retry same request'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('operational-patient')),
            )
            .onChanged,
        isNull,
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.calls.length, 2);
      expect(repository.calls[1], repository.calls[0]);
      expect(find.text('Appointment confirmed by the server.'), findsOneWidget);
    },
  );
  testWidgets(
    'a dialog hides private contents when its captured scope changes',
    (tester) async {
      final authorized = ValueNotifier(true);
      addTearDown(authorized.dispose);
      await tester.pumpWidget(
        _app(
          GuardedDialogContent(
            changes: authorized,
            isAuthorized: () => authorized.value,
            message: 'Workspace changed',
            child: const Text('SYNTHETIC PRIVATE CONTENT'),
          ),
        ),
      );
      expect(find.text('SYNTHETIC PRIVATE CONTENT'), findsOneWidget);
      authorized.value = false;
      await tester.pumpAndSettle();
      expect(find.text('SYNTHETIC PRIVATE CONTENT'), findsNothing);
      expect(find.text('Workspace changed'), findsOneWidget);
    },
  );
}
