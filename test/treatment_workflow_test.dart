import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/core/design/app_theme.dart';
import 'package:clinic_solution/data/datasources/workflow_models.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:clinic_solution/ui/views/home/revamp/treatment_plan_card.dart';
import 'package:clinic_solution/ui/views/home/revamp/prescription_preview.dart';
import 'package:clinic_solution/data/datasources/prescription_print_settings.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';

Widget app(Widget child) => MaterialApp(
  theme: AppTheme.forLocale(const Locale('en')),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
void main() {
  testWidgets(
    'language change removes the previous printable document until new bytes are ready',
    (tester) async {
      final english = Completer<Uint8List>(), gujarati = Completer<Uint8List>();
      await tester.pumpWidget(
        app(
          PrescriptionPreviewView(
            record: const PrescriptionModel(
              patient: PatientModel(firstName: 'Demo'),
            ),
            clinic: const ClinicProfile(id: 'demo', name: 'Demo Clinic'),
            documentBuilder: (language) =>
                language == 'en' ? english.future : gujarati.future,
            previewBuilder: (key, bytes) =>
                _CachedDocument(key: key, bytes: bytes),
          ),
        ),
      );
      english.complete(Uint8List.fromList([1]));
      await tester.pumpAndSettle();
      expect(find.text('Document 1'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ગુજરાતી').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Document 1'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gujarati.complete(Uint8List.fromList([2]));
      await tester.pumpAndSettle();
      expect(find.text('Document 2'), findsOneWidget);
      expect(find.text('Document 1'), findsNothing);
    },
  );
  test(
    'legacy plans stay active and lifecycle status survives progress changes',
    () {
      final legacy = TreatmentPlan.fromMap({
        'patient_id': 'demo',
        'name': 'Plan',
        'sittings': [],
      }, 'plan');
      expect(legacy.status, TreatmentPlanStatus.active);
      final closed = TreatmentPlan.fromMap({
        ...legacy.toMap(),
        'status': 'completed',
      }, 'plan');
      expect(closed.withSittings([]).status, TreatmentPlanStatus.completed);
      final log = TreatmentSittingLog.fromMap({
        'sitting_index': 2,
        'work_done': 'Demo work',
        'notes': 'Private demo notes',
        'performed_at': DateTime(2026, 10, 19),
        'author_id': 'doctor',
      }, '2');
      expect(log.sittingIndex, 2);
      expect(log.notes, 'Private demo notes');
      expect(log.performedAt, DateTime(2026, 10, 19));
    },
  );
  testWidgets(
    'failed log save retains clinical text and can be retried without duplicate submission',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TreatmentSittingLogForm(
                  sitting: TreatmentSitting(
                    name: 'Demo sitting',
                    scheduledAt: DateTime(2026, 10, 19),
                  ),
                  onSave: (work, notes, date) async {
                    calls++;
                    expect(work, 'Synthetic work only');
                    expect(notes, 'Synthetic private note');
                    if (calls == 1) throw StateError('offline');
                    await pending.future;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Synthetic work only',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Synthetic private note',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Synthetic work only'), findsOneWidget);
      expect(find.text('Could not save. Please try again.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(calls, 2);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TreatmentSittingLogForm), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'letterhead dialog validates and returns selected configuration',
    (tester) async {
      PrescriptionPrintSettings? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<PrescriptionPrintSettings>(
                  context: context,
                  builder: (_) => const PrescriptionLetterheadForm(
                    settings: PrescriptionPrintSettings(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Demo clinician',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result?.clinicianName, 'Demo clinician');
      expect(result?.layout, PrescriptionLayout.classic);
      expect(tester.takeException(), isNull);
    },
  );
}

// Simulates a PDF plugin that caches the first supplied file in native state.
class _CachedDocument extends StatefulWidget {
  const _CachedDocument({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<_CachedDocument> createState() => _CachedDocumentState();
}

class _CachedDocumentState extends State<_CachedDocument> {
  late final int _first = widget.bytes.first;
  @override
  Widget build(BuildContext context) => Text('Document $_first');
}
