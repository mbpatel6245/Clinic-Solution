import '../../../data/datasources/clinical_models.dart';

class ClinicalEncounter {
  const ClinicalEncounter({
    required this.id,
    required this.revision,
    required this.version,
    required this.releasedVersion,
    required this.state,
    required this.record,
    this.privateNotes = '',
  });
  final String id, state;
  final int revision, version, releasedVersion;
  final PrescriptionModel record;
  final String privateNotes;
  bool get signed => state == 'signed';
}

class ClinicalFailure implements Exception {
  const ClinicalFailure(this.code, {this.uncertain = false});
  final String code;
  final bool uncertain;
}

abstract interface class ClinicalRepository {
  Future<ClinicalEncounter> load(String encounterId);
  Future<void> command(Map<String, Object?> input);
  String newOperationId();
  void close();
}

abstract interface class ClinicalVersionRepository {
  Future<List<PrescriptionModel>> versions(String encounterId);
}

abstract interface class ClinicalDraftListing {
  Future<List<PrescriptionModel>> drafts(String patientId);
}
