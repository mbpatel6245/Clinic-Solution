import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clinic_solution/core/design/uvilo_theme.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/workflow_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/ui/views/home/revamp/prescription_preview.dart';
import 'package:clinic_solution/features/clinical/presentation/prescription_review.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_draft_repository.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_repository.dart';
import 'package:clinic_solution/features/clinical/presentation/clinical_finalization_screen.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:clinic_solution/services/auth_services.dart';
import 'package:clinic_solution/services/firestore_services.dart';
import 'package:clinic_solution/services/session_controller.dart';
import 'package:clinic_solution/ui/views/home/new_prescription/tab_new_prescription.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_workspace.dart';

/// No Firebase initialization or network access. Synthetic UI review only.
void main() => runApp(const Phase3Preview());

final phase3Patient = PatientModel(
  id: 'SYNTHETIC-P001',
  firstName: 'Arjun',
  lastName: 'Nair',
  age: 42,
  gender: 'male',
  allergies: const ['Synthetic allergy record'],
  phone: '0000000000',
  userId: 'SYNTHETIC-ACCOUNT-P001',
);
final phase3Record = PrescriptionModel(
  id: 'SYNTHETIC-R001',
  patient: phase3Patient,
  visitDate: DateTime(2026, 10, 28),
  complaints: 'Synthetic presenting concern for layout review',
  vitals: 'Synthetic measurements — no clinical interpretation',
  diagnoses: const ['Synthetic assessment'],
  advice: 'Synthetic care instructions for layout review only',
  followUpDate: DateTime(2026, 11, 4),
  medicines: const [
    MedicineLine(
      name: 'Synthetic medicine — not for use',
      dosage: 'Sample dose',
      frequency: 'Sample frequency',
      duration: 'Sample duration',
      instructions: 'Layout example only',
    ),
  ],
);

class _NoDatabase implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Synthetic preview cannot use Firebase');
}

class _NoAuth implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Synthetic preview cannot authenticate');
}

class _PreviewSession extends SessionController {
  _PreviewSession(this.migration)
    : super(auth: _NoAuth(), firestore: _NoDatabase());
  final bool migration;
  @override
  bool get clinicalV3 => migration;
  @override
  bool get sharePrescriptionsWithPatients => migration;
}

class _PreviewClinic extends FirebaseFireStore {
  _PreviewClinic()
    : super(
        firestore: _NoDatabase(),
        authService: AuthService(auth: _NoAuth()),
      );
  int _sequence = 0;
  @override
  String createPrescriptionId() => 'synthetic-${_sequence++}';
  @override
  Future<String> savePrescription(
    PrescriptionModel prescription, {
    String? privateNotes,
    bool completeQueueVisit = false,
  }) async => prescription.id;
}

class Phase3Preview extends StatelessWidget {
  const Phase3Preview({
    super.key,
    this.screen = 'record',
    this.language = 'en',
    this.scale = 1,
    this.recoveryScope,
    this.draftRepositoryFactory,
    this.clinicalRepository,
  });
  final String screen, language;
  final double scale;
  final String? recoveryScope;
  final ClinicalDraftRepository Function()? draftRepositoryFactory;
  final ClinicalRepository? clinicalRepository;
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionController>(
        create: (_) => _PreviewSession(clinicalRepository != null),
      ),
      ChangeNotifierProvider<FirebaseFireStore>(
        create: (_) => _PreviewClinic(),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: UviloTheme.light,
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: _PreviewHome(
        screen: screen,
        recoveryScope: recoveryScope,
        draftRepositoryFactory: draftRepositoryFactory,
        clinicalRepository: clinicalRepository,
      ),
    ),
  );
}

