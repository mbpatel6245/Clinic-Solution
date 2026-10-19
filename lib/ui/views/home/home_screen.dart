import '../../../core/design/clinic_brand.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/login_portal.dart';
import '../../../core/constants/locale_key.dart';
import '../../../core/design/app_theme.dart';
import '../../../core/utils/locale_provider.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../data/datasources/workflow_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/local/secure_data_viewmodel.dart';
import '../../../services/firestore_services.dart';
import '../../../services/session_controller.dart';
import 'appointment/tab_appointments.dart';
import 'dashboard/clinic_overview.dart';
import 'new_prescription/tab_new_prescription.dart';
import 'prescription_list/tab_prescription_list.dart';
import 'stock_inward/tab_stock_inward_screen.dart';
import 'team/team_roles_screen.dart';
import 'enterprise/enterprise_screens.dart';
import 'sync_status_banner.dart';
import '../../../core/design/revamp_labels.dart';
import 'revamp/practice_dashboard.dart';
import 'revamp/patient_registry.dart';
import 'revamp/workspace_navigation.dart';
import 'revamp/clinical_workspaces.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  PatientModel? _prescriptionPatient;
  PrescriptionModel? _prescriptionToEdit;
  PrescriptionTemplate? _prescriptionTemplate;
  String _queueAppointmentId = '';
  int _prescriptionFormVersion = 0;
  String? _lastClinicId;
  final _secureData = SecureDataViewModel();
  bool _passwordDialogShown = false;

  @override
  void dispose() {
    _secureData.dispose();
    super.dispose();
  }

  void _selectFeature(
    List<_WorkspaceDestination> destinations,
    AppFeature feature,
  ) {
    final index = destinations.indexWhere((item) => item.feature == feature);
    if (index < 0) return;
    setState(() {
      _selectedIndex = index;
      if (feature == AppFeature.createPrescription &&
          (_prescriptionPatient != null ||
              _prescriptionToEdit != null ||
              _prescriptionTemplate != null)) {
        _prescriptionPatient = null;
        _prescriptionToEdit = null;
        _prescriptionTemplate = null;
        _queueAppointmentId = '';
        _prescriptionFormVersion++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final labels = RevampLabels.of(context);
    final session = context.watch<SessionController>();
    if (session.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_lastClinicId != session.activeClinicId) {
      _lastClinicId = session.activeClinicId;
      _selectedIndex = 0;
      _prescriptionPatient = null;
      _prescriptionToEdit = null;
      _prescriptionTemplate = null;
      _queueAppointmentId = '';
      _prescriptionFormVersion++;
    }
    if (session.mustChangePassword && !_passwordDialogShown) {
      _passwordDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _changePassword(context),
      );
    }
    context.read<FirebaseFireStore>().useClinic(session.activeClinicId);

    late List<_WorkspaceDestination> destinations;
    void startNewVisit(PatientModel patient) {
      final index = destinations.indexWhere(
        (item) => item.feature == AppFeature.createPrescription,
      );
      if (index < 0) return;
      setState(() {
        _prescriptionPatient = patient;
        _queueAppointmentId = '';
        _prescriptionTemplate = null;
        _prescriptionToEdit = null;
        _prescriptionFormVersion++;
        _selectedIndex = index;
      });
    }

    void editPrescription(PrescriptionModel prescription) {
      final index = destinations.indexWhere(
        (item) => item.feature == AppFeature.createPrescription,
      );
      if (index < 0) return;
      setState(() {
        _prescriptionPatient = null;
        _prescriptionToEdit = prescription;
        _queueAppointmentId = '';
        _prescriptionTemplate = null;
        _prescriptionFormVersion++;
        _selectedIndex = index;
      });
    }

    destinations = [
      if (session.can(AppFeature.dashboard) && !isFrontDeskOnly(session.roles))
        _WorkspaceDestination(
          feature: AppFeature.dashboard,
          label: strings.overview,
          icon: Icons.space_dashboard_outlined,
          selectedIcon: Icons.space_dashboard,
          page: session.isAllClinics
              ? const PlatformOverviewScreen()
              : session.role == AppRole.patient
              ? const PatientPortalScreen()
              : PracticeDashboard(
                  onOpen: (feature) => _selectFeature(destinations, feature),
                ),
        ),
      if (session.can(AppFeature.patients))
        _WorkspaceDestination(
          feature: AppFeature.patients,
          label: labels.text('patients'),
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          page: PatientRegistry(
            onNewVisit: session.can(AppFeature.createPrescription)
                ? startNewVisit
                : null,
          ),
        ),
      if (session.can(AppFeature.createPrescription))
        _WorkspaceDestination(
          feature: AppFeature.createPrescription,
          label: strings.newPrescription,
          icon: Icons.note_add_outlined,
          selectedIcon: Icons.note_add,
          page: TabNewPrescription(
            key: ValueKey(_prescriptionFormVersion),
            initialPatient: _prescriptionPatient,
            initialPrescription: _prescriptionToEdit,
            initialTemplate: _prescriptionTemplate,
            queueAppointmentId: _queueAppointmentId,
            onSaved: () {
              _prescriptionPatient = null;
              _prescriptionToEdit = null;
              _prescriptionTemplate = null;
              _queueAppointmentId = '';
              _prescriptionFormVersion++;
              _selectFeature(destinations, AppFeature.prescriptionList);
            },
          ),
        ),
      if (session.can(AppFeature.prescriptionList))
        _WorkspaceDestination(
          feature: AppFeature.prescriptionList,
          label: strings.prescriptionList,
          icon: Icons.manage_search_outlined,
          selectedIcon: Icons.manage_search,
          page: TabPrescriptionList(
            onNewVisit: startNewVisit,
            onEditPrescription: editPrescription,
          ),
        ),
      if (session.can(AppFeature.appointments) &&
          (session.role != AppRole.patient ||
              session.activeClinicId.isNotEmpty))
        _WorkspaceDestination(
          feature: AppFeature.appointments,
          label: strings.appointments,
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
          page: TabAppointments(patientOnly: session.role == AppRole.patient),
        ),
      if (session.can(AppFeature.reception))
        _WorkspaceDestination(
          feature: AppFeature.reception,
          label: labels.text('queue'),
          icon: Icons.how_to_reg_outlined,
          selectedIcon: Icons.how_to_reg,
          page: ReceptionScreen(
            onStartPrescription: session.can(AppFeature.createPrescription)
                ? (patient, appointment) {
                    startNewVisit(patient);
                    setState(() => _queueAppointmentId = appointment.id);
                  }
                : null,
          ),
        ),
      if (session.can(AppFeature.inventory))
        _WorkspaceDestination(
          feature: AppFeature.inventory,
          label: labels.text('pharmacy'),
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          page: const TabStockInward(),
        ),
      if (session.can(AppFeature.vaccination))
        _WorkspaceDestination(
          feature: AppFeature.vaccination,
          label: labels.text('vaccines'),
          icon: Icons.vaccines_outlined,
          selectedIcon: Icons.vaccines,
          page: const VaccinationScreen(),
        ),
      if (session.can(AppFeature.reminders))
        _WorkspaceDestination(
          feature: AppFeature.reminders,
          label: labels.text('reminders'),
          icon: Icons.notifications_active_outlined,
          selectedIcon: Icons.notifications_active,
          page: const RemindersScreen(),
        ),
      if (session.can(AppFeature.billing))
        _WorkspaceDestination(
          feature: AppFeature.billing,
          label: labels.text('billing'),
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          page: const BillingScreen(),
        ),
      if (session.can(AppFeature.finance))
        _WorkspaceDestination(
          feature: AppFeature.finance,
          label: strings.finance,
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          page: const FinanceLedgerScreen(),
        ),
      if (session.can(AppFeature.reports))
        _WorkspaceDestination(
          feature: AppFeature.reports,
          label: labels.text('reports'),
          icon: Icons.query_stats_outlined,
          selectedIcon: Icons.query_stats,
          page: const ReportsScreen(),
        ),
      if (session.can(AppFeature.dataExchange))
        _WorkspaceDestination(
          feature: AppFeature.dataExchange,
          label: labels.text('exchange'),
          icon: Icons.import_export_outlined,
          selectedIcon: Icons.import_export,
          page: const DataExchangeScreen(),
        ),
      if (session.can(AppFeature.team))
        _WorkspaceDestination(
          feature: AppFeature.team,
          label: strings.team,
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          page: const TeamRolesScreen(),
        ),
      if (session.can(AppFeature.clinicSetup))
        _WorkspaceDestination(
          feature: AppFeature.clinicSetup,
          label: labels.text('setup'),
          icon: Icons.settings_suggest_outlined,
          selectedIcon: Icons.settings_suggest,
          page: const ClinicSetupScreen(),
        ),
      if (session.can(AppFeature.prescriptionTemplates))
        _WorkspaceDestination(
          feature: AppFeature.prescriptionTemplates,
          label: labels.text('templates'),
          icon: Icons.snippet_folder_outlined,
          selectedIcon: Icons.snippet_folder,
          page: TemplateLibraryScreen(
            onUse: (template) {
              final index = destinations.indexWhere(
                (d) => d.feature == AppFeature.createPrescription,
              );
              if (index < 0) return;
              setState(() {
                _prescriptionPatient = null;
                _prescriptionToEdit = null;
                _prescriptionTemplate = template;
                _prescriptionFormVersion++;
                _selectedIndex = index;
              });
            },
          ),
        ),
      if (session.can(AppFeature.treatmentPlans))
        _WorkspaceDestination(
          feature: AppFeature.treatmentPlans,
          label: labels.text('plans'),
          icon: Icons.route_outlined,
          selectedIcon: Icons.route,
          page: const TreatmentPlansScreen(),
        ),
      if (session.can(AppFeature.laboratory))
        _WorkspaceDestination(
          feature: AppFeature.laboratory,
          label: labels.text('laboratory'),
          icon: Icons.science_outlined,
          selectedIcon: Icons.science,
          page: const LaboratoryScreen(),
        ),
      if (session.can(AppFeature.staffMessages))
        _WorkspaceDestination(
          feature: AppFeature.staffMessages,
          label: labels.text('messages'),
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum,
          page: const StaffMessagesScreen(),
        ),
    ];
    if (isFrontDeskOnly(session.roles)) {
      const priority = [
        AppFeature.reception,
        AppFeature.appointments,
        AppFeature.patients,
        AppFeature.billing,
        AppFeature.reminders,
        AppFeature.staffMessages,
      ];
      destinations.sort(
        (a, b) =>
            priority.indexOf(a.feature).compareTo(priority.indexOf(b.feature)),
      );
    }
    if (destinations.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final selectedIndex = _selectedIndex.clamp(0, destinations.length - 1);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;
    final features = destinations.map((d) => d.feature).toList();
    final primary = [
      AppFeature.dashboard,
      AppFeature.reception,
      AppFeature.appointments,
      AppFeature.patients,
    ].where(features.contains).take(3).toList();
    final selectedFeature = destinations[selectedIndex].feature;
    final pages = LazyWorkspacePages(
      key: ValueKey('${session.activeClinicId}:${features.join(',')}'),
      features: features,
      selected: selectedFeature,
      pages: destinations.map((d) => d.page).toList(),
    );

    return Scaffold(
      drawer: compact
          ? NavigationDrawer(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                Navigator.pop(context);
                setState(() => _selectedIndex = index);
              },
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 24, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ClinicLogo(size: 48),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 16, 12),
                  child: Text(
                    '${session.clinicName}\n${session.role.displayName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...destinations.map(
                  (item) => NavigationDrawerDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(
                      item.selectedIcon,
                      color: AppColors.inverse,
                    ),
                    label: Text(item.label),
                  ),
                ),
              ],
            )
          : null,
      appBar: AppBar(
        title: compact
            ? const ClinicLogo(size: 28)
            : Row(
                children: [
                  const ClinicLogo(size: 34),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      session.clinicName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        actions: [
          if (session.role == AppRole.platformOwner ||
              session.clinicIds.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Switch clinic',
              icon: const Icon(Icons.domain_outlined),
              onSelected: (value) => value == SessionController.allClinicsId
                  ? session.showAllClinics()
                  : session.selectClinic(value),
              itemBuilder: (_) => [
                if (session.role == AppRole.platformOwner)
                  PopupMenuItem(
                    value: SessionController.allClinicsId,
                    child: Row(
                      children: [
                        if (session.isAllClinics)
                          const Icon(Icons.check, size: 18),
                        if (session.isAllClinics) const SizedBox(width: 8),
                        const Text('All clinics'),
                      ],
                    ),
                  ),
                ...session.clinicIds.map(
                  (id) => PopupMenuItem(
                    value: id,
                    child: Row(
                      children: [
                        if (id == session.activeClinicId)
                          const Icon(Icons.check, size: 18),
                        if (id == session.activeClinicId)
                          const SizedBox(width: 8),
                        Flexible(child: Text(session.clinicNameFor(id))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (!compact)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: SyncStatusBanner(compact: true),
            ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Chip(label: Text(session.role.displayName)),
            ),
          PopupMenuButton<String>(
            tooltip: strings.language,
            icon: const Icon(Icons.translate),
            onSelected: (languageCode) =>
                context.read<LocaleProvider>().setLocale(Locale(languageCode)),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'hi', child: Text('हिन्दी')),
              PopupMenuItem(value: 'gu', child: Text('ગુજરાતી')),
            ],
          ),
          IconButton(
            tooltip: 'My profile',
            onPressed: () => _editProfile(context),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: strings.logout,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Log out?'),
                  content: const Text(
                    'Are you sure you want to end this session?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              await context.read<SessionController>().clear();
              await _secureData.clearData();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/${Constants.navLogin}');
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      bottomNavigationBar: compact
          ? Builder(
              builder: (scaffoldContext) => NavigationBar(
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                selectedIndex: primary.contains(selectedFeature)
                    ? primary.indexOf(selectedFeature)
                    : primary.length,
                onDestinationSelected: (index) {
                  if (index == primary.length) {
                    Scaffold.of(scaffoldContext).openDrawer();
                  } else {
                    _selectFeature(destinations, primary[index]);
                  }
                },
                destinations: [
                  for (final feature in primary)
                    NavigationDestination(
                      icon: Icon(destinations[features.indexOf(feature)].icon),
                      label: destinations[features.indexOf(feature)].label,
                    ),
                  NavigationDestination(
                    icon: const Icon(Icons.menu),
                    label: labels.text('more'),
                  ),
                ],
              ),
            )
          : null,
      body: compact
          ? pages
          : Row(
              children: [
                WorkspaceSidebar(
                  links: destinations
                      .map((d) => WorkspaceLink(d.feature, d.label, d.icon))
                      .toList(),
                  selected: selectedFeature,
                  onSelected: (feature) =>
                      _selectFeature(destinations, feature),
                  clinicName: session.clinicName,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages),
              ],
            ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;
    final session = context.read<SessionController>();
    final name = TextEditingController(text: session.displayName);
    final phone = TextEditingController();
    final email = TextEditingController(text: authUser.email ?? '');
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid)
        .get();
    phone.text = profile.data()?['phone']?.toString() ?? '';
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('My profile'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                    _changePassword(context);
                  },
                  icon: const Icon(Icons.password_outlined),
                  label: const Text('Change password'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    final service = context.read<FirebaseFireStore>();
    await authUser.updateDisplayName(name.text.trim());
    await service.updateMemberDetails(
      authUser.uid,
      name: name.text,
      phone: phone.text,
    );
    final requestedEmail = email.text.trim().toLowerCase();
    if (requestedEmail.isNotEmpty && requestedEmail != authUser.email) {
      await authUser.verifyBeforeUpdateEmail(requestedEmail);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification sent to $requestedEmail.')),
        );
      }
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final required = context.read<SessionController>().mustChangePassword;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: !required,
      builder: (dialogContext) => PopScope(
        canPop: !required,
        child: AlertDialog(
          title: Text(required ? 'Set your new password' : 'Change password'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!required)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
            FilledButton(
              onPressed: () {
                if (password.text.length < 8 ||
                    password.text != confirmation.text) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Use at least 8 matching characters.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Update password'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await FirebaseAuth.instance.currentUser!.updatePassword(password.text);
        if (context.mounted) {
          await context.read<SessionController>().markPasswordChanged();
        }
      } catch (_) {
        _passwordDialogShown = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in again, then change the password.'),
            ),
          );
        }
      }
    } else {
      _passwordDialogShown = false;
    }
  }
}

class _WorkspaceDestination {
  const _WorkspaceDestination({
    required this.feature,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final AppFeature feature;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}
