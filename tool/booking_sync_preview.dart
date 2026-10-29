import 'package:flutter/material.dart';
import 'package:clinic_solution/core/design/uvilo_theme.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/features/appointments/data/operational_repository.dart';
import 'package:clinic_solution/features/appointments/presentation/durable_booking_workspace.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';

/// Synthetic browser durability harness. No Firebase initialization or delivery.
void main() => runApp(const BookingSyncPreview());

class BookingSyncPreview extends StatefulWidget {
  const BookingSyncPreview({super.key});
  @override
  State<BookingSyncPreview> createState() => _BookingSyncPreviewState();
}

class _BookingSyncPreviewState extends State<BookingSyncPreview> {
  final authorized = ValueNotifier(true);
  final repository = _PreviewRepository();
  late final patients = Stream.value([
    PatientModel(id: 'synthetic-patient', firstName: 'Synthetic Patient'),
  ]);
  @override
  void dispose() {
    authorized.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: UviloTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Synthetic booking test'),
        actions: [
          Row(
            children: [
              Semantics(
                label: 'Simulated connection',
                child: Switch(
                  value: repository.online,
                  onChanged: (v) => setState(() => repository.online = v),
                ),
              ),
            ],
          ),
        ],
      ),
      body: DurableBookingWorkspace(
        clinic: const ClinicProfile(id: 'synthetic', name: 'Synthetic Clinic'),
        scope: '["synthetic-project","synthetic-user","synthetic-clinic"]',
        repository: repository,
        patients: patients,
        authorized: () => authorized.value,
        authorizationChanges: authorized,
      ),
    ),
  );
}

class _PreviewRepository implements OperationalRepository {
  bool online = false;
  final accepted = <String>{};
  int sequence = 0;
  @override
  Future<List<Practitioner>> practitioners() async => const [
    Practitioner('synthetic-doctor', 'Synthetic Doctor'),
  ];
  @override
  Stream<List<AppointmentModel>> appointments({String? doctorId}) =>
      Stream.value(const []);
  @override
  Future<void> command(Map<String, Object?> command) async {
    if (!online) throw const OperationalFailure('unavailable', unknown: true);
    accepted.add(command['operationId']! as String);
  }

  @override
  String newOperationId() =>
      'synthetic-${DateTime.now().microsecondsSinceEpoch}-${sequence++}';
}
