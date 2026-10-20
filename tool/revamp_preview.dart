// Local visual review only. Synthetic fixtures, no Firebase initialization,
// network services or persistence. Not the production application entry point.
import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:clinic_solution/core/design/app_theme.dart';
import 'package:clinic_solution/core/design/revamp_labels.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:clinic_solution/ui/views/home/revamp/practice_dashboard.dart';
import 'package:clinic_solution/ui/views/home/revamp/queue_workspace.dart';
import 'package:clinic_solution/ui/views/home/revamp/workspace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:clinic_solution/services/firestore_services.dart';
import 'package:clinic_solution/services/session_controller.dart';
import 'package:clinic_solution/services/auth_services.dart';
import 'package:clinic_solution/data/datasources/workflow_models.dart';
import 'package:clinic_solution/data/datasources/prescription_print_settings.dart';
import 'package:clinic_solution/ui/views/home/new_prescription/tab_new_prescription.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/ui/views/home/revamp/prescription_preview.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_workspace.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_registry.dart';
import 'package:clinic_solution/ui/widgets/app_design.dart';
import 'package:clinic_solution/data/datasources/patient_intake.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_entry_dialog.dart';
import 'package:clinic_solution/ui/views/home/revamp/appointment_booking.dart';

void main() => runApp(const RevampPreview());

class RevampPreview extends StatefulWidget {
  const RevampPreview({super.key});
  @override
  State<RevampPreview> createState() => _RevampPreviewState();
}

