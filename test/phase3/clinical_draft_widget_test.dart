import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_draft_repository.dart';
import '../../tool/phase3_preview.dart';

class _Recovery implements ClinicalDraftRepository {
  Map<String, Object?>? saved;
  int revision = 0;
  @override
  Future<int> save(
    Map<String, Object?> payload,
    String password, {
    required int expectedRevision,
  }) async {
    saved = payload;
    return ++revision;
  }

  @override
  Future<RecoveredClinicalDraft?> restore(String password) async =>
      saved == null ? null : (revision: revision, payload: saved!);
  @override
  Future<void> remove(int expectedRevision) async {
    saved = null;
  }

  @override
  Future<void> close() async {}
}

Future<void> password(WidgetTester tester, String action) async {
  final button = find.text(action);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextField).last,
    'synthetic recovery passphrase',
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'consultation recovery restores private notes, medicines and stable ID after closing the editor',
    (tester) async {
      final repository = _Recovery();
      Widget editor() => Phase3Preview(
        key: UniqueKey(),
        screen: 'consultation',
        recoveryScope: 'synthetic-device-scope',
        draftRepositoryFactory: () => repository,
      );
      await tester.pumpWidget(editor());
      await tester.pumpAndSettle();
      final notes = find.widgetWithText(
        TextFormField,
        'Private clinical notes',
      );
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'PRIVATE SYNTHETIC RECOVERY NOTE');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await password(tester, 'Save encrypted draft');
      expect(repository.saved?['id'], 'synthetic-0');
      expect(
        (repository.saved?['fields'] as Map)['privateNotes'],
        'PRIVATE SYNTHETIC RECOVERY NOTE',
      );
      expect(
        (repository.saved?['medicines'] as List).single['name'],
        'Synthetic medicine — not for use',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(editor());
      await tester.pumpAndSettle();
      await password(tester, 'Restore encrypted draft');
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Private clinical notes'),
      );
      expect(find.text('PRIVATE SYNTHETIC RECOVERY NOTE'), findsOneWidget);
      expect(find.text('Synthetic medicine — not for use'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
