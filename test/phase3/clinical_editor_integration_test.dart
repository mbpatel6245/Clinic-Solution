import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_repository.dart';
import '../../tool/phase3_preview.dart';

class _ClinicalServer implements ClinicalRepository {
  final commands = <Map<String, Object?>>[];
  ClinicalEncounter? current;
  @override
  void close() {}
  @override
  String newOperationId() => 'operation-${commands.length}';
  @override
  Future<ClinicalEncounter> load(String id) async => current!;
  @override
  Future<void> command(Map<String, Object?> input) async {
    commands.add(Map.of(input));
    if (input['kind'] == 'saveDraft') {
      final public = Map<String, dynamic>.from(input['record'] as Map);
      current = ClinicalEncounter(
        id: input['encounterId'] as String,
        revision: 1,
        version: 0,
        releasedVersion: 0,
        state: 'draft',
        record: PrescriptionModel.fromMap({
          ...public,
          'patient_id': phase3Patient.id,
          'patient': {
            'first_name': phase3Patient.firstName,
            'last_name': phase3Patient.lastName,
            'user_id': phase3Patient.userId,
          },
        }, input['encounterId'] as String),
        privateNotes: input['privateNotes'] as String? ?? '',
      );
    } else if (input['kind'] == 'sign') {
      final previous = current!;
      current = ClinicalEncounter(
        id: previous.id,
        revision: 2,
        version: 1,
        releasedVersion: 0,
        state: 'signed',
        record: previous.record,
        privateNotes: previous.privateNotes,
      );
    }
  }
}

void main() {
  testWidgets(
    'migrated editor saves a scoped draft, signs only after review and starts a fresh consultation on Done',
    (tester) async {
      final server = _ClinicalServer();
      await tester.pumpWidget(
        Phase3Preview(screen: 'consultation', clinicalRepository: server),
      );
      await tester.pumpAndSettle();
      final note = find.widgetWithText(TextFormField, 'Private clinical notes');
      await tester.ensureVisible(note);
      await tester.enterText(note, 'PRIVATE EDITOR NOTE');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final review = find.widgetWithText(
        FilledButton,
        'Review, sign and complete visit',
      );
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(server.commands.single['kind'], 'saveDraft');
      expect(server.commands.single['patientId'], phase3Patient.id);
      expect(server.commands.single['expectedRevision'], 0);
      expect(
        (server.commands.single['record'] as Map).containsKey('privateNotes'),
        false,
      );
      expect(server.commands.single['privateNotes'], 'PRIVATE EDITOR NOTE');
      expect(find.text('PRIVATE EDITOR NOTE'), findsNothing);
      for (var i = 0; i < 4; i++) {
        final check = find.byKey(ValueKey('clinical-review-$i'));
        await tester.ensureVisible(check);
        await tester.tap(check);
        await tester.pumpAndSettle();
      }
      final sign = find.byKey(const ValueKey('clinical-review-confirm'));
      await tester.ensureVisible(sign);
      await tester.tap(sign);
      await tester.pumpAndSettle();
      expect(server.commands.last['kind'], 'sign');
      expect(server.commands.last['expectedRevision'], 1);
      expect(server.commands.where((c) => c['kind'] == 'release'), isEmpty);
      final done = find.text('Done');
      await tester.ensureVisible(done);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(find.text('Consultation workspace'), findsOneWidget);
      expect(find.text('PRIVATE EDITOR NOTE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
