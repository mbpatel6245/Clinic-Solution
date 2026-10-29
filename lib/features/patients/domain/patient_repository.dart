import '../../../core/domain/clinic_scope.dart';

/// Deliberately small administrative domain model. No Firebase/Flutter types.
final class PatientProfile {
  PatientProfile({
    required this.id,
    required this.firstName,
    this.lastName = '',
  }) {
    if (id.isEmpty || id.contains('/') || id.length > 128) {
      throw ArgumentError('A stable patient ID is required.');
    }
    if (firstName.trim().isEmpty ||
        firstName.length > 120 ||
        lastName.length > 120) {
      throw ArgumentError('A valid patient name is required.');
    }
  }
  final String id, firstName, lastName;
  String get displayName =>
      [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
}

enum RecordSyncState {
  confirmed,
  pending,
  conflict,
  rejected,
  authenticationRequired,
}

final class PatientRecord {
  const PatientRecord(this.patient, this.revision, this.syncState);
  final PatientProfile patient;
  final int revision;
  final RecordSyncState syncState;
}

final class LocalSave {
  const LocalSave(this.operationId);
  final String operationId;
}

abstract interface class PatientRepository {
  ClinicScope get scope;
  Future<List<PatientRecord>> list({
    String search = '',
    int limit = 50,
    int offset = 0,
  });
  Stream<void> get changes;
  Future<LocalSave> save(PatientProfile patient);
  Future<LocalSave> remove(String patientId);
}
