import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/clinical_artifact.dart';
import 'firebase_clinical_artifact_repository.dart';
import 'patient_prescription_stream.dart';

class PatientClinicalCopy {
  const PatientClinicalCopy(this.clinicId, this.artifact);
  final String clinicId;
  final ClinicalArtifact artifact;
}

/// Only whitelisted, explicitly released snapshots enter the patient view.
Stream<List<PatientClinicalCopy>> patientClinicalArtifacts(
  String userId, {
  FirebaseFirestore? firestore,
  FirebaseAuth? auth,
}) {
  final db = firestore ?? FirebaseFirestore.instance,
      identity = auth ?? FirebaseAuth.instance;
  if (userId.isEmpty || identity.currentUser?.uid != userId) {
    return Stream.value(const []);
  }
  return scopedPatientRecordStream<PatientClinicalCopy>(
    userId: userId,
    identities: identity.authStateChanges().map((u) => u?.uid),
    access: db.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data() ?? {},
          clinics = (data['clinic_ids'] as List? ?? [])
              .map((v) => v.toString())
              .toSet();
      return PatientClinicAccess(
        clinics,
        approved:
            doc.exists &&
            data['role'] == 'patient' &&
            (data['status'] ?? 'approved') == 'approved',
      );
    }),
    sharing: (clinic) => db
        .collection('clinics')
        .doc(clinic)
        .snapshots()
        .map(
          (doc) =>
              doc.exists &&
              doc.data()?['active'] != false &&
              doc.data()?['share_clinical_artifacts_with_patients'] == true,
        ),
    records: (clinic) => db
        .collection('clinics')
        .doc(clinic)
        .collection('clinical_artifact_copies')
        .where('patient_user_id', isEqualTo: userId)
        .where('shared', isEqualTo: true)
        .orderBy('issued_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PatientClinicalCopy(
                  clinic,
                  publicArtifactFromMap(doc.data(), doc.id),
                ),
              )
              .toList(),
        ),
    compare: (a, b) => (b.artifact.issuedAt ?? DateTime(1970)).compareTo(
      a.artifact.issuedAt ?? DateTime(1970),
    ),
  );
}
