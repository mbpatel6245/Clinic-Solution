import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:clinic_solution/core/design/uvilo_theme.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/data/datasources/patient_intake.dart';
import 'package:clinic_solution/features/appointments/data/operational_repository.dart';
import 'package:clinic_solution/features/appointments/presentation/operational_schedule.dart';
import 'package:clinic_solution/features/patients/presentation/patient_directory_view.dart';
import 'package:clinic_solution/features/patients/presentation/administrative_patient_profile.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:clinic_solution/shared/presentation/adaptive_workspace.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_entry_dialog.dart';
import 'package:clinic_solution/features/front_desk/presentation/front_desk_overview.dart';
import 'package:clinic_solution/features/front_desk/presentation/front_desk_queue.dart';
import 'package:clinic_solution/core/auth/app_role.dart';

void main() => runApp(const Phase2Preview());

/// Deliberately has no Firebase initialization or production network access.
class Phase2Preview extends StatefulWidget {
  const Phase2Preview({super.key, this.initialDestination = 'patients'});
  final String initialDestination;
  @override
  State<Phase2Preview> createState() => _Phase2PreviewState();
}

class _Phase2PreviewState extends State<Phase2Preview> {
  late String _selected = widget.initialDestination;
  PatientModel? _patient;
  final _patients = [
    for (final entry in [
      ('2048', 'Rajesh', 'Kumar', 48, 'male'),
      ('2083', 'Priya', 'Sharma', 36, 'female'),
      ('2034', 'Kavita', 'Rao', 54, 'female'),
      ('2056', 'Arjun', 'Nair', 29, 'male'),
      ('2072', 'Meera', 'Iyer', 62, 'female'),
      ('2091', 'Vikram', 'Singh', 42, 'male'),
      ('2104', 'Suresh', 'Patel', 57, 'male'),
      ('2118', 'Neha', 'Desai', 31, 'female'),
    ])
      PatientModel(
        id: 'MDF-${entry.$1}',
        firstName: entry.$2,
        lastName: entry.$3,
        age: entry.$4,
        gender: entry.$5,
        phone: '+91 90000 0${entry.$1}',
        address: 'Synthetic address for visual review',
        createdAt: DateTime(2026, 10, 1),
      ),
  ];
  int _id = 0;
  late final _appointments = [
    for (var i = 0; i < _patients.length; i++)
      AppointmentModel(
        id: 'synthetic-visit-$i',
        patientId: _patients[i].id,
        patientName: _patients[i].fullName,
        phone: _patients[i].phone,
        scheduledAt: DateTime(2026, 10, 28, 9 + i),
        status: i < 4
            ? 'completed'
            : i < 6
            ? 'confirmed'
            : 'booked',
        practitionerId: 'synthetic-doctor',
        practitionerName: 'Dr. Ananya Mehta',
        arrivalAt: i < 6 ? DateTime(2026, 10, 28, 8 + i, 50) : null,
      ),
  ];
  late final OperationalRepository repository = _PreviewOperations();
  Future<void> _register(BuildContext context) async {
    final result = await showDialog<PatientEntryResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PatientEntryDialog(
        reviewNewPatients: true,
        canQueue: false,
        patients: () => Stream.value(_patients),
        newPatientId: () => 'synthetic-${++_id}',
        newAppointmentId: () => 'synthetic-visit-${++_id}',
        onSubmit: (entry) async =>
            PatientEntryResult(entry.patient, entry.action),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _patients.add(result.patient);
        _patient = result.patient;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: UviloTheme.light,
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => AdaptiveWorkspace(
        figmaNavigation: true,
        workspaceLabel: 'Staff workspace · synthetic preview',
        clinicLabel: 'Aarogya Clinic',
        title:
            'Workspace  ›  ${_selected == 'patients'
                ? 'Patients'
                : _selected == 'dashboard'
                ? 'Front desk'
                : _selected == 'reception'
                ? 'Check-in and queue'
                : 'Appointments'}',
        selectedId: _selected,
        footer: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('PN')),
          title: Text('Priya Nair'),
          subtitle: Text('Synthetic clinic staff'),
        ),
        destinations: const [
          WorkspaceDestination(
            id: 'dashboard',
            label: 'Front desk',
            icon: Icons.dashboard_outlined,
          ),
          WorkspaceDestination(
            id: 'patients',
            label: 'Patients',
            icon: Icons.people_outline,
          ),
          WorkspaceDestination(
            id: 'appointments',
            label: 'Appointments',
            icon: Icons.calendar_month_outlined,
          ),
          WorkspaceDestination(
            id: 'reception',
            label: 'Check-in and queue',
            icon: Icons.list_alt_outlined,
          ),
        ],
        navigationIconBuilder: (id) => SizedBox(
          width: 18,
          height: 18,
          child: SvgPicture.asset(
            'assets/figma/phase2/n${_selected == 'patients'
                ? '4_18003'
                : _selected == 'reception'
                ? '12_4553'
                : _selected == 'dashboard'
                ? '4_17763'
                : '4_18438'}_${id == 'patients'
                ? 'imgUsers'
                : id == 'dashboard'
                ? 'imgLayoutDashboard'
                : id == 'reception'
                ? 'imgListOrdered'
                : 'imgCalendarDays'}.svg',
          ),
        ),
        onSelect: (id) => setState(() {
          _selected = id;
          _patient = null;
        }),
        child: _selected == 'dashboard'
            ? FrontDeskOverview(
                appointments: _appointments,
                invoices: const [],
                available: const {
                  AppFeature.reception,
                  AppFeature.patients,
                  AppFeature.appointments,
                },
                onOpen: (f) => setState(() => _selected = f.name),
                clinic: const ClinicProfile(
                  id: 'synthetic',
                  name: 'Aarogya Clinic',
                ),
                now: DateTime(2026, 10, 28),
                displayName: 'Priya Nair',
              )
            : _selected == 'reception'
            ? FrontDeskQueue(
                items: _appointments,
                clinic: const ClinicProfile(
                  id: 'synthetic',
                  name: 'Aarogya Clinic',
                ),
                now: DateTime(2026, 10, 28),
                onAction: (_, _) async {
                  throw const OperationalFailure('synthetic-preview');
                },
              )
            : _selected == 'appointments'
            ? OperationalScheduleView(
                clinic: const ClinicProfile(
                  id: 'synthetic',
                  name: 'Aarogya Clinic',
                ),
                repository: repository,
                patients: Stream.value(_patients),
              )
            : _patient == null
            ? PatientDirectoryView(
                patients: _patients,
                onOpen: (p) => setState(() => _patient = p),
                onRegister: () => _register(context),
              )
            : AdministrativePatientProfileView(
                patient: _patient!,
                onBack: () => setState(() => _patient = null),
                onBook: () => setState(() => _selected = 'appointments'),
              ),
      ),
    ),
  );
}

class _PreviewOperations implements OperationalRepository {
  @override
  Future<List<Practitioner>> practitioners() async => const [
    Practitioner('synthetic-doctor', 'Dr. Ananya Mehta'),
  ];
  @override
  Stream<List<AppointmentModel>> appointments({String? doctorId}) =>
      Stream.value(const []);
  @override
  Future<void> command(Map<String, Object?> input) async =>
      throw const OperationalFailure('synthetic-preview');
  @override
  String newOperationId() => 'synthetic-operation';
}
