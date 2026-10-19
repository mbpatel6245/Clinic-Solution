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
  void _open(AppFeature feature) => setState(
    () => _selected = feature == AppFeature.reception
        ? feature
        : AppFeature.dashboard,
  );
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
        l.text('queue'),
        Icons.groups_outlined,
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
          final sidebar = WorkspaceSidebar(
            links: links,
            selected: _selected,
            onSelected: _open,
            clinicName: 'Demo Clinic',
          );
          return Scaffold(
            appBar: AppBar(
              title: const Text('orByteza · Demo Clinic'),
              actions: [
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
                : NavigationBar(
                    selectedIndex: _selected == AppFeature.dashboard ? 0 : 1,
                    onDestinationSelected: (index) => _open(
                      index == 0 ? AppFeature.dashboard : AppFeature.reception,
                    ),
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.space_dashboard_outlined),
                        label: l.text('home'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.groups_outlined),
                        label: l.text('queue'),
                      ),
                    ],
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
                            : PracticeDashboardView(
                                available: const {
                                  AppFeature.dashboard,
                                  AppFeature.patients,
                                  AppFeature.prescriptionList,
                                  AppFeature.appointments,
                                  AppFeature.reception,
                                },
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
