import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/locale_key.dart';
import '../../../core/utils/locale_provider.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/local/secure_data_viewmodel.dart';
import 'appointment/tab_appointments.dart';
import 'new_prescription/tab_new_prescription.dart';
import 'prescription_list/tab_prescription_list.dart';
import 'stock_inward/tab_stock_inward_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  PatientModel? _prescriptionPatient;
  int _prescriptionFormVersion = 0;
  final _secureData = SecureDataViewModel();

  @override
  void dispose() {
    _secureData.dispose();
    super.dispose();
  }

  void _startNewVisit(PatientModel patient) {
    setState(() {
      _prescriptionPatient = patient;
      _prescriptionFormVersion++;
      _selectedIndex = 0;
    });
  }

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0 && _prescriptionPatient != null) {
        _prescriptionPatient = null;
        _prescriptionFormVersion++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.note_add_outlined),
        selectedIcon: const Icon(Icons.note_add),
        label: strings.newPrescription,
      ),
      NavigationDestination(
        icon: const Icon(Icons.manage_search_outlined),
        selectedIcon: const Icon(Icons.manage_search),
        label: strings.prescriptionList,
      ),
      NavigationDestination(
        icon: const Icon(Icons.calendar_month_outlined),
        selectedIcon: const Icon(Icons.calendar_month),
        label: strings.appointments,
      ),
      NavigationDestination(
        icon: const Icon(Icons.inventory_2_outlined),
        selectedIcon: const Icon(Icons.inventory_2),
        label: strings.stockInward,
      ),
    ];

    final pages = <Widget>[
      TabNewPrescription(
        key: ValueKey(_prescriptionFormVersion),
        initialPatient: _prescriptionPatient,
        onSaved: () => setState(() => _selectedIndex = 1),
      ),
      TabPrescriptionList(onNewVisit: _startNewVisit),
      const TabAppointments(),
      const TabStockInward(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_hospital,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(strings.dashboard),
          ],
        ),
        actions: [
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
            tooltip: strings.logout,
            onPressed: () async {
              await _secureData.clearData();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                context.go('/${Constants.navLogin}');
              }
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return IndexedStack(index: _selectedIndex, children: pages);
          }
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _selectDestination,
                extended: constraints.maxWidth >= 1180,
                labelType: constraints.maxWidth >= 1180
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: destinations
                    .map(
                      (item) => NavigationRailDestination(
                        icon: item.icon,
                        selectedIcon: item.selectedIcon,
                        label: Text(item.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: pages),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectDestination,
              destinations: destinations,
            )
          : null,
    );
  }
}
