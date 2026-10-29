import '../../../../features/patients/presentation/patient_directory_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../core/auth/app_role.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import 'patient_workspace.dart';
import 'patient_entry_dialog.dart';
import '../../../../data/datasources/patient_intake.dart';

Future<PatientEntryResult?> showPatientRegistration(
  BuildContext context, {
  PatientEntryMode mode = PatientEntryMode.registration,
}) => showPatientEntry(context, mode: mode);

class PatientRegistry extends StatefulWidget {
  const PatientRegistry({
    super.key,
    required this.onEntryResult,
    this.onOpenPatient,
  });
  final ValueChanged<PatientEntryResult> onEntryResult;
  final ValueChanged<PatientModel>? onOpenPatient;
  @override
  State<PatientRegistry> createState() => _PatientRegistryState();
}

class _PatientRegistryState extends State<PatientRegistry> {
  late Stream<List<PatientModel>> _patients;
  Stream<List<AppointmentModel>>? _appointments;
  String? _clinic;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final clinic =
        '${session.activeClinicId}:${session.can(AppFeature.appointments)}:${session.can(AppFeature.reception)}';
    if (_clinic == clinic) return;
    _clinic = clinic;
    _patients = context.read<FirebaseFireStore>().streamPatients();
    _appointments =
        (session.can(AppFeature.appointments) ||
            session.can(AppFeature.reception))
        ? context.read<FirebaseFireStore>().streamAppointments()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PatientModel>>(
      key: ValueKey(_clinic),
      stream: _patients,
      builder: (context, snapshot) => StreamBuilder<List<AppointmentModel>>(
        stream: _appointments,
        builder: (context, appointments) => PatientDirectoryView(
          patients: snapshot.data ?? const [],
          appointments: appointments.data ?? const [],
          loading: !snapshot.hasData && !snapshot.hasError,
          hasError: snapshot.hasError || appointments.hasError,
          onRetry: () => setState(() {
            _patients = context.read<FirebaseFireStore>().streamPatients();
          }),
          onOpen: (patient) => _showPatient(context, patient),
          onRegister: () => _addPatient(context),
        ),
      ),
    );
  }

  Future<void> _addPatient(BuildContext context) async {
    final result = await showPatientRegistration(context);
    if (result != null && mounted) widget.onEntryResult(result);
  }

  Future<void> _showPatient(BuildContext context, PatientModel patient) async {
    if (widget.onOpenPatient != null) {
      widget.onOpenPatient!(patient);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PatientWorkspace(patient: patient)),
    );
  }
}

/// Compact rows on mobile and a scannable directory table on desktop.
class PatientDirectoryList extends StatelessWidget {
  const PatientDirectoryList({
    super.key,
    required this.patients,
    required this.onOpen,
    this.visits,
  });
  final List<PatientModel> patients;
  final List<PrescriptionModel>? visits;
  final ValueChanged<PatientModel> onOpen;
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final s = AppLocalizations.of(context)!;
    String age(PatientModel p) => [
      if (p.age != null) '${p.age} ${l.text(p.ageUnit)}',
      if (p.gender.isNotEmpty) l.text(p.gender),
    ].join(' · ');
    List<PrescriptionModel> history(PatientModel p) =>
        (visits ?? [])
            .where((v) => p.id.isNotEmpty && v.patient.id == p.id)
            .toList()
          ..sort(
            (a, b) => (b.visitDate ?? b.createdAt ?? DateTime(1970)).compareTo(
              a.visitDate ?? a.createdAt ?? DateTime(1970),
            ),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              for (final patient in patients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.soft,
                        foregroundColor: AppColors.primary,
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(patient.fullName),
                      subtitle: Text(
                        [
                          age(patient),
                          if (patient.phone.isNotEmpty) patient.phone,
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => onOpen(patient),
                    ),
                  ),
                ),
            ],
          );
        }
        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                horizontalMargin: 16,
                columnSpacing: 24,
                headingTextStyle: const TextStyle(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
                columns: [
                  DataColumn(label: Text(l.text('patients'))),
                  DataColumn(label: Text(s.age)),
                  DataColumn(label: Text(s.phone)),
                  if (visits != null) ...[
                    DataColumn(label: Text(l.text('lastVisit'))),
                    DataColumn(
                      label: Text(l.text('consultations')),
                      numeric: true,
                    ),
                  ],
                ],
                rows: [
                  for (final patient in patients)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            patient.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => onOpen(patient),
                        ),
                        DataCell(
                          Text(age(patient)),
                          onTap: () => onOpen(patient),
                        ),
                        DataCell(
                          Text(patient.phone.isEmpty ? '—' : patient.phone),
                        ),
                        if (visits != null) ...[
                          DataCell(
                            Text(
                              history(patient).isEmpty
                                  ? '—'
                                  : DateFormat.yMMMd(
                                      Localizations.localeOf(
                                        context,
                                      ).toString(),
                                    ).format(
                                      history(patient).first.visitDate ??
                                          history(patient).first.createdAt ??
                                          DateTime(1970),
                                    ),
                            ),
                          ),
                          DataCell(Text(history(patient).length.toString())),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
