import 'dart:convert';

/// Device-local recovery identity. New encounters have one recovery slot per
/// patient and clinician; existing prescriptions and queue entries are isolated.
class ClinicalDraftIdentity {
  ClinicalDraftIdentity({
    required String project,
    required String user,
    required String clinic,
    required String patient,
    required String encounter,
  }) {
    if ([
      project,
      user,
      clinic,
      patient,
      encounter,
    ].any((v) => v.trim().isEmpty)) {
      throw ArgumentError(
        'An authenticated patient/encounter scope is required',
      );
    }
    scope = jsonEncode([
      'clinical-draft-v1',
      project,
      user,
      clinic,
      patient,
      encounter,
    ]);
  }
  late final String scope;
}

typedef RecoveredClinicalDraft = ({int revision, Map<String, Object?> payload});

abstract interface class ClinicalDraftRepository {
  Future<int> save(
    Map<String, Object?> payload,
    String passphrase, {
    required int expectedRevision,
  });
  Future<RecoveredClinicalDraft?> restore(String passphrase);
  Future<void> remove(int expectedRevision);
  Future<void> close();
}
