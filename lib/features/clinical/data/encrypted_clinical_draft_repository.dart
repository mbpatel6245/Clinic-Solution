import '../../patients/data/registration_draft_store.dart';
import '../domain/clinical_draft_repository.dart';

/// Reuses the audited AES-GCM, PBKDF2 and SQLite CAS implementation without
/// changing its database schema or mixing registration and consultation scopes.
class EncryptedClinicalDraftRepository implements ClinicalDraftRepository {
  EncryptedClinicalDraftRepository(this.scope, this.store);
  factory EncryptedClinicalDraftRepository.open(String scope) =>
      EncryptedClinicalDraftRepository(scope, RegistrationDraftStore.open());
  final String scope;
  final RegistrationDraftStore store;
  @override
  Future<int> save(
    Map<String, Object?> payload,
    String passphrase, {
    required int expectedRevision,
  }) => store.save(
    scope,
    payload,
    passphrase,
    expectedRevision: expectedRevision,
  );
  @override
  Future<RecoveredClinicalDraft?> restore(String passphrase) =>
      store.restore(scope, passphrase);
  @override
  Future<void> remove(int expectedRevision) =>
      store.remove(scope, expectedRevision);
  @override
  Future<void> close() => store.close();
}
