import '../../../data/datasources/clinical_models.dart';

enum ClinicalArtifactKind { labOrder, labResult, carePlan }

class ClinicalArtifact {
  const ClinicalArtifact({
    required this.id,
    required this.kind,
    required this.patient,
    required this.state,
    required this.revision,
    required this.version,
    required this.record,
    required this.input,
    required this.context,
    this.encounterId = '',
    this.orderStatus = '',
    this.releasedVersion = 0,
    this.published,
    this.issuedAt,
    this.collectedAt,
  });
  final String id, state, encounterId, orderStatus;
  final ClinicalArtifactKind kind;
  final PatientModel patient;
  final int revision, version, releasedVersion;
  final Map<String, dynamic> record, input, context;
  final Map<String, dynamic>? published;
  final DateTime? issuedAt, collectedAt;
  bool get issued => state == 'issued';
  String get title => record['title']?.toString() ?? '';
  String get recipientId => patient.userId;
  ClinicalArtifact asPublished() {
    final snapshot = published;
    if (snapshot == null) return this;
    return ClinicalArtifact(
      id: id,
      kind: kind,
      patient: PatientModel.fromMap({
        ...Map<String, dynamic>.from(snapshot['patient'] as Map),
        'user_id': snapshot['patient_user_id'],
      }, patient.id),
      state: state == 'cancelled' ? 'cancelled' : 'issued',
      revision: revision,
      version: (snapshot['version'] as num).toInt(),
      record: Map<String, dynamic>.from(snapshot['record'] as Map),
      input: const {},
      context: Map<String, dynamic>.from(snapshot['context'] as Map),
      releasedVersion: releasedVersion,
      published: snapshot,
      issuedAt: issuedAt,
      orderStatus: orderStatus,
      collectedAt: collectedAt,
    );
  }
}

class ClinicalArtifactFailure implements Exception {
  const ClinicalArtifactFailure(
    this.code, {
    this.uncertain = false,
    this.details = const {},
  });
  final String code;
  final bool uncertain;
  final Map<String, dynamic> details;
}

class ClinicalArtifactSources {
  const ClinicalArtifactSources({
    this.encounters = const [],
    this.plans = const [],
    this.vaccinations = const [],
    this.orders = const [],
  });
  final List<Map<String, dynamic>> encounters, plans, vaccinations;
  final List<ClinicalArtifact> orders;
}

abstract interface class ClinicalArtifactRepository {
  Stream<List<ClinicalArtifact>> watch({String? patientId});
  Future<ClinicalArtifact> load(String id);
  Future<ClinicalArtifactSources> sources(String patientId);
  Future<void> command(Map<String, Object?> command);
  Future<List<Map<String, dynamic>>> history(String id);
  Future<List<ClinicalArtifact>> versions(String id);
  String newId();
  void close();
}