class _PreviewHome extends StatelessWidget {
  const _PreviewHome({
    required this.screen,
    this.recoveryScope,
    this.draftRepositoryFactory,
    this.clinicalRepository,
  });
  final String screen;
  final String? recoveryScope;
  final ClinicalDraftRepository Function()? draftRepositoryFactory;
  final ClinicalRepository? clinicalRepository;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Text('SYNTHETIC UI PREVIEW · NO CLINICAL USE'),
          ),
        ),
        Expanded(
          child: switch (screen) {
            'consultation' => TabNewPrescription(
              recoveryScope: recoveryScope,
              draftRepositoryFactory: draftRepositoryFactory,
              clinicalRepository: clinicalRepository,
              initialPatient: phase3Patient,
              initialTemplate: PrescriptionTemplate(
                name: 'Synthetic example',
                diagnoses: phase3Record.diagnoses,
                complaints: phase3Record.complaints,
                advice: phase3Record.advice,
                medicines: phase3Record.medicines,
              ),
            ),
            'review' => PrescriptionReview(
              record: phase3Record,
              clinicName: 'Uvilo · Synthetic clinic',
            ),
            'final-review' || 'signed' => _FinalPreview(
              key: ValueKey(screen),
              signed: screen == 'signed',
            ),
            _ => PatientWorkspaceView(
              patient: phase3Patient,
              visits: [phase3Record],
              consultation: TabNewPrescription(initialPatient: phase3Patient),
              onPreview: (record) => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PrescriptionReview(
                    record: record,
                    clinicName: 'Synthetic clinic',
                  ),
                ),
              ),
            ),
          },
        ),
      ],
    ),
  );
}

class _SyntheticClinicalRepository
    implements ClinicalRepository, ClinicalVersionRepository {
  _SyntheticClinicalRepository(bool signed) {
    _update(signed: signed, revision: signed ? 2 : 1, version: signed ? 1 : 0);
  }
  late ClinicalEncounter current;
  void _update({
    required bool signed,
    required int revision,
    required int version,
    bool released = false,
  }) {
    current = ClinicalEncounter(
      id: phase3Record.id,
      revision: revision,
      version: version,
      releasedVersion: released ? version : 0,
      state: signed ? 'signed' : 'draft',
      record: PrescriptionModel(
        id: phase3Record.id,
        patient: phase3Patient,
        visitDate: phase3Record.visitDate,
        followUpDate: phase3Record.followUpDate,
        diagnoses: phase3Record.diagnoses,
        complaints: phase3Record.complaints,
        vitals: phase3Record.vitals,
        advice: phase3Record.advice,
        medicines: phase3Record.medicines,
        clinicalState: signed ? 'signed' : 'draft',
        clinicalVersion: version,
        clinicalPrintContext: signed
            ? const {
                'name': 'Uvilo · Synthetic clinic',
                'clinician_name': 'Synthetic practitioner',
              }
            : const {},
      ),
    );
  }

  @override
  Future<ClinicalEncounter> load(String id) async => current;
  @override
  Future<List<PrescriptionModel>> versions(String id) async => [current.record];
  @override
  String newOperationId() => 'synthetic-${current.revision}';
  @override
  void close() {}
  @override
  Future<void> command(Map<String, Object?> input) async {
    _update(
      signed: input['kind'] != 'amend',
      revision: current.revision + 1,
      version: input['kind'] == 'sign' ? current.version + 1 : current.version,
      released: input['kind'] == 'release',
    );
  }
}

class _FinalPreview extends StatefulWidget {
  const _FinalPreview({super.key, required this.signed});
  final bool signed;
  @override
  State<_FinalPreview> createState() => _FinalPreviewState();
}

class _FinalPreviewState extends State<_FinalPreview> {
  late final _repository = _SyntheticClinicalRepository(widget.signed);
  final _access = ValueNotifier(true);
  @override
  void dispose() {
    _access.dispose();
    _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClinicalFinalizationScreen(
    initial: _repository.current,
    repository: _repository,
    clinicName: 'Uvilo · Synthetic clinic',
    authorized: () => _access.value,
    changes: _access,
    sharingEnabled: () => true,
    onAmended: (_) {},
    onDone: () {},
    onPrint: (record) => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PrescriptionPreviewView(
          record: record,
          clinic: const ClinicProfile(
            id: 'synthetic',
            name: 'Synthetic clinic',
          ),
        ),
      ),
    ),
  );
}
