import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_artifact.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_draft_repository.dart';
import 'package:clinic_solution/features/clinical/data/encrypted_clinical_draft_repository.dart';
import 'package:clinic_solution/features/patients/data/registration_draft_store.dart';
import 'package:clinic_solution/features/clinical/presentation/clinical_artifact_document.dart';
import 'package:clinic_solution/features/clinical/presentation/clinical_artifact_editor.dart';
import 'package:clinic_solution/features/clinical/presentation/clinical_artifact_pdf.dart';
import 'package:clinic_solution/features/clinical/presentation/clinical_artifact_review.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import '../../tool/clinical_artifacts_preview.dart';

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
void main() {
  setUpAll(() async {
    for (final language in ['en', 'hi', 'gu']) {
      await initializeDateFormatting(language);
    }
  });
  test(
    'public sections preserve qualitative values and reference units without leaking source verification',
    () {
      final report = artifactFixture(
        ClinicalArtifactKind.labResult,
        issued: true,
      );
      final sections = ClinicalArtifactPdf.sections(report, 'en').toString();
      expect(sections, contains('Synthetic result'));
      expect(sections, contains('6.4 demo/L'));
      expect(sections, contains('Outside reported range'));
      expect(artifactOutside({'value': null, 'lower': 2, 'upper': 6}), isFalse);
      expect(artifactOutside({'value': 4, 'lower': 2, 'upper': 6}), isFalse);
      final care = artifactFixture(ClinicalArtifactKind.carePlan, issued: true);
      care.input['verification_note'] = 'PRIVATE SOURCE VERIFICATION';
      care.record['notes'] = 'PRIVATE PLAN NOTES';
      final text = ClinicalArtifactPdf.sections(care, 'gu').toString();
      expect(text, isNot(contains('PRIVATE')));
      expect(text, isNot(contains('synthetic-encounter')));
    },
  );
  test(
    'date-only report days are stable and timed source dates use the frozen clinic timezone',
    () {
      expect(
        artifactCalendarDate('2026-10-28', 'en', 'America/Los_Angeles'),
        'Oct 28, 2026',
      );
      expect(
        artifactCalendarDate(
          '2026-10-28T01:00:00Z',
          'en',
          'America/Los_Angeles',
        ),
        'Oct 27, 2026',
      );
      expect(
        () => ClinicalArtifactPdf.build(
          artifactFixture(ClinicalArtifactKind.labOrder),
          'en',
        ),
        throwsStateError,
      );
    },
  );
  test(
    'issued lab and care documents generate printable multilingual PDF bytes',
    () async {
      for (final kind in ClinicalArtifactKind.values) {
        for (final language in ['en', 'hi', 'gu']) {
          final bytes = await ClinicalArtifactPdf.build(
            artifactFixture(kind, issued: true),
            language,
          );
          expect(ascii.decode(bytes.take(4).toList()), '%PDF');
          expect(bytes.length, greaterThan(10000));
          if (const bool.fromEnvironment('ARTIFACT_SCREENSHOTS')) {
            final file = File(
              'build/phase3-artifact-review/${kind.name}-$language.pdf',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes);
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'artifact draft restarts preserve raw values, identity and private verification in encrypted SQLite',
    () async {
      final directory = await Directory.systemTemp.createTemp(
            'artifact-recovery-',
          ),
          file = File('${directory.path}/draft.sqlite');
      String scope(String kind) => ClinicalDraftIdentity(
        project: 'synthetic',
        user: 'doctor',
        clinic: 'clinic',
        patient: 'patient',
        encounter: 'artifact-$kind-new',
      ).scope;
      EncryptedClinicalDraftRepository open(String kind) =>
          EncryptedClinicalDraftRepository(
            scope(kind),
            RegistrationDraftStore(NativeDatabase(file)),
          );
      var repo = open('labResult');
      const payload = <String, Object?>{
        'v': 1,
        'id': 'stable-report',
        'revision': 3,
        'fields': {
          'verification': 'PRIVATE SOURCE VERIFICATION',
          'reported': '2026-10-28',
        },
        'rows': [
          {'value': '4.00', 'unit': 'demo/L', 'lower': '', 'upper': '7.20'},
        ],
      };
      try {
        await repo.save(
          payload,
          'synthetic recovery passphrase',
          expectedRevision: 0,
        );
        await repo.close();
        expect(
          String.fromCharCodes(await file.readAsBytes()),
          isNot(contains('PRIVATE SOURCE')),
        );
        repo = open('labResult');
        expect(
          (await repo.restore('synthetic recovery passphrase'))?.payload,
          payload,
        );
        await expectLater(
          repo.save(
            {'id': 'stale'},
            'synthetic recovery passphrase',
            expectedRevision: 0,
          ),
          throwsA(isA<DraftConflict>()),
        );
        await repo.close();
        final other = open('carePlan');
        expect(await other.restore('synthetic recovery passphrase'), isNull);
        await other.close();
        repo = open('labResult');
        await repo.remove(1);
        expect(await repo.restore('synthetic recovery passphrase'), isNull);
      } finally {
        await repo.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
  testWidgets(
    'issue needs four checks; release is a second explicit transaction',
    (tester) async {
      tester.view.physicalSize = const Size(1512, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = ArtifactPreviewRepository(
            artifactFixture(ClinicalArtifactKind.labOrder),
          ),
          access = ValueNotifier(true);
      await tester.pumpWidget(
        app(
          ClinicalArtifactReviewScreen(
            initial: repo.current,
            repository: repo,
            authorized: () => access.value,
            changes: access,
            sharingEnabled: () => true,
          ),
        ),
      );
      final issue = find.byKey(const ValueKey('artifact-issue'));
      expect(tester.widget<FilledButton>(issue).onPressed, isNull);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(ValueKey('artifact-review-$i')));
        await tester.pump();
      }
      await tester.tap(issue);
      await tester.pumpAndSettle();
      expect(repo.commands.map((v) => v['action']), ['issue']);
      expect(repo.current.releasedVersion, 0);
      final release = find.widgetWithText(
        FilledButton,
        'Release to linked patient account',
      );
      expect(release, findsOneWidget);
      expect(tester.widget<FilledButton>(release).onPressed, isNull);
      expect(find.text('Record actual collection'), findsOneWidget);
      await tester.tap(find.text('Record actual collection'));
      await tester.pumpAndSettle();
      expect(repo.commands.length, 1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          CheckboxListTile,
          'I verified the linked patient account and consent to release this reviewed version.',
        ),
      );
      await tester.pump();
      await tester.tap(release);
      await tester.pumpAndSettle();
      expect(repo.commands.map((v) => v['action']), ['issue', 'release']);
      expect(repo.current.releasedVersion, 1);
      access.value = false;
      await tester.pump();
      expect(find.text(repo.current.title), findsNothing);
      expect(repo.commands.length, 2);
      await tester.pumpWidget(const SizedBox());
      access.dispose();
    },
  );
  testWidgets(
    'lost issue acknowledgement shows uncertainty and reload does not repeat the issue',
    (tester) async {
      tester.view.physicalSize = const Size(1512, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = ArtifactPreviewRepository(
            artifactFixture(ClinicalArtifactKind.labOrder),
          )..loseAck = true,
          changes = ChangeNotifier();
      await tester.pumpWidget(
        app(
          ClinicalArtifactReviewScreen(
            initial: repo.current,
            repository: repo,
            authorized: () => true,
            changes: changes,
            sharingEnabled: () => true,
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(ValueKey('artifact-review-$i')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('artifact-issue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('artifact-issue')), findsOneWidget);
      expect(repo.commands.length, 1);
      await tester.tap(find.text('Reload server record'));
      await tester.pumpAndSettle();
      expect(find.text('Record actual collection'), findsOneWidget);
      expect(repo.commands.length, 1);
      await tester.pumpWidget(const SizedBox());
      changes.dispose();
    },
  );
  for (final locale in ['en', 'hi', 'gu']) {
    for (final width in [320.0, 768.0, 1512.0]) {
      for (final kind in ClinicalArtifactKind.values) {
        testWidgets('${kind.name} $locale $width handles 200 percent text', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1600),
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: ClinicalArtifactDocument(
                      artifact: artifactFixture(kind, issued: true),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'lab forms are empty for a new patient and reject missing input',
    (tester) async {
      tester.view.physicalSize = const Size(1512, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = ArtifactPreviewRepository(
            artifactFixture(ClinicalArtifactKind.labOrder),
          ),
          changes = ChangeNotifier();
      await tester.pumpWidget(
        app(
          ClinicalArtifactEditor(
            patient: artifactPatient,
            kind: ClinicalArtifactKind.labOrder,
            repository: repo,
            scope: 'synthetic-only',
            authorized: () => true,
            changes: changes,
            sharingEnabled: () => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic investigation A'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('artifact-save-review')));
      await tester.pumpAndSettle();
      expect(repo.commands, isEmpty);
      await tester.pumpWidget(const SizedBox());
      changes.dispose();
    },
  );
  testWidgets('capture synthetic lab and care designs', (tester) async {
    if (!const bool.fromEnvironment('ARTIFACT_SCREENSHOTS')) return;
    final fonts = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(fonts.load);
    await tester.runAsync(icons.load);
    for (final width in [390.0, 1512.0]) {
      for (final kind in ClinicalArtifactKind.values) {
        tester.view.physicalSize = Size(width, 1500);
        tester.view.devicePixelRatio = 1;
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ClinicalArtifactsPreview(kind: kind),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
                  await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(),
              bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = await Directory(
            'build/phase3-artifact-review',
          ).create(recursive: true);
          await File(
            '${directory.path}/${kind.name}-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    tester.view.reset();
  });
}
