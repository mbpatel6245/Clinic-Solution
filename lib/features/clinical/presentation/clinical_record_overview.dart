import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/revamp_labels.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'clinical_components.dart';

class ClinicalRecordOverview extends StatelessWidget {
  const ClinicalRecordOverview({
    super.key,
    required this.patient,
    required this.visits,
    this.onPreview,
  });
  final PatientModel patient;

  /// Already filtered by immutable patient identity and sorted newest first.
  final List<PrescriptionModel> visits;
  final ValueChanged<PrescriptionModel>? onPreview;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!,
        l = RevampLabels.of(context),
        c = ClinicalLabels.of(context);
    final latest = visits.firstOrNull;
    String date(DateTime? value) => value == null
        ? c('noData')
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(value);
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClinicalCard(
          title: s.vitals,
          icon: '4_18715_imgClipboardList.svg',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                latest?.vitals.trim().isNotEmpty == true
                    ? latest!.vitals
                    : c('noData'),
              ),
              const SizedBox(height: 8),
              Text(
                '${l.text('lastVisit')}: ${date(latest?.visitDate ?? latest?.createdAt)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ClinicalCard(
          title: l.text('diagnoses'),
          child: Text(
            visits
                    .expand((v) => v.diagnoses)
                    .where((v) => v.trim().isNotEmpty)
                    .toSet()
                    .join(' · ')
                    .isEmpty
                ? l.text('noDiagnoses')
                : visits
                      .expand((v) => v.diagnoses)
                      .where((v) => v.trim().isNotEmpty)
                      .toSet()
                      .join(' · '),
          ),
        ),
        const SizedBox(height: 16),
        ClinicalCard(
          title: s.medicines,
          icon: '4_18715_imgPill.svg',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (latest == null ||
                  latest.medicines.where((m) => !m.isEmpty).isEmpty)
                Text(c('noData')),
              if (latest != null)
                for (final m in latest.medicines.where((m) => !m.isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [
                            m.dosage,
                            m.frequency,
                            m.duration,
                            m.instructions,
                          ].where((v) => v.isNotEmpty).join(' · '),
                        ),
                      ],
                    ),
                  ),
              if (latest != null)
                Text(date(latest.visitDate ?? latest.createdAt)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ClinicalCard(
          title: l.text('consultations'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${visits.length} · ${l.text('allTime')}'),
              if (visits.isEmpty) Text(l.text('noHistory')),
              for (final visit in visits.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(date(visit.visitDate ?? visit.createdAt)),
                  subtitle: Text(visit.diagnoses.join(', ')),
                  trailing: onPreview == null
                      ? null
                      : IconButton(
                          tooltip: l.text('printPreview'),
                          icon: const Icon(Icons.print_outlined),
                          onPressed: () => onPreview!(visit),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClinicalAllergyBanner(allergies: patient.allergies),
        const SizedBox(height: 16),
        ClinicalCard(
          title: s.followUpDate,
          child: Text(date(latest?.followUpDate)),
        ),
        const SizedBox(height: 16),
        ClinicalCard(
          title: s.patientDetails,
          child: Text(
            [
                  patient.phone,
                  patient.email ?? '',
                  patient.address,
                ].where((s) => s.isNotEmpty).join('\n').isEmpty
                ? c('noData')
                : [
                    patient.phone,
                    patient.email ?? '',
                    patient.address,
                  ].where((s) => s.isNotEmpty).join('\n'),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 1000
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: main),
                const SizedBox(width: 20),
                SizedBox(width: 300, child: side),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [side, const SizedBox(height: 16), main],
            ),
    );
  }
}
