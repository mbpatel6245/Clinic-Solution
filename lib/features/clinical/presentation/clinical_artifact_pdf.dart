import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../data/datasources/enterprise_models.dart';
import '../../../data/datasources/prescription_print_settings.dart';
import '../../../data/datasources/patient_intake.dart';
import '../../../services/prescription_document.dart';
import '../domain/clinical_artifact.dart';
import 'clinical_artifact_document.dart';
import 'clinical_artifact_labels.dart';
import 'clinical_components.dart';

abstract final class ClinicalArtifactPdf {
  static List<(String, String)> sections(
    ClinicalArtifact artifact,
    String language,
  ) {
    final l = ArtifactLabels(language), r = artifact.record;
    String calendar(Object? value) => artifactCalendarDate(
      value,
      language,
      (artifact.context['clinic'] as Map?)?['timezone']?.toString(),
    );
    return [
      (l('reference'), artifact.id),
      (l('version'), '${artifact.version}'),
      if (artifact.kind == ClinicalArtifactKind.labOrder) ...[
        (l('tests'), (r['tests'] as List).map((v) => '• $v').join('\n')),
        (l('plannedDate'), calendar(r['planned_date'])),
        if (r['indication']?.toString().isNotEmpty == true)
          (l('indication'), r['indication'].toString()),
        ('', l('separateStatus')),
      ],
      if (artifact.kind == ClinicalArtifactKind.labResult) ...[
        (l('source'), r['source_reference'].toString()),
        (l('reportedDate'), calendar(r['reported_date'])),
        for (final row in r['observations'] as List)
          (
            row['analyte'].toString(),
            [
              row['value'] == null
                  ? row['text_result'].toString()
                  : '${row['value']} ${row['unit']}',
              if (row['lower'] != null || row['upper'] != null)
                '${l('referenceRange')}: ${artifactRange(Map<String, dynamic>.from(row as Map))}',
              if (artifactOutside(Map<String, dynamic>.from(row as Map)))
                l('outsideRange'),
            ].join('\n'),
          ),
        ('', l('rangeHint')),
        (l('reviewNote'), r['review'].toString()),
      ],
      if (artifact.kind == ClinicalArtifactKind.carePlan) ...[
        (
          l('instructions'),
          (r['instructions'] as List).map((v) => '• $v').join('\n'),
        ),
        if (r['follow_up_date'] != null)
          (l('plannedReview'), calendar(r['follow_up_date'])),
        if (r['treatment_plan'] is Map)
          (
            l('sourcePlan'),
            [
              r['treatment_plan']['name'].toString(),
              for (final row in r['treatment_plan']['sittings'] as List)
                '${row['name']} · ${calendar(row['scheduled_at'])} · ${l(row['completed'] == true ? 'recordedCompleted' : 'recordedPlanned')}',
            ].join('\n'),
          ),
        if ((r['vaccinations'] as List).isEmpty)
          (l('vaccines'), l('unknownHistory')),
        for (final row in r['vaccinations'] as List)
          (
            l('vaccines'),
            [
              row['vaccine'].toString(),
              '${l('administered')}: ${calendar(row['administered_at'])}',
              '${l('dose')}: ${row['dose_number']}',
              if (row['batch_number']?.toString().isNotEmpty == true)
                '${l('batch')}: ${row['batch_number']}',
            ].join('\n'),
          ),
        ('', l('noNewVaccination')),
      ],
    ];
  }

  static Future<Uint8List> build(ClinicalArtifact source, String language) {
    if (!source.issued || source.version < 1) {
      throw StateError('Only an issued reviewed document can be printed');
    }
    final artifact = source.asPublished(),
        patient = artifact.patient,
        clinic = ClinicProfile.fromMap(
          Map<String, dynamic>.from(artifact.context['clinic'] as Map),
          'document-clinic',
        );
    final date = artifact.issuedAt == null
        ? null
        : ClinicSchedule.local(clinic, artifact.issuedAt!);
    return PrescriptionDocument.build(
      record: PrescriptionModel(
        patient: PatientModel(
          id: patient.id,
          firstName: patient.firstName,
          middleName: patient.middleName,
          lastName: patient.lastName,
          age: patient.age,
          ageUnit: patient.ageUnit,
          gender: patient.gender,
        ),
        visitDate: date,
      ),
      clinic: clinic,
      settings: PrescriptionPrintSettings(
        clinicianName: artifact.context['practitioner_name']?.toString() ?? '',
        registration: artifact.context['registration']?.toString() ?? '',
        qualifications: artifact.context['qualifications']?.toString() ?? '',
        showPhone: false,
      ),
      language: language,
      documentTitle: ArtifactLabels(language)(artifact.kind.name),
      documentSections: sections(artifact, language),
    );
  }
}

class ClinicalArtifactPrintScreen extends StatefulWidget {
  const ClinicalArtifactPrintScreen({
    super.key,
    required this.artifact,
    required this.authorized,
    required this.changes,
  });
  final ClinicalArtifact artifact;
  final bool Function() authorized;
  final Listenable changes;
  @override
  State<ClinicalArtifactPrintScreen> createState() =>
      _ClinicalArtifactPrintScreenState();
}

class _ClinicalArtifactPrintScreenState
    extends State<ClinicalArtifactPrintScreen> {
  String? _language;
  Future<Uint8List>? _bytes;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_language == null) {
      _language = Localizations.localeOf(context).languageCode;
      _build();
    }
  }

  void _build() =>
      _bytes = ClinicalArtifactPdf.build(widget.artifact, _language!);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.changes,
    builder: (context, _) {
      final l = ClinicalLabels.of(context);
      if (!widget.authorized()) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(l('remoteError'))),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(l('print'))),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButton<String>(
                value: _language,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                  DropdownMenuItem(value: 'gu', child: Text('ગુજરાતી')),
                ],
                onChanged: (value) => setState(() {
                  _language = value!;
                  _build();
                }),
              ),
            ),
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: _bytes,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(_build),
                        child: Text(l('reload')),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return PdfPreview(
                    key: ValueKey((_language, snapshot.data)),
                    build: (_) => Future.value(snapshot.data!),
                    initialPageFormat: PdfPageFormat.a4,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    pdfFileName:
                        '${widget.artifact.kind.name}-${widget.artifact.id}-v${widget.artifact.version}.pdf',
                    maxPageWidth: 800,
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
