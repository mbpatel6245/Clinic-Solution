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
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/ui/views/home/revamp/prescription_preview.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_workspace.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_registry.dart';
import 'package:clinic_solution/ui/widgets/app_design.dart';

void main() => runApp(const RevampPreview());

class RevampPreview extends StatefulWidget {
  const RevampPreview({super.key});
  @override
  State<RevampPreview> createState() => _RevampPreviewState();
}

class _RevampPreviewState extends State<RevampPreview> {
  String _language = 'en';
  AppFeature _selected = AppFeature.dashboard;
  final _today = DateTime(2026, 10, 19);
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
  final _appointments = List.generate(
    4,
    (i) => AppointmentModel(
      id: 'queue-$i',
      patientName: 'Demo patient ${i + 1}',
      phone: '',
      scheduledAt: DateTime(2026, 10, 19, 9, i * 15),
      status: i < 2 ? 'confirmed' : 'booked',
    ),
  );
  void _open(AppFeature feature) => setState(() => _selected = feature);
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
    return MaterialApp(
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
          );
          return Scaffold(
            appBar: AppBar(
              title: const Text('orByteza · Demo Clinic'),
              actions: [
                IconButton(
                  tooltip: 'Patient workspace (demo)',
                  icon: const Icon(Icons.person_outline),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PatientWorkspaceView(
                        patient: _patients.first,
                        visits: [
                          PrescriptionModel(
                            patient: _patients.first,
                            visitDate: _today,
                            complaints: 'DEMO ONLY - Synthetic visit.',
                          ),
                        ],
                      ),
                    ),
                  ),
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
                                          builder: (_) => PatientWorkspaceView(
                                            patient: patient,
                                          ),
                                        ),
                                      ),
                                  visits: const [],
                                ),
                              )
                            : _selected == AppFeature.appointments
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Booking is available in the signed-in app at http://127.0.0.1:8090/login. This preview does not save appointments.',
                                  ),
                                ),
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
                                  for (var i = 0; i < 24; i++)
                                    PrescriptionModel(
                                      id: 'visit-$i',
                                      patient: _patients[i % _patients.length],
                                      visitDate: DateTime(2026, 10, 19 - i % 7),
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
    );
  }
}
