import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/platform/scoped_clinic_callable.dart';
import '../../../data/datasources/clinical_models.dart';
import '../domain/clinical_artifact.dart';

DateTime? artifactDate(Object? v) => v is Timestamp
    ? v.toDate()
    : v is DateTime
    ? v
    : DateTime.tryParse(v?.toString() ?? '');
ClinicalArtifact artifactFromMap(
  Map<String, dynamic> e,
  String id, {
  Map<String, dynamic>? copy,
}) => ClinicalArtifact(
  id: id,
  kind: ClinicalArtifactKind.values.byName(e['kind'] as String),
  patient: PatientModel.fromMap({
    ...Map<String, dynamic>.from(e['patient'] as Map),
    'user_id': e['patient_user_id'],
  }, e['patient_id'] as String),
  state: e['state'] as String,
  revision: (e['revision'] as num).toInt(),
  version: (e['version'] as num).toInt(),
  record: Map<String, dynamic>.from(e['record'] as Map),
  input: Map<String, dynamic>.from(e['input'] as Map),
  context: Map<String, dynamic>.from(e['context'] as Map),
  encounterId: e['encounter_id']?.toString() ?? '',
  orderStatus: e['order_status']?.toString() ?? '',
  releasedVersion: copy?['shared'] == true
      ? (copy!['version'] as num).toInt()
      : (e['released_version'] as num?)?.toInt() ?? 0,
  published: e['published_snapshot'] is Map
      ? Map<String, dynamic>.from(e['published_snapshot'] as Map)
      : null,
  issuedAt: artifactDate(e['issued_at']),
  collectedAt: artifactDate(e['collected_at']),
);

class FirebaseClinicalArtifactRepository implements ClinicalArtifactRepository {
  FirebaseClinicalArtifactRepository(
    this.clinicId, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ScopedClinicCallable? callable,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _user = (auth ?? FirebaseAuth.instance).currentUser?.uid,
       _callable = callable ?? ScopedClinicCallable(clinicId, auth: auth);
  final String clinicId;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String? _user;
  final ScopedClinicCallable _callable;
  CollectionReference<Map<String, dynamic>> get _artifacts =>
      _db.collection('clinics').doc(clinicId).collection('clinical_artifacts');
  void _check() {
    if (_user == null || _auth.currentUser?.uid != _user) {
      throw const ClinicalArtifactFailure('unauthenticated');
    }
  }

  @override
  String newId() => _artifacts.doc().id;
  @override
  Stream<List<ClinicalArtifact>> watch({String? patientId}) {
    _check();
    Query<Map<String, dynamic>> query = _artifacts.where(
      'author_id',
      isEqualTo: _user,
    );
    if (patientId != null) {
      query = query.where('patient_id', isEqualTo: patientId);
    }
    return query.snapshots().map((snapshot) {
      _check();
      return snapshot.docs
          .map((doc) => artifactFromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<ClinicalArtifact> load(String id) async {
    _check();
    final result = await _db
        .runTransaction<ClinicalArtifact>((tx) async {
          final parent = await tx.get(_artifacts.doc(id));
          final e = parent.data();
          if (e == null || e['author_id'] != _user) {
            throw const ClinicalArtifactFailure('permission-denied');
          }
          final copy = await tx.get(
            _db
                .collection('clinics')
                .doc(clinicId)
                .collection('clinical_artifact_copies')
                .doc(id),
          );
          _check();
          return artifactFromMap(
            {
              ...e,
              'released_version': copy.data()?['shared'] == true
                  ? copy.data()!['version']
                  : 0,
            },
            id,
            copy: copy.data(),
          );
        })
        .timeout(const Duration(seconds: 30));
    _check();
    return result;
  }

  @override
  Future<ClinicalArtifactSources> sources(String patientId) async {
    _check();
    final clinic = _db.collection('clinics').doc(clinicId);
    final encounters = await clinic
        .collection('clinical_encounters')
        .where('author_id', isEqualTo: _user)
        .where('patient_id', isEqualTo: patientId)
        .get(const GetOptions(source: Source.server));
    final plans = await clinic
        .collection('treatment_plans')
        .where('patient_id', isEqualTo: patientId)
        .get(const GetOptions(source: Source.server));
    // Vaccination access is optional. The UI/backend still reject selections
    // when that module is disabled; a denied optional source is not fabricated.
    List<Map<String, dynamic>> vaccinations = [];
    try {
      final data = await clinic
          .collection('vaccinations')
          .where('patient_id', isEqualTo: patientId)
          .get(const GetOptions(source: Source.server));
      vaccinations = data.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    final orders = await _artifacts
        .where('author_id', isEqualTo: _user)
        .where('patient_id', isEqualTo: patientId)
        .get(const GetOptions(source: Source.server));
    _check();
    return ClinicalArtifactSources(
      encounters: encounters.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList(),
      plans: plans.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      vaccinations: vaccinations,
      orders: orders.docs
          .where((doc) => doc.data()['kind'] == 'labOrder')
          .map((doc) => artifactFromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  @override
  Future<void> command(Map<String, Object?> input) async {
    _check();
    try {
      await _callable.call('clinicalArtifactCommand', input);
    } on ClinicCallableFailure catch (e) {
      throw ClinicalArtifactFailure(
        e.code,
        uncertain: e.uncertain,
        details: e.details,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> history(String id) async {
    _check();
    final data = await _artifacts
        .doc(id)
        .collection('release_history')
        .where('author_id', isEqualTo: _user)
        .get(const GetOptions(source: Source.server));
    _check();
    return data.docs.map((doc) => doc.data()).toList()..sort(
      (a, b) => (artifactDate(b['created_at']) ?? DateTime(1970)).compareTo(
        artifactDate(a['created_at']) ?? DateTime(1970),
      ),
    );
  }

  @override
  void close() => _callable.close();
  @override
  Future<List<ClinicalArtifact>> versions(String id) async {
    _check();
    final data = await _artifacts
        .doc(id)
        .collection('versions')
        .where('author_id', isEqualTo: _user)
        .get(const GetOptions(source: Source.server));
    _check();
    return data.docs
        .map(
          (doc) => publicArtifactFromMap(
            Map<String, dynamic>.from(doc.data()['snapshot'] as Map),
            id,
          ),
        )
        .toList()
      ..sort((a, b) => b.version.compareTo(a.version));
  }
}

ClinicalArtifact publicArtifactFromMap(Map<String, dynamic> data, String id) =>
    ClinicalArtifact(
      id: id,
      kind: ClinicalArtifactKind.values.byName(data['kind'] as String),
      patient: PatientModel.fromMap({
        ...Map<String, dynamic>.from(data['patient'] as Map),
        'user_id': data['patient_user_id'],
      }, data['patient_id'] as String),
      state: 'issued',
      revision: 0,
      version: (data['version'] as num).toInt(),
      record: Map<String, dynamic>.from(data['record'] as Map),
      input: const {},
      context: Map<String, dynamic>.from(data['context'] as Map),
      issuedAt: artifactDate(data['issued_at']),
    );
