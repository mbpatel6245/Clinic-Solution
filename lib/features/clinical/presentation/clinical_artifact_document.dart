import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/enterprise_models.dart';
import '../../../data/datasources/patient_intake.dart';
import '../domain/clinical_artifact.dart';
import 'clinical_artifact_labels.dart';
import 'clinical_components.dart';

class ClinicalArtifactIcon extends StatelessWidget {
  const ClinicalArtifactIcon(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/figma/phase3/$name',
    width: name == '4_19096_imgDownload.svg' || name == '4_19096_imgShare2.svg'
        ? 16
        : 18,
    height: name == '4_19096_imgDownload.svg' || name == '4_19096_imgShare2.svg'
        ? 16
        : 18,
  );
}

String artifactCalendarDate(
  Object? value,
  String language, [
  String? timezone,
]) {
  if (value == null || value.toString().isEmpty) return '—';
  final date = DateTime.tryParse(value.toString());
  return date == null
      ? '—'
      : DateFormat.yMMMd(language).format(
          value.toString().length == 10
              ? date
              : timezone == null
              ? date.toLocal()
              : ClinicSchedule.local(
                  ClinicProfile(id: 'document', name: '', timezone: timezone),
                  date,
                ),
        );
}

String artifactRange(Map<String, dynamic> row) =>
    [row['lower'] ?? '—', row['upper'] ?? '—'].join(' – ');
bool artifactOutside(Map<String, dynamic> row) {
  final value = row['value'];
  return value is num &&
      ((row['lower'] is num && value < (row['lower'] as num)) ||
          (row['upper'] is num && value > (row['upper'] as num)));
}

/// Only the public record enters this widget. Draft inputs and private source
/// verification notes must never be rendered into a patient copy or PDF.
class ClinicalArtifactDocument extends StatelessWidget {
  const ClinicalArtifactDocument({super.key, required this.artifact});
  final ClinicalArtifact artifact;
  @override
  Widget build(BuildContext context) {
    final l = ArtifactLabels.of(context),
        c = ClinicalLabels.of(context),
        r = artifact.record;
    final clinic = Map<String, dynamic>.from(
      artifact.context['clinic'] as Map? ?? const {},
    );
    String calendar(Object? value) =>
        artifactCalendarDate(value, l.language, clinic['timezone']?.toString());
    Widget section(String label, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body.isEmpty ? c('noData') : body),
        ],
      ),
    );
    return ClinicalCard(
      title: artifact.title,
      icon: artifact.kind == ClinicalArtifactKind.carePlan
          ? '22_10739_imgShieldCheck.svg'
          : '4_19096_imgFileText.svg',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            clinic['name']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (clinic['address']?.toString().isNotEmpty == true)
            Text(clinic['address'].toString()),
          Text(artifact.context['practitioner_name']?.toString() ?? ''),
          Text(
            '${l('reference')}: ${artifact.id} · ${l('version')} ${artifact.version}',
          ),
          const Divider(height: 28),
          if (artifact.kind == ClinicalArtifactKind.labOrder) ...[
            section(
              l('tests'),
              (r['tests'] as List? ?? []).map((v) => '• $v').join('\n'),
            ),
            section(l('plannedDate'), calendar(r['planned_date'])),
            section(l('indication'), r['indication']?.toString() ?? ''),
            _ArtifactNotice(l('separateStatus')),
          ],
          if (artifact.kind == ClinicalArtifactKind.labResult) ...[
            section(l('source'), r['source_reference']?.toString() ?? ''),
            section(l('reportedDate'), calendar(r['reported_date'])),
            _ResultTable(
              rows: (r['observations'] as List? ?? [])
                  .map((v) => Map<String, dynamic>.from(v as Map))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _ArtifactNotice(l('rangeHint')),
            const SizedBox(height: 16),
            section(l('reviewNote'), r['review']?.toString() ?? ''),
          ],
          if (artifact.kind == ClinicalArtifactKind.carePlan) ...[
            section(
              l('instructions'),
              (r['instructions'] as List? ?? []).map((v) => '• $v').join('\n'),
            ),
            section(l('plannedReview'), calendar(r['follow_up_date'])),
            if (r['treatment_plan'] is Map) ...[
              section(
                l('sourcePlan'),
                r['treatment_plan']['name']?.toString() ?? '',
              ),
              for (final raw
                  in r['treatment_plan']['sittings'] as List? ?? const [])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${raw['name']} · ${calendar(raw['scheduled_at'])} · ${l(raw['completed'] == true ? 'recordedCompleted' : 'recordedPlanned')}',
                  ),
                ),
            ],
            const Divider(height: 28),
            Row(
              children: [
                const ClinicalArtifactIcon('22_10739_imgShieldCheck.svg'),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l('vaccines'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if ((r['vaccinations'] as List? ?? []).isEmpty)
              _ArtifactNotice(l('unknownHistory')),
            for (final raw in r['vaccinations'] as List? ?? const [])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      raw['vaccine'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${l('administered')}: ${calendar(raw['administered_at'])}',
                    ),
                    Text('${l('dose')}: ${raw['dose_number']}'),
                    if (raw['batch_number']?.toString().isNotEmpty == true)
                      Text('${l('batch')}: ${raw['batch_number']}'),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _ArtifactNotice(l('noNewVaccination')),
          ],
        ],
      ),
    );
  }
}

class _ArtifactNotice extends StatelessWidget {
  const _ArtifactNotice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: UviloTheme.soft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ClinicalArtifactIcon('4_19096_imgInfo.svg'),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: UviloTheme.muted, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    final l = ArtifactLabels.of(context);
    String value(Map<String, dynamic> r) => r['value'] == null
        ? r['text_result'].toString()
        : '${r['value']} ${r['unit']}';
    Widget flag(Map<String, dynamic> r) => artifactOutside(r)
        ? Text(
            l('outsideRange'),
            style: const TextStyle(color: Color(0xFF996016)),
          )
        : const SizedBox.shrink();
    Widget cell(String text, {bool bold = false}) => Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 720
          ? Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.3),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
              },
              border: const TableBorder(
                horizontalInside: BorderSide(color: UviloTheme.border),
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: UviloTheme.canvas),
                  children: [
                    cell(l('analyte'), bold: true),
                    cell(l('result'), bold: true),
                    cell(l('referenceRange'), bold: true),
                    const SizedBox.shrink(),
                  ],
                ),
                for (final row in rows)
                  TableRow(
                    children: [
                      cell(row['analyte'].toString()),
                      cell(value(row)),
                      cell(
                        row['lower'] == null && row['upper'] == null
                            ? '—'
                            : artifactRange(row),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: flag(row),
                      ),
                    ],
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: UviloTheme.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          row['analyte'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(value(row)),
                        if (row['lower'] != null || row['upper'] != null)
                          Text('${l('referenceRange')}: ${artifactRange(row)}'),
                        flag(row),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
