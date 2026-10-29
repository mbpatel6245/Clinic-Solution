import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../../../data/datasources/clinical_models.dart';
import '../domain/clinical_repository.dart';

class FirebaseClinicalRepository
    implements
        ClinicalRepository,
        ClinicalVersionRepository,
        ClinicalDraftListing {
  FirebaseClinicalRepository(
    this.clinicId, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? client,
    String? projectId,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _user = (auth ?? FirebaseAuth.instance).currentUser?.uid,
       _client = client ?? http.Client(),
       _project = projectId ?? Firebase.app().options.projectId;
  final String clinicId, _project;
  final String? _user;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final http.Client _client;
  void _check() {
    if (_user == null || _auth.currentUser?.uid != _user) {
      throw const ClinicalFailure('unauthenticated');
    }
  }

  @override
  String newOperationId() => _db
      .collection('clinics')
      .doc(clinicId)
      .collection('clinical_receipts')
      .doc()
      .id;
  @override
  Future<ClinicalEncounter> load(String encounterId) async {
    _check();
    final clinic = _db.collection('clinics').doc(clinicId);
    // Online transactions keep the draft, private note and public projection at
    // one read version even when another window signs an amendment concurrently.
    final result = await _db
        .runTransaction<ClinicalEncounter>((transaction) async {
          _check();
          final snapshot = await transaction.get(
            clinic.collection('clinical_encounters').doc(encounterId),
          );
          final e = snapshot.data();
          if (e == null || e['author_id'] != _user) {
            throw const ClinicalFailure('permission-denied');
          }
          final private = await transaction.get(
            clinic.collection('clinical_encounter_private').doc(encounterId),
          );
          _check();
          final projection = (e['version'] as num).toInt() > 0
              ? await transaction.get(
                  clinic.collection('prescriptions').doc(encounterId),
                )
              : null;
          _check();
          if (e['state'] == 'signed' &&
              projection?.data()?['clinical_version'] != e['version']) {
            throw const ClinicalFailure('aborted');
          }
          final record = Map<String, dynamic>.from(
            (e['state'] == 'signed' ? projection!.data() : e['record']) as Map,
          );
          return ClinicalEncounter(
            id: encounterId,
            revision: (e['revision'] as num).toInt(),
            version: (e['version'] as num).toInt(),
            releasedVersion: projection?.data()?['shared_with_patient'] == true
                ? (e['released_version'] as num?)?.toInt() ?? 0
                : 0,
            state: e['state'] as String,
            privateNotes: private.data()?['body']?.toString() ?? '',
            record: PrescriptionModel.fromMap({
              ...record,
              'patient': e['patient'],
              'patient_id': e['patient_id'],
              'appointment_id': e['appointment_id'],
              '_clinic_id': clinicId,
              'clinical_state': e['state'],
              'clinical_version': e['version'],
              'clinical_author_id': e['author_id'],
            }, encounterId),
          );
        })
        .timeout(const Duration(seconds: 30));
    _check();
    return result;
  }

  @override
  Future<void> command(Map<String, Object?> input) async {
    _check();
    if (input['clinicId'] != null && input['clinicId'] != clinicId) {
      throw const ClinicalFailure('permission-denied');
    }
    try {
      final token = await _auth.currentUser!.getIdToken().timeout(
        const Duration(seconds: 20),
      );
      _check();
      if (token == null || token.isEmpty) {
        throw const ClinicalFailure('unauthenticated');
      }
      final response = await _client
          .post(
            Uri.https(
              'asia-south1-$_project.cloudfunctions.net',
              '/clinicalCommand',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'data': {...input, 'clinicId': clinicId},
            }),
          )
          .timeout(const Duration(seconds: 20));
      _check();
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw const ClinicalFailure('unavailable', uncertain: true);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ClinicalFailure('permission-denied');
      }
      final body = jsonDecode(response.body) as Map;
      if (body['error'] is Map) {
        throw ClinicalFailure(
          (body['error'] as Map)['status']?.toString().toLowerCase().replaceAll(
                '_',
                '-',
              ) ??
              'rejected',
        );
      }
      if (response.statusCode != 200 || body['result'] is! Map) {
        throw const ClinicalFailure('unknown', uncertain: true);
      }
    } on ClinicalFailure {
      rethrow;
    } catch (_) {
      throw const ClinicalFailure('unknown', uncertain: true);
    }
  }

  @override
  Future<List<PrescriptionModel>> drafts(String patientId) async {
    _check();
    final data = await _db
        .collection('clinics')
        .doc(clinicId)
        .collection('clinical_encounters')
        .where('author_id', isEqualTo: _user)
        .where('patient_id', isEqualTo: patientId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    _check();
    return data.docs
        .where((doc) => doc.data()['state'] == 'draft')
        .map(
          (doc) => PrescriptionModel.fromMap({
            ...Map<String, dynamic>.from(doc.data()['record'] as Map),
            'patient': doc.data()['patient'],
            'patient_id': patientId,
            'appointment_id': doc.data()['appointment_id'],
            'created_at': doc.data()['created_at'],
            'clinical_state': 'draft',
            '_clinic_id': clinicId,
          }, doc.id),
        )
        .toList();
  }

  @override
  Future<List<PrescriptionModel>> versions(String encounterId) async {
    _check();
    final data = await _db
        .collection('clinics')
        .doc(clinicId)
        .collection('clinical_encounters')
        .doc(encounterId)
        .collection('versions')
        .where('author_id', isEqualTo: _user)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    _check();
    return data.docs
        .map(
          (doc) => PrescriptionModel.fromMap({
            ...Map<String, dynamic>.from(doc.data()['snapshot'] as Map),
            '_clinic_id': clinicId,
          }, encounterId),
        )
        .toList()
      ..sort((a, b) => b.clinicalVersion.compareTo(a.clinicalVersion));
  }

  @override
  void close() => _client.close();
}

Map<String, Object?> clinicalRecordPayload(PrescriptionModel record) => {
  'diagnoses': record.diagnoses,
  'complaints': record.complaints,
  'vitals': record.vitals,
  'investigation': record.investigation,
  'advice': record.advice,
  'medicines': record.medicines
      .where((m) => !m.isEmpty)
      .map((m) => m.toMap())
      .toList(),
  'visit_date': (record.visitDate ?? DateTime.now()).toUtc().toIso8601String(),
  'follow_up_date': record.followUpDate?.toUtc().toIso8601String(),
};
