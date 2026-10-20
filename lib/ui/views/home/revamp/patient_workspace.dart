import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/auth/app_role.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import '../../../widgets/app_design.dart';
import '../enterprise/enterprise_screens.dart';
import '../new_prescription/tab_new_prescription.dart';
import 'clinical_workspaces.dart';
import 'prescription_preview.dart';

class PatientWorkspace extends StatefulWidget {
  const PatientWorkspace({
    super.key,
    required this.patient,
    this.embedded = false,
    this.onBack,
  });
  final PatientModel patient;
  final bool embedded;
  final VoidCallback? onBack;
  @override
  State<PatientWorkspace> createState() => _PatientWorkspaceState();
}

class _PatientWorkspaceState extends State<PatientWorkspace> {
  late final String _clinic = context.read<SessionController>().activeClinicId;
  late final Stream<List<PrescriptionModel>> _history = context
      .read<FirebaseFireStore>()
      .streamPrescriptions();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final l = RevampLabels.of(context);
    if (session.activeClinicId != _clinic ||
        !session.can(AppFeature.patients)) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.text('clinicChanged'))),
      );
    }
    return StreamBuilder<List<PrescriptionModel>>(
      stream: session.can(AppFeature.prescriptionList) ? _history : null,
      builder: (context, snapshot) => PatientWorkspaceView(
        embedded: widget.embedded,
        onBack: widget.onBack,
        patient: widget.patient,
        visits: session.can(AppFeature.prescriptionList)
            ? snapshot.data ?? []
            : [],
        historyLoading:
            session.can(AppFeature.prescriptionList) &&
            !snapshot.hasData &&
            !snapshot.hasError,
        historyError: snapshot.hasError,
        canReadHistory: session.can(AppFeature.prescriptionList),
        onPreview: (visit) => showPrescriptionPreview(context, visit),
        consultation: session.can(AppFeature.createPrescription)
            ? TabNewPrescription(initialPatient: widget.patient)
            : null,
        treatment: session.can(AppFeature.treatmentPlans)
            ? TreatmentPlansScreen(patient: widget.patient)
            : null,
        vaccinations: session.can(AppFeature.vaccination)
            ? VaccinationScreen(patient: widget.patient)
            : null,
      ),
    );
  }
}

/// Shared live and visual-review presentation. Records are matched by patient
/// identity only; a shared family phone/name must never merge clinical history.
class PatientWorkspaceView extends StatefulWidget {
  const PatientWorkspaceView({
    super.key,
    required this.patient,
    this.visits = const [],
    this.canReadHistory = true,
    this.historyLoading = false,
    this.historyError = false,
    this.consultation,
    this.treatment,
    this.vaccinations,
    this.onPreview,
    this.embedded = false,
    this.onBack,
  });
  final PatientModel patient;
  final List<PrescriptionModel> visits;
  final bool canReadHistory, historyLoading, historyError;
  final Widget? consultation, treatment, vaccinations;
  final ValueChanged<PrescriptionModel>? onPreview;
  final bool embedded;
  final VoidCallback? onBack;
  @override
  State<PatientWorkspaceView> createState() => _PatientWorkspaceViewState();
}