class _RevampPreviewState extends State<RevampPreview> {
  String _language = 'en';
  AppFeature _selected = AppFeature.dashboard;
  final _today = DateTime.now();
  int _entrySequence = 0;
  PatientModel? _bookingPatient;
  final _clinic = _PreviewClinic();
  final _patients = List.generate(
    18,
    (i) => PatientModel(
      id: 'demo-$i',
      firstName: 'Demo patient ${i + 1}',
      age: 25 + i,
      gender: i.isEven ? 'female' : 'male',
      createdAt: DateTime(2026, 10, 19 - i),
    ),
  );
  late final _appointments = List.generate(
    4,
    (i) => AppointmentModel(
      id: 'queue-$i',
      patientName: 'Demo patient ${i + 1}',
      phone: '',
      patientId: _patients[i].id,
      patient: _patients[i],
      scheduledAt: DateTime(_today.year, _today.month, _today.day, 9, i * 15),
      status: i < 2 ? 'confirmed' : 'booked',
    ),
  );
  Future<PatientEntryResult?> _entry(
    BuildContext context, {
    DateTime? slot,
    bool walkIn = false,
  }) => showDialog<PatientEntryResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PatientEntryDialog(
      mode: slot != null
          ? PatientEntryMode.booking
          : walkIn
          ? PatientEntryMode.walkIn
          : PatientEntryMode.registration,
      slot: slot,
      initialPatient: slot == null ? null : _bookingPatient,
      slotLabel: slot == null
          ? null
          : appointmentSlotLabel(
              const ClinicProfile(id: 'demo', name: 'DEMO ONLY Clinic'),
              slot,
              _language,
            ),
      patients: () => Stream.value(List<PatientModel>.from(_patients)),
      newPatientId: () => 'demo-new-${_entrySequence++}',
      newAppointmentId: () => 'demo-entry-${_entrySequence++}',
      onSubmit: (value) async {
        final patient = value.patient;
        AppointmentModel? appointment;
        setState(() {
          if (value.isNew) _patients.add(patient);
          if (value.action != PatientEntryAction.openRecord) {
            appointment = AppointmentModel(
              id: value.appointmentId,
              patientId: patient.id,
              patient: patient,
              patientName: patient.fullName,
              phone: patient.phone,
              scheduledAt: value.scheduledAt!,
              status: value.action == PatientEntryAction.queue
                  ? 'confirmed'
                  : 'booked',
            );
            _appointments.add(appointment!);
          }
        });
        return PatientEntryResult(
          patient,
          value.action,
          appointment: appointment,
        );
      },
    ),
  );
  Future<void> _add(BuildContext context, {bool walkIn = false}) async {
    final result = await _entry(context, walkIn: walkIn);
    if (!context.mounted || result == null) return;
    if (result.action == PatientEntryAction.queue) {
      _open(AppFeature.reception);
    } else {
      _record(context, result.patient);
    }
  }

  void _record(BuildContext context, PatientModel patient) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientWorkspaceView(
          patient: patient,
          visits: _clinic.records,
          consultation: TabNewPrescription(initialPatient: patient),
          onBook: () {
            Navigator.pop(context);
            setState(() {
              _selected = AppFeature.appointments;
              _bookingPatient = patient;
            });
          },
        ),
      ),
    );
  }

  void _open(AppFeature feature) => setState(() {
    _selected = feature;
    _bookingPatient = null;
  });
  @override
  Widget build(BuildContext context) {
    final locale = Locale(_language), l = RevampLabels(_language);
    final links = [
      WorkspaceLink(
        AppFeature.dashboard,
        l.text('home'),
        Icons.space_dashboard_outlined,
      ),
      WorkspaceLink(
        AppFeature.reception,
        l.text('todayNav'),
        Icons.groups_outlined,
      ),
      WorkspaceLink(
        AppFeature.appointments,
        l.text('bookNav'),
        Icons.event_outlined,
      ),
      WorkspaceLink(
        AppFeature.patients,
        l.text('patients'),
        Icons.people_outline,
      ),
    ];
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FirebaseFireStore>.value(value: _clinic),
        ChangeNotifierProvider<SessionController>(
          create: (_) => _PreviewSession(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forLocale(locale),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final desktop =
                MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;
            final sidebar = PracticeNavigation(
              vertical: true,
              links: links,
              selected: _selected,
              onSelected: _open,
              onAddPatient: () => _add(context),
            );
            return Scaffold(
              appBar: AppBar(
                title: const Text('orByteza · Demo Clinic'),
                actions: [
                  IconButton(
                    tooltip: 'Add patient (demo)',
                    icon: const Icon(Icons.person_outline),
                    onPressed: () => _add(context),
                  ),
                  IconButton(
                    tooltip: 'Prescription PDF (demo)',
                    icon: const Icon(Icons.print_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PrescriptionPreviewView(
                          clinic: const ClinicProfile(
                            id: 'demo',
                            name: 'DEMO ONLY Clinic',
                            address: 'Synthetic document for layout review',
                          ),
                          record: PrescriptionModel(
                            patient: _patients.first,
                            visitDate: _today,
                            complaints: 'DEMO ONLY. No clinical treatment.',
                            medicines: const [
                              MedicineLine(
                                name: 'DEMO ONLY - Not a medicine',
                                instructions:
                                    'केवल डेमो। માત્ર ડેમો. Synthetic text only.',
                              ),
                            ],
                            advice: 'DEMO ONLY - Not valid for clinical use.',
                          ),
                        ),
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _language,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                      DropdownMenuItem(value: 'gu', child: Text('ગુજરાતી')),
                    ],
                    onChanged: (value) => setState(() => _language = value!),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              drawer: desktop ? null : Drawer(child: sidebar),
              bottomNavigationBar: desktop
                  ? null
                  : PracticeNavigation(
                      links: links,
                      selected: _selected,
                      onSelected: _open,
                    ),
              body: Column(
                children: [
                  const Material(
                    color: AppColors.soft,
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Visual preview · Synthetic data only',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (desktop) sidebar,
                        Expanded(
                          child: _selected == AppFeature.reception
                              ? QueueWorkspace(
                                  items: _appointments,
                                  now: _today,
                                  canPrescribe: false,
                                  onRegister: () => _add(context, walkIn: true),
                                  onAction: (item, status) async {
                                    setState(
                                      () =>
                                          _appointments[_appointments.indexOf(
                                            item,
                                          )] = AppointmentModel(
                                            id: item.id,
                                            patientName: item.patientName,
                                            phone: '',
                                            scheduledAt: item.scheduledAt,
                                            status: status,
                                          ),
                                    );
                                  },
                                )
                              : _selected == AppFeature.patients
                              ? AppPage(
                                  child: PatientDirectoryList(
                                    patients: _patients,
                                    onOpen: (patient) =>
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                PatientWorkspaceView(
                                                  patient: patient,
                                                ),
                                          ),
                                        ),
                                    visits: const [],
                                  ),
                                )
                              : _selected == AppFeature.appointments
                              ? AppointmentBookingView(
                                  clinic: const ClinicProfile(
                                    id: 'demo',
                                    name: 'DEMO ONLY Clinic',
                                    workingDays: {1, 2, 3, 4, 5, 6, 7},
                                  ),
                                  appointments: _appointments,
                                  onChooseSlot: (slot) =>
                                      _entry(context, slot: slot),
                                  onOpenPatient: (patient) =>
                                      _record(context, patient),
                                )
                              : PracticeDashboardView(
                                  available: const {
                                    AppFeature.dashboard,
                                    AppFeature.billing,
                                    AppFeature.vaccination,
                                    AppFeature.patients,
                                    AppFeature.prescriptionList,
                                    AppFeature.appointments,
                                    AppFeature.reception,
                                  },
                                  displayName: 'Demo Doctor',
                                  patients: _patients,
                                  appointments: _appointments,
                                  now: _today,
                                  onOpen: _open,
                                  visits: [
                                    ..._clinic.records,
                                    for (var i = 0; i < 24; i++)
                                      PrescriptionModel(
                                        id: 'visit-$i',
                                        patient:
                                            _patients[i % _patients.length],
                                        visitDate: DateTime(
                                          2026,
                                          10,
                                          19 - i % 7,
                                        ),
                                        diagnoses: [
                                          i.isEven
                                              ? 'Demo diagnosis A'
                                              : 'Demo diagnosis B',
                                        ],
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      '© 2026 ORBYTEZA TECH LLP. All rights reserved.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// These adapters only serve this explicit local demo. They never initialize
// Firebase or send clinic data over the network.
class _PreviewDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewAuth implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewSession extends SessionController {
  _PreviewSession() : super(auth: _PreviewAuth(), firestore: _PreviewDb());
  @override
  String get activeClinicId => 'demo';
  @override
  bool can(AppFeature feature) => feature != AppFeature.inventory;
}

class _PreviewClinic extends FirebaseFireStore {
  _PreviewClinic()
    : super(
        firestore: _PreviewDb(),
        authService: AuthService(auth: _PreviewAuth()),
      ) {
    useClinic('demo');
  }
  final records = <PrescriptionModel>[];
  final templates = <PrescriptionTemplate>[];
  int _next = 0;
  @override
  String createPrescriptionId() => 'demo-prescription-${_next++}';
  @override
  Future<String> savePrescription(
    PrescriptionModel record, {
    String? privateNotes,
    bool completeQueueVisit = false,
  }) async {
    records.add(record);
    return record.id;
  }

  @override
  Stream<List<PrescriptionTemplate>> streamPrescriptionTemplates() =>
      Stream.value(templates);
  @override
  Future<void> savePrescriptionTemplate(PrescriptionTemplate value) async {
    templates.add(value);
  }

  @override
  Stream<ClinicProfile> streamActiveClinic() =>
      Stream.value(const ClinicProfile(id: 'demo', name: 'DEMO ONLY Clinic'));
  @override
  Future<PrescriptionPrintSettings> getPrescriptionPrintSettings() async =>
      const PrescriptionPrintSettings();
}
