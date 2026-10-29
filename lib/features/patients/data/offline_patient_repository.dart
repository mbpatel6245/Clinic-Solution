import 'dart:convert';
import '../../../core/domain/clinic_scope.dart';
import '../../../core/persistence/clinic_database.dart';
import '../../../core/sync/sync_contract.dart';
import '../domain/patient_repository.dart';

final class OfflinePatientRepository implements PatientRepository {
  OfflinePatientRepository({
    required this.database,
    required this.scope,
    required this.newId,
  });
  final ClinicDatabase database;
  @override
  final ClinicScope scope;
  final String Function() newId;
  @override
  Stream<void> get changes => database.changes;
  @override
  Future<List<PatientRecord>> list({
    String search = '',
    int limit = 50,
    int offset = 0,
  }) async =>
      (await database.patients(
        scope,
        search: search,
        limit: limit,
        offset: offset,
      )).map((row) {
        final data = jsonDecode(row.read<String>('payload')) as Map;
        return PatientRecord(
          PatientProfile(
            id: row.read<String>('id'),
            firstName: data['first_name'] as String,
            lastName: data['last_name'] as String? ?? '',
          ),
          row.read<int>('revision'),
          RecordSyncState.values.byName(
            row.readNullable<String>('sync_state') ?? 'confirmed',
          ),
        );
      }).toList();
  @override
  Future<LocalSave> save(PatientProfile patient) async {
    final id = newId();
    await database.stage(
      scope,
      operationId: id,
      entityId: patient.id,
      kind: MutationKind.put,
      patch: {
        'first_name': patient.firstName.trim(),
        'last_name': patient.lastName.trim(),
      },
    );
    return LocalSave(id);
  }

  @override
  Future<LocalSave> remove(String patientId) async {
    final id = newId();
    await database.stage(
      scope,
      operationId: id,
      entityId: patientId,
      kind: MutationKind.delete,
      patch: const {},
    );
    return LocalSave(id);
  }
}