class _PatientWorkspaceViewState extends State<PatientWorkspaceView> {
  String _tab = 'analytics';
  final _visited = <String>{};
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final patient = widget.patient;
    final locale = Localizations.localeOf(context).toString();
    final visits =
        widget.visits
            .where((v) => patient.id.isNotEmpty && v.patient.id == patient.id)
            .toList()
          ..sort(
            (a, b) => (b.visitDate ?? b.createdAt ?? DateTime(1970)).compareTo(
              a.visitDate ?? a.createdAt ?? DateTime(1970),
            ),
          );
    final tabs = <String>[
      if (widget.canReadHistory) ...['analytics', 'timeline'],
      if (widget.consultation != null) 'consultationTab',
      if (widget.treatment != null) 'plans',
      if (widget.vaccinations != null) 'vaccines',
      if (!widget.canReadHistory &&
          widget.consultation == null &&
          widget.treatment == null &&
          widget.vaccinations == null)
        'details',
    ];
    final selected = tabs.contains(_tab) ? _tab : tabs.first;
    _visited.add(selected);
    final diagnoses = visits
        .expand((v) => v.diagnoses)
        .where((s) => s.trim().isNotEmpty)
        .toSet();
    Widget history({required bool analytics}) => AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.historyLoading)
            const LinearProgressIndicator()
          else if (widget.historyError)
            AppSection(child: Text(l.text('loadError')))
          else if (analytics) ...[
            ResponsiveGrid(
              minimumItemWidth: 200,
              children: [
                AppMetricCard(
                  label: l.text('consultations'),
                  value: '${visits.length}',
                  icon: Icons.medical_services_outlined,
                  caption: l.text('allTime'),
                ),
                AppMetricCard(
                  label: l.text('lastVisit'),
                  value: visits.isEmpty
                      ? '—'
                      : DateFormat.yMMMd(locale).format(
                          visits.first.visitDate ??
                              visits.first.createdAt ??
                              DateTime(1970),
                        ),
                  icon: Icons.history,
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppSection(
              title: l.text('diagnoses'),
              child: Text(
                diagnoses.isEmpty
                    ? l.text('noDiagnoses')
                    : diagnoses.join(' · '),
              ),
            ),
          ] else if (visits.isEmpty)
            AppSection(child: Text(l.text('noHistory')))
          else
            for (final visit in visits)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSection(
                  title: DateFormat.yMMMd(locale).format(
                    visit.visitDate ?? visit.createdAt ?? DateTime(1970),
                  ),
                  trailing: widget.onPreview == null
                      ? null
                      : IconButton(
                          tooltip: l.text('printPreview'),
                          icon: const Icon(Icons.print_outlined),
                          onPressed: () => widget.onPreview!(visit),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (visit.diagnoses.isNotEmpty)
                        Text(
                          visit.diagnoses.join(', '),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      if (visit.complaints.isNotEmpty) Text(visit.complaints),
                      if (visit.advice.isNotEmpty) Text(visit.advice),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(l.text('patientWorkspace'))),
      body: Column(
        children: [
          if (widget.embedded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l.text('patients')),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.soft,
                          foregroundColor: AppColors.primary,
                          child: Icon(Icons.person_outline),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.fullName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                [
                                  if (patient.gender.isNotEmpty)
                                    l.text(patient.gender),
                                  if (patient.age != null)
                                    '${patient.age} ${l.text(patient.ageUnit)}',
                                  if (patient.phone.isNotEmpty) patient.phone,
                                ].join(' · '),
                                style: const TextStyle(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(
                            Icons.notifications_outlined,
                            size: 16,
                          ),
                          label: Text(
                            l.text(
                              patient.notificationConsent == true
                                  ? 'consentGranted'
                                  : 'consentNotGranted',
                            ),
                          ),
                        ),
                        if (patient.allergies.isNotEmpty)
                          Chip(
                            avatar: const Icon(
                              Icons.warning_amber_outlined,
                              size: 16,
                            ),
                            label: Text(
                              '${l.text('allergies')}: ${patient.allergies.join(', ')}',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: WorkspaceTabs(
              labels: tabs.map(l.text).toList(),
              selected: tabs.indexOf(selected),
              onSelected: (index) => setState(() => _tab = tabs[index]),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: tabs.indexOf(selected),
              children: [
                for (final tab in tabs)
                  KeyedSubtree(
                    key: ValueKey(tab),
                    child: !_visited.contains(tab)
                        ? const SizedBox.shrink()
                        : switch (tab) {
                            'analytics' => history(analytics: true),
                            'timeline' => history(analytics: false),
                            'consultationTab' => widget.consultation!,
                            'plans' => widget.treatment!,
                            'vaccines' => widget.vaccinations!,
                            _ => AppPage(child: Text(patient.address)),
                          },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
