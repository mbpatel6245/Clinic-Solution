import 'package:flutter/material.dart';
import 'package:clinic_solution/core/design/uvilo_theme.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_artifact.dart';
import 'package:clinic_solution/features/clinical/presentation/clinical_artifact_document.dart';
import 'package:clinic_solution/features/clinical/presentation/clinical_artifact_editor.dart';
import 'package:clinic_solution/features/clinical/presentation/clinical_artifact_review.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';

// Synthetic standalone renderer; never initialized against Firebase.
final artifactPatient = PatientModel(
  id: 'synthetic-patient',
  userId: 'synthetic-login',
  firstName: 'Synthetic',
  lastName: 'Patient',
  age: 35,
  gender: 'female',
);
const artifactContext = <String, dynamic>{
  'clinic': {
    'name': 'SYNTHETIC DEMO · not for clinical use',
    'address': 'Preview clinic',
    'timezone': 'Asia/Kolkata',
  },
  'practitioner_name': 'Synthetic Practitioner',
};
ClinicalArtifact artifactFixture(
  ClinicalArtifactKind kind, {
  bool issued = false,
  int revision = 1,
  int released = 0,
}) {
  final record = <String, dynamic>{
    'title': switch (kind) {
      ClinicalArtifactKind.labOrder => 'Synthetic investigation requisition',
      ClinicalArtifactKind.labResult => 'Synthetic reviewed report',
      ClinicalArtifactKind.carePlan => 'Synthetic care-plan copy',
    },
    ...switch (kind) {
      ClinicalArtifactKind.labOrder => {
        'tests': ['Synthetic investigation A', 'Synthetic investigation B'],
        'planned_date': '2026-10-30',
        'indication': 'Synthetic indication for layout verification',
      },
      ClinicalArtifactKind.labResult => {
        'reported_date': '2026-10-28',
        'source_reference': 'SYNTHETIC-REPORT',
        'observations': [
          {
            'key': 'a',
            'analyte': 'Synthetic analyte',
            'value': 6.4,
            'unit': 'demo/L',
            'lower': 2.0,
            'upper': 6.0,
          },
          {
            'key': 'b',
            'analyte': 'Synthetic qualitative investigation',
            'value': null,
            'text_result': 'Synthetic result',
            'unit': '',
            'lower': null,
            'upper': null,
          },
        ],
        'review':
            'Synthetic clinician review. Verify units and source before issue.',
      },
      ClinicalArtifactKind.carePlan => {
        'instructions': [
          'Synthetic existing signed advice for layout verification.',
          'Synthetic follow-up instruction.',
        ],
        'follow_up_date': '2026-11-04T00:00:00.000Z',
        'treatment_plan': null,
        'vaccinations': [],
        'source_encounter_version': 1,
      },
    },
  };
  return ClinicalArtifact(
    id: 'synthetic-${kind.name}',
    kind: kind,
    patient: artifactPatient,
    state: issued ? 'issued' : 'draft',
    revision: revision,
    version: issued ? 1 : 0,
    releasedVersion: released,
    record: record,
    input: kind == ClinicalArtifactKind.carePlan
        ? {
            'title': record['title'],
            'instruction_indices': [0],
            'vaccination_ids': <String>[],
            'source_plan_id': '',
            'verification_note': '',
          }
        : record,
    context: artifactContext,
    encounterId: kind == ClinicalArtifactKind.carePlan
        ? 'synthetic-encounter'
        : '',
    orderStatus: kind == ClinicalArtifactKind.labOrder && issued
        ? 'ordered'
        : '',
    issuedAt: issued ? DateTime.utc(2026, 10, 29) : null,
  );
}

class ArtifactPreviewRepository implements ClinicalArtifactRepository {
  ArtifactPreviewRepository(this.current);
  ClinicalArtifact current;
  final commands = <Map<String, Object?>>[];
  bool loseAck = false;
  int sequence = 0;
  @override
  String newId() => 'synthetic-${sequence++}';
  @override
  void close() {}
  @override
  Stream<List<ClinicalArtifact>> watch({String? patientId}) =>
      Stream.value([current]);
  @override
  Future<ClinicalArtifact> load(String id) async => current;
  @override
  Future<List<Map<String, dynamic>>> history(String id) async => [];
  @override
  Future<List<ClinicalArtifact>> versions(String id) async =>
      current.issued ? [current] : [];
  @override
  Future<ClinicalArtifactSources> sources(
    String patientId,
  ) async => const ClinicalArtifactSources(
    encounters: [
      {
        'id': 'synthetic-encounter',
        'state': 'signed',
        'record': {
          'advice':
              'Synthetic existing signed advice for layout verification.\nSynthetic follow-up instruction.',
        },
      },
    ],
  );
  @override
  Future<void> command(Map<String, Object?> input) async {
    commands.add(Map.of(input));
    if (input['action'] == 'saveDraft') {
      final record = Map<String, dynamic>.from(input['record'] as Map);
      current = ClinicalArtifact(
        id: input['artifactId'] as String,
        kind: ClinicalArtifactKind.values.byName(
          input['artifactKind'] as String,
        ),
        patient: artifactPatient,
        state: 'draft',
        revision: current.revision + 1,
        version: 0,
        record: record,
        input: record,
        context: artifactContext,
      );
    } else if (input['action'] == 'issue') {
      current = artifactFixture(
        current.kind,
        issued: true,
        revision: current.revision + 1,
      );
    } else if (input['action'] == 'release') {
      current = artifactFixture(
        current.kind,
        issued: true,
        revision: current.revision + 1,
        released: 1,
      );
    }
    if (loseAck) {
      throw const ClinicalArtifactFailure('unknown', uncertain: true);
    }
  }
}

void main() => runApp(const ClinicalArtifactsPreview());

class ClinicalArtifactsPreview extends StatefulWidget {
  const ClinicalArtifactsPreview({
    super.key,
    this.kind = ClinicalArtifactKind.labResult,
    this.editor = false,
    this.issued = false,
    this.locale = const Locale('en'),
  });
  final ClinicalArtifactKind kind;
  final bool editor, issued;
  final Locale locale;
  @override
  State<ClinicalArtifactsPreview> createState() =>
      _ClinicalArtifactsPreviewState();
}

class _ClinicalArtifactsPreviewState extends State<ClinicalArtifactsPreview> {
  late final repository = ArtifactPreviewRepository(
    artifactFixture(widget.kind, issued: widget.issued),
  );
  final changes = ChangeNotifier();
  @override
  void dispose() {
    changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: UviloTheme.light,
    locale: widget.locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: widget.editor
        ? ClinicalArtifactEditor(
            patient: artifactPatient,
            kind: widget.kind,
            repository: repository,
            scope: 'synthetic-preview-only',
            authorized: () => mounted,
            changes: changes,
            sharingEnabled: () => true,
            initial: repository.current,
          )
        : widget.issued
        ? Scaffold(
            appBar: AppBar(
              title: const Text('SYNTHETIC DEMO · not for clinical use'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ClinicalArtifactDocument(artifact: repository.current),
            ),
          )
        : ClinicalArtifactReviewScreen(
            initial: repository.current,
            repository: repository,
            authorized: () => mounted,
            changes: changes,
            sharingEnabled: () => true,
          ),
  );
}
