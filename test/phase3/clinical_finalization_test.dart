import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_repository.dart';
import 'package:clinic_solution/features/clinical/presentation/clinical_finalization_screen.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';

ClinicalEncounter encounter({
  int revision = 1,
  int version = 0,
  int released = 0,
  bool signed = false,
}) => ClinicalEncounter(
  id: 'synthetic',
  revision: revision,
  version: version,
  releasedVersion: released,
  state: signed ? 'signed' : 'draft',
  privateNotes: 'PRIVATE SYNTHETIC NOTE',
  record: PrescriptionModel(
    id: 'synthetic',
    patient: PatientModel(
      id: 'patient',
      firstName: 'Synthetic Patient',
      userId: 'patient-login',
    ),
    diagnoses: const ['Synthetic assessment'],
    visitDate: DateTime(2026, 10, 28),
    clinicalVersion: version,
  ),
);

class _Repository implements ClinicalRepository {
  ClinicalEncounter current = encounter();
  final commands = <Map<String, Object?>>[];
  bool loseSignAck = false;
  @override
  Future<ClinicalEncounter> load(String id) async => current;
  @override
  String newOperationId() => 'op-${commands.length}';
  @override
  void close() {}
  @override
  Future<void> command(Map<String, Object?> input) async {
    commands.add(Map.of(input));
    switch (input['kind']) {
      case 'sign':
        current = encounter(
          revision: current.revision + 1,
          version: current.version + 1,
          signed: true,
        );
        if (loseSignAck) {
          throw const ClinicalFailure('unknown', uncertain: true);
        }
      case 'release':
        current = encounter(
          revision: current.revision + 1,
          version: current.version,
          signed: true,
          released: 1,
        );
      case 'amend':
        current = encounter(
          revision: current.revision + 1,
          version: current.version,
        );
      case 'revoke':
        current = encounter(
          revision: current.revision + 1,
          version: current.version,
          signed: true,
        );
    }
  }
}

Widget _app(
  _Repository repository,
  ValueNotifier<bool> access, {
  ValueChanged<ClinicalEncounter>? onAmended,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: ClinicalFinalizationScreen(
    initial: repository.current,
    repository: repository,
    clinicName: 'Synthetic clinic',
    authorized: () => access.value,
    changes: access,
    sharingEnabled: () => true,
    onAmended: onAmended,
  ),
);
Future<void> acknowledge(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    final check = find.byKey(ValueKey('clinical-review-$i'));
    await tester.ensureVisible(check);
    await tester.tap(check);
    await tester.pumpAndSettle();
  }
  final confirm = find.byKey(const ValueKey('clinical-review-confirm'));
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'signing, release and amendment are separate explicit actions; private notes stay out of the summary',
    (tester) async {
      final repository = _Repository(), access = ValueNotifier(true);
      ClinicalEncounter? amended;
      await tester.pumpWidget(
        _app(repository, access, onAmended: (e) => amended = e),
      );
      expect(find.text('PRIVATE SYNTHETIC NOTE'), findsNothing);
      await acknowledge(tester);
      expect(repository.commands.single['kind'], 'sign');
      expect(repository.commands.single['finalAcknowledgement'], true);
      expect(find.text('Signed prescription'), findsNWidgets(2));
      final release = find.widgetWithText(
        FilledButton,
        'Release to linked patient account',
      );
      expect(tester.widget<FilledButton>(release).onPressed, isNull);
      final consent = find.byType(CheckboxListTile);
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(release);
      await tester.tap(release);
      await tester.pumpAndSettle();
      expect(repository.commands.last['kind'], 'release');
      expect(repository.commands.last['recipientId'], 'patient-login');
      final revoke = find.widgetWithText(TextButton, 'Revoke patient access');
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Synthetic withdrawal reason',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Revoke patient access'),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(repository.commands.last['kind'], 'revoke');
      expect(repository.commands.last['revokeAcknowledgement'], true);
      final reason = find.byType(TextField);
      await tester.ensureVisible(reason);
      await tester.enterText(reason, 'Synthetic correction reason');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final amend = find.text('Start an audited amendment');
      await tester.ensureVisible(amend);
      await tester.tap(amend);
      await tester.pumpAndSettle();
      expect(amended?.state, 'draft');
      expect(amended?.version, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'lost signing acknowledgement stays unconfirmed until a fresh server read without automatic replay',
    (tester) async {
      final repository = _Repository()..loseSignAck = true;
      await tester.pumpWidget(_app(repository, ValueNotifier(true)));
      await acknowledge(tester);
      expect(find.text('Signed prescription'), findsNothing);
      final reload = find.text('Reload server record');
      await tester.ensureVisible(reload);
      await tester.tap(reload);
      await tester.pumpAndSettle();
      expect(find.text('Signed prescription'), findsNWidgets(2));
      expect(repository.commands.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'revoking access removes the clinical summary and blocks actions',
    (tester) async {
      final repository = _Repository(), access = ValueNotifier(true);
      await tester.pumpWidget(_app(repository, access));
      access.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Patient'), findsNothing);
      expect(
        find.byKey(const ValueKey('clinical-review-confirm')),
        findsNothing,
      );
      expect(repository.commands, isEmpty);
    },
  );
}
