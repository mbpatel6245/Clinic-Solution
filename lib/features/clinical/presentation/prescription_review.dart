import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'clinical_components.dart';

/// A patient-facing summary of an in-memory snapshot. Private notes never enter
/// this widget. Review acknowledgements belong to this route and are not signed
/// record metadata. Firebase persistence remains with the existing editor.
class PrescriptionReview extends StatefulWidget {
  const PrescriptionReview({
    super.key,
    required this.record,
    required this.clinicName,
    this.signing = false,
    this.signed = false,
    this.busy = false,
    this.onConfirm,
    this.actions,
    this.notice,
  });
  final PrescriptionModel record;
  final String clinicName;
  final bool signing, signed, busy;
  final VoidCallback? onConfirm;
  final Widget? actions, notice;
  @override
  State<PrescriptionReview> createState() => _PrescriptionReviewState();
}

class _PrescriptionReviewState extends State<PrescriptionReview> {
  final _checked = <int>{};
  @override
  Widget build(BuildContext context) {
    final l = ClinicalLabels.of(context), s = AppLocalizations.of(context)!;
    final r = widget.record;
    Widget textSection(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body.trim().isEmpty ? l('noData') : body),
        ],
      ),
    );
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClinicalCard(
          title:
              r.clinicalPrintContext['name']?.toString() ?? widget.clinicName,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r.clinicalPrintContext['clinician_name']
                      ?.toString()
                      .isNotEmpty ==
                  true)
                Text(r.clinicalPrintContext['clinician_name'].toString()),
              if (r.visitDate != null)
                Text(
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(r.visitDate!),
                ),
              const Divider(height: 30),
              textSection(s.chiefComplaints, r.complaints),
              textSection(s.vitals, r.vitals),
              textSection(s.diagnosis, r.diagnoses.join(', ')),
              textSection(s.investigation, r.investigation),
              ClinicalAllergyBanner(allergies: r.patient.allergies),
              const SizedBox(height: 20),
              Text(
                s.medicines,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (r.medicines.where((m) => !m.isEmpty).isEmpty)
                Text(l('noData')),
              for (final m in r.medicines.where((m) => !m.isEmpty)) ...[
                Text(
                  m.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    m.dosage,
                    m.frequency,
                    m.duration,
                  ].where((v) => v.isNotEmpty).join(' · '),
                ),
                if (m.instructions.isNotEmpty) Text(m.instructions),
                const Divider(height: 24),
              ],
              const SizedBox(height: 12),
              textSection(s.advice, r.advice),
              textSection(
                s.followUpDate,
                r.followUpDate == null
                    ? ''
                    : DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).format(r.followUpDate!),
              ),
            ],
          ),
        ),
      ],
    );
    final review = ClinicalCard(
      title: l(
        widget.signing
            ? 'finalReview'
            : widget.signed
            ? 'signedRecord'
            : 'review',
      ),
      icon: '4_18896_imgCircleCheck.svg',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Chip(
            label: Text(
              widget.signed
                  ? '${l('signedRecord')} · ${r.clinicalVersion}'
                  : l('draft'),
            ),
          ),
          const SizedBox(height: 12),
          if (!widget.signed)
            for (var i = 0; i < (widget.signing ? 4 : 3); i++)
              CheckboxListTile(
                key: ValueKey('clinical-review-$i'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  l(['identity', 'medication', 'plan', 'signAck'][i]),
                ),
                value: _checked.contains(i),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _checked.add(i);
                  } else {
                    _checked.remove(i);
                  }
                }),
              ),
          const SizedBox(height: 12),
          Text(
            l(widget.signing || widget.signed ? 'signHint' : 'saveHint'),
            style: const TextStyle(color: UviloTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (widget.notice != null) widget.notice!,
          if (!widget.signed)
            FilledButton.icon(
              key: const ValueKey('clinical-review-confirm'),
              onPressed:
                  !widget.busy && _checked.length == (widget.signing ? 4 : 3)
                  ? widget.onConfirm ?? () => Navigator.pop(context, true)
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: Text(widget.signing ? l('sign') : s.savePrescription),
            ),
          if (!widget.signed)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
          if (widget.actions != null) widget.actions!,
        ],
      ),
    );
    return Theme(
      data: UviloTheme.light,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l(
              widget.signing
                  ? 'finalReview'
                  : widget.signed
                  ? 'signedRecord'
                  : 'review',
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClinicalPatientBanner(
                    patient: r.patient,
                    encounter: r.appointmentId,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= 1000
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: summary),
                              const SizedBox(width: 20),
                              SizedBox(width: 320, child: review),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              summary,
                              const SizedBox(height: 20),
                              review,
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
