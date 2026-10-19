import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../core/auth/app_role.dart';
import '../core/utils/module_record_path.dart';
import '../data/datasources/stock_model.dart';
import '../data/datasources/clinical_models.dart';
import '../data/datasources/enterprise_models.dart';
import '../data/datasources/user_model.dart';
import '../data/datasources/workflow_models.dart';
import 'auth_services.dart';

class FirebaseFireStore with ChangeNotifier {
  FirebaseFireStore({FirebaseFirestore? firestore, AuthService? authService})
    : _db = firestore ?? FirebaseFirestore.instance,
      _authService = authService ?? AuthService();
  final FirebaseFirestore _db;
  final AuthService _authService;
  bool _isLoading = true;

  static const String pathUser = "users";
  static const String pathStock = "stocks";
  static const String pathPatients = 'patients';
  static const String pathPrescriptions = 'prescriptions';
  static const String pathAppointments = 'appointments';
  static const String pathFinance = 'finance_entries';
  static const String pathInvoices = 'invoices';
  static const String pathVaccinations = 'vaccinations';
  static const String pathReminders = 'reminders';
  static const String pathAuditLogs = 'audit_logs';
  static const String pathTeamInvites = 'team_invites';

  String _activeClinicId = 'default-clinic';
  String get activeClinicId => _activeClinicId;

  void useClinic(String clinicId) {
    final normalized = clinicId.trim();
    if (normalized.isEmpty || normalized == _activeClinicId) return;
    _activeClinicId = normalized;
  }

  CollectionReference<Map<String, dynamic>> _collection(String path) {
    if (path == pathUser || path == 'clinics') return _db.collection(path);
    return _db.collection('clinics').doc(_activeClinicId).collection(path);
  }

  Future<List<Map<String, dynamic>>> exportModuleRecords(String path) async {
    final snapshot = await _collection(path).get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
  }

  Future<void> importModuleRecord(
    String path,
    Map<String, dynamic> data,
  ) async {
    final id = data.remove('id')?.toString() ?? '';
    final document = id.isEmpty
        ? _collection(path).doc()
        : _collection(path).doc(id);
    await _queueWrite(document.set(data, SetOptions(merge: true)));
  }

  bool get isLoading => _isLoading;
  List<UserModel> _users = [];

  List<UserModel> get users => _users;

  Future<void> _queueWrite(Future<void> operation) async {
    try {
      await operation.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Firestore keeps the original operation queued in its persistent cache.
      // Observe late failures without keeping an offline form/dialog blocked.
      unawaited(
        operation.catchError((Object error, StackTrace stackTrace) {
          debugPrint('Queued Firestore write failed: $error');
        }),
      );
    }
  }

  Future<void> registerUserData(
    String email,
    String password,
    String name,
    String phone,
    String role,
    String clinicName, {
    String locale = 'en',
  }) async {
    final userCredential = await _authService.createUserWithEmailAndPassword(
      email,
      password,
    );
    final user = userCredential.user;
    if (user == null) {
      throw StateError('Authentication account was not created.');
    }
    try {
      final appRole = AppRole.fromValue(role);
      final patient = appRole == AppRole.patient;
      await _db.collection(pathUser).doc(user.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'email_normalized': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'locale': locale,
        'role': role,
        if (!patient) 'requested_clinic_name': clinicName.trim(),
        'active_clinic_id': '',
        'clinic_ids': <String>[],
        'clinic_roles': <String, String>{},
        'status': patient ? 'approved' : 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      // A delivery failure must not delete a successfully registered account.
      try {
        await _authService.sendEmailVerification(locale: locale);
      } on FirebaseAuthException {
        debugPrint(
          'Verification email could not be sent; account was retained.',
        );
      }
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      await user.delete();
      await FirebaseAuth.instance.signOut();
      rethrow;
    }
  }

  //---------------------------
  Future<void> deleteStock(String stockDocumentId) async {
    try {
      await deleteDocument(path: pathStock, id: stockDocumentId);
    } catch (e) {
      debugPrint('Error deleting stock: $e');
    }
  }

  Future<void> addNewStock(
    StockModel stock,
    Function successCallback,
    Function errorCallback,
  ) async {
    try {
      final docRef = _collection(pathStock).withConverter(
        fromFirestore: StockModel.fromFirestore,
        toFirestore: (StockModel stockModel, options) =>
            stockModel.toFirestore(),
      );
      await docRef.add(stock);
      successCallback();
    } catch (e) {
      debugPrint('Error adding stock: $e');
      errorCallback(e);
    }
  }

  Future<void> updateStock(
    StockModel stock,
    String documentId,
    Function successCallback,
    Function errorCallback,
  ) async {
    try {
      final docRef = _collection(pathStock).doc(documentId);
      /*.withConverter(
        fromFirestore: StockModel.fromFirestore,
        toFirestore: (StockModel stockModel, options) => stockModel.toFirestore(),
      );*/
      await docRef.update(stock.toFirestore());
      successCallback();
      //await docRef.add(stock);
    } catch (e) {
      debugPrint('Error adding stock: $e');
      errorCallback(e);
    }
  }

  //---------------------------

  Stream<List<InventoryItem>> streamInventory() {
    return _collection(pathStock).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => InventoryItem.fromMap(doc.data(), doc.id))
          .where((item) => item.name.isNotEmpty)
          .toList();
      items.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    final data = item.toMap();
    if (item.id.isEmpty) {
      final document = _collection(pathStock).doc();
      await _queueWrite(document.set(data));
      return;
    }
    await _queueWrite(
      _collection(pathStock).doc(item.id).set(data, SetOptions(merge: true)),
    );
  }

  Future<void> adjustInventory(String id, double adjustment) async {
    final reference = _collection(pathStock).doc(id);
    await _queueWrite(
      reference.update({
        if (adjustment > 0) 'quantity_in': FieldValue.increment(adjustment),
        'remaining_quantity': FieldValue.increment(adjustment),
        'updated_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> removeInventoryItem(String id) =>
      _queueWrite(_collection(pathStock).doc(id).delete());

  Future<void> sellInventoryItem(
    InventoryItem item, {
    required double quantity,
    required String patientName,
  }) async {
    final stockReference = _collection(pathStock).doc(item.id);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(stockReference);
      final remaining =
          double.tryParse('${snapshot.data()?['remaining_quantity']}') ?? 0;
      if (quantity <= 0 || quantity > remaining) {
        throw StateError('Insufficient available stock.');
      }
      transaction.update(stockReference, {
        'remaining_quantity': FieldValue.increment(-quantity),
        'updated_at': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _collection(pathInvoices).doc(),
        ClinicInvoice(
          patientName: patientName.trim().isEmpty
              ? 'Walk-in customer'
              : patientName,
          lines: [
            InvoiceLine(
              type: 'pharmacy',
              description: '${item.name} × $quantity',
              amount: item.mrp * quantity,
            ),
          ],
          issuedAt: DateTime.now(),
          amountPaid: item.mrp * quantity,
          status: InvoiceStatus.paid,
        ).toMap(),
      );
    });
  }

  Stream<List<PrescriptionModel>> streamPrescriptions() {
    return _collection(pathPrescriptions).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => PrescriptionModel.fromMap(doc.data(), doc.id))
          .toList();
      items.sort((a, b) {
        final aDate = a.visitDate ?? a.createdAt ?? DateTime(1970);
        final bDate = b.visitDate ?? b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  Stream<List<PatientModel>> streamPatients() {
    return _collection(pathPatients).snapshots().map((snapshot) {
      final patients = snapshot.docs
          .map((doc) => PatientModel.fromMap(doc.data(), doc.id))
          .toList();
      patients.sort((a, b) => a.fullName.compareTo(b.fullName));
      return patients;
    });
  }

  Stream<List<PrescriptionTemplate>> streamPrescriptionTemplates() =>
      _collection('prescription_templates')
          .orderBy('name')
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => PrescriptionTemplate.fromMap(d.data(), d.id))
                .toList(),
          );
  Future<void> savePrescriptionTemplate(PrescriptionTemplate value) =>
      _queueWrite(
        (value.id.isEmpty
                ? _collection('prescription_templates').doc()
                : _collection('prescription_templates').doc(value.id))
            .set(value.toMap()),
      );
  Stream<List<TreatmentPlan>> streamTreatmentPlans() =>
      _collection('treatment_plans').snapshots().map(
        (s) =>
            s.docs.map((d) => TreatmentPlan.fromMap(d.data(), d.id)).toList(),
      );
  Future<void> saveTreatmentPlan(TreatmentPlan value) => _queueWrite(
    (value.id.isEmpty
            ? _collection('treatment_plans').doc()
            : _collection('treatment_plans').doc(value.id))
        .set(value.toMap()),
  );
  Stream<List<LabObservation>> streamLabObservations() =>
      _collection('laboratory')
          .where('record_type', isEqualTo: 'observation')
          .snapshots()
          .map(
            (s) =>
                s.docs
                    .map((d) => LabObservation.fromMap(d.data(), d.id))
                    .toList()
                  ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt)),
          );
  Future<void> saveLabObservation(LabObservation value) => _queueWrite(
    (value.id.isEmpty
            ? _collection('laboratory').doc()
            : _collection('laboratory').doc(value.id))
        .set({...value.toMap(), 'record_type': 'observation'}),
  );
  Stream<List<StaffMessage>> streamStaffMessages() =>
      _collection('staff_messages')
          .orderBy('sent_at', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => StaffMessage.fromMap(d.data(), d.id))
                .toList(),
          );
  Future<void> sendStaffMessage(String text, String senderName) => _queueWrite(
    _collection('staff_messages').doc().set({
      'text': text.trim(),
      'sender_name': senderName,
      'sender_id': FirebaseAuth.instance.currentUser!.uid,
      'sent_at': FieldValue.serverTimestamp(),
    }),
  );

  /// Register a profile without creating a visit, invoice or queue entry.
  Future<void> savePatientProfile(PatientModel patient) => _queueWrite(
    (patient.id.isEmpty
            ? _collection(pathPatients).doc()
            : _collection(pathPatients).doc(patient.id))
        .set(patient.toMap(), SetOptions(merge: true)),
  );

  Future<String> savePrescription(
    PrescriptionModel prescription, {
    String? privateNotes,
    bool completeQueueVisit = false,
  }) async {
    final patientReference = prescription.patient.id.isEmpty
        ? _collection(pathPatients).doc()
        : _collection(pathPatients).doc(prescription.patient.id);
    final prescriptionReference = prescription.id.isEmpty
        ? _collection(pathPrescriptions).doc()
        : _collection(pathPrescriptions).doc(prescription.id);
    final batch = _db.batch();
    batch.set(
      patientReference,
      prescription.patient.toMap()..removeWhere(
        (key, value) =>
            key == 'created_at' &&
            prescription.patient.id.isNotEmpty &&
            prescription.patient.createdAt == null,
      ),
      SetOptions(merge: true),
    );
    batch.set(
      prescriptionReference,
      prescription.toMap(patientReference.id),
      SetOptions(merge: true),
    );
    if (privateNotes != null) {
      batch.set(_collection('clinical_notes').doc(prescriptionReference.id), {
        'patient_id': patientReference.id,
        'body': privateNotes.trim(),
        'author_id': FirebaseAuth.instance.currentUser?.uid ?? '',
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    if (completeQueueVisit && prescription.appointmentId.isNotEmpty) {
      batch.update(
        _collection(pathAppointments).doc(prescription.appointmentId),
        {
          'status': 'completed',
          'completed_at': FieldValue.serverTimestamp(),
          'prescription_id': prescriptionReference.id,
          'updated_at': FieldValue.serverTimestamp(),
        },
      );
    }
    await _queueWrite(batch.commit());
    return prescriptionReference.id;
  }

  Future<String> getPrivateVisitNotes(String prescriptionId) async =>
      (await _collection(
        'clinical_notes',
      ).doc(prescriptionId).get()).data()?['body']?.toString() ??
      '';

  String createPrescriptionId() => _collection(pathPrescriptions).doc().id;

  Future<void> updatePrescriptionStatus(String id, String status) async {
    await _queueWrite(
      _collection(pathPrescriptions).doc(id).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> removePrescription(String id) =>
      _queueWrite(_collection(pathPrescriptions).doc(id).delete());

  Stream<List<AppointmentModel>> streamAppointments() {
    return _collection(pathAppointments).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
      items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return items;
    });
  }

  Stream<List<AppointmentModel>> streamAppointmentsForUser(String userId) {
    return _db
        .collectionGroup(pathAppointments)
        .where('created_by', isEqualTo: userId)
        .orderBy('scheduled_at', descending: true)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(
                (doc) => AppointmentModel.fromMap({
                  ...doc.data(),
                  '_clinic_id': doc.reference.parent.parent?.id ?? '',
                }, doc.id),
              )
              .toList();
          items.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
          return items;
        });
  }

  Stream<List<PrescriptionModel>> streamPatientPrescriptions(String userId) =>
      _db
          .collectionGroup(pathPrescriptions)
          .where('patient_user_id', isEqualTo: userId)
          .where('shared_with_patient', isEqualTo: true)
          .orderBy('visit_date', descending: true)
          .snapshots()
          .map((snapshot) {
            final items = snapshot.docs
                .map(
                  (doc) => PrescriptionModel.fromMap({
                    ...doc.data(),
                    '_clinic_id': doc.reference.parent.parent?.id ?? '',
                  }, doc.id),
                )
                .toList();
            items.sort((a, b) => b.visitTimestamp.compareTo(a.visitTimestamp));
            return items;
          });

  Stream<List<ClinicProfile>> streamPublicClinics() => _db
      .collection('clinics')
      .where('active', isEqualTo: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => ClinicProfile.fromMap(doc.data(), doc.id))
            .toList(),
      );

  Future<void> selectPatientClinic(String clinicId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _queueWrite(
      _db.collection(pathUser).doc(user.uid).update({
        'clinic_ids': FieldValue.arrayUnion([clinicId]),
        'active_clinic_id': clinicId,
        'updated_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> saveAppointment(AppointmentModel appointment) async {
    final data = appointment.toMap();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && appointment.createdBy == currentUser.uid) {
      final profile = await _db.collection(pathUser).doc(currentUser.uid).get();
      if (AppRole.fromValue(profile.data()?['role']?.toString()) ==
          AppRole.patient) {
        final patient = PatientModel(
          id: currentUser.uid,
          userId: currentUser.uid,
          firstName: appointment.patientName,
          phone: appointment.phone,
        );
        final appointmentReference = appointment.id.isEmpty
            ? _collection(pathAppointments).doc()
            : _collection(pathAppointments).doc(appointment.id);
        final embedded = patient.toMap()
          ..remove('created_at')
          ..remove('updated_at');
        final batch = _db.batch();
        batch.set(
          _collection(pathPatients).doc(currentUser.uid),
          patient.toMap(),
          SetOptions(merge: true),
        );
        batch.set(
          appointmentReference,
          data
            ..['patient_id'] = currentUser.uid
            ..['patient'] = embedded,
          SetOptions(merge: true),
        );
        await _queueWrite(batch.commit());
        return;
      }
    }
    if (appointment.id.isEmpty) {
      final document = _collection(pathAppointments).doc();
      await _queueWrite(document.set(data));
      return;
    }
    await _queueWrite(
      _collection(
        pathAppointments,
      ).doc(appointment.id).set(data, SetOptions(merge: true)),
    );
  }

  Future<PatientModel> saveReceptionVisit(
    PatientModel patient,
    AppointmentModel appointment,
  ) async {
    final patientReference = patient.id.isEmpty
        ? _collection(pathPatients).doc()
        : _collection(pathPatients).doc(patient.id);
    final appointmentReference = appointment.id.isEmpty
        ? _collection(pathAppointments).doc()
        : _collection(pathAppointments).doc(appointment.id);
    final savedPatient = patient.copyWith(id: patientReference.id);
    final embeddedPatient = savedPatient.toMap()
      ..remove('created_at')
      ..remove('updated_at');
    final appointmentData = appointment.toMap()
      ..['patient_id'] = patientReference.id
      ..['patient'] = embeddedPatient;
    final batch = _db.batch();
    batch.set(patientReference, savedPatient.toMap(), SetOptions(merge: true));
    batch.set(appointmentReference, appointmentData, SetOptions(merge: true));
    final lines = <InvoiceLine>[
      if (appointment.doctorFee > 0)
        InvoiceLine(
          type: 'doctor',
          description: 'Doctor consultation',
          amount: appointment.doctorFee,
        ),
      if (appointment.clinicFee > 0)
        InvoiceLine(
          type: 'clinic',
          description: 'Clinic / case fee',
          amount: appointment.clinicFee,
        ),
    ];
    if (lines.isNotEmpty) {
      final total = appointment.doctorFee + appointment.clinicFee;
      batch.set(
        _collection(pathInvoices).doc(),
        ClinicInvoice(
          patientId: patientReference.id,
          patientName: savedPatient.fullName,
          lines: lines,
          issuedAt: appointment.scheduledAt,
          amountPaid: appointment.amountPaid,
          status: appointment.amountPaid >= total
              ? InvoiceStatus.paid
              : appointment.amountPaid > 0
              ? InvoiceStatus.partiallyPaid
              : InvoiceStatus.unpaid,
        ).toMap(),
      );
    }
    await _queueWrite(batch.commit());
    return savedPatient;
  }

  Future<PatientModel?> getPatient(String patientId) async {
    if (patientId.isEmpty) return null;
    final snapshot = await _collection(pathPatients).doc(patientId).get();
    final data = snapshot.data();
    return data == null ? null : PatientModel.fromMap(data, snapshot.id);
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    await _queueWrite(
      _collection(pathAppointments).doc(id).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> removeAppointment(String id) =>
      _queueWrite(_collection(pathAppointments).doc(id).delete());

  Stream<List<FinanceEntry>> streamFinanceEntries() {
    return _collection(pathFinance).snapshots().map((snapshot) {
      final entries = snapshot.docs
          .map((doc) => FinanceEntry.fromMap(doc.data(), doc.id))
          .toList();
      entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return entries;
    });
  }

  Future<void> saveFinanceEntry(FinanceEntry entry) async {
    final document = entry.id.isEmpty
        ? _collection(pathFinance).doc()
        : _collection(pathFinance).doc(entry.id);
    await _queueWrite(document.set(entry.toMap(), SetOptions(merge: true)));
  }

  Future<void> removeFinanceEntry(String id) =>
      _queueWrite(_collection(pathFinance).doc(id).delete());

  Stream<ClinicProfile> streamActiveClinic() => _db
      .collection('clinics')
      .doc(_activeClinicId)
      .snapshots()
      .map((doc) => ClinicProfile.fromMap(doc.data() ?? const {}, doc.id));

  Stream<List<ClinicProfile>> streamClinics(List<String> clinicIds) {
    if (clinicIds.isEmpty) return const Stream.empty();
    return _db
        .collection('clinics')
        .where(FieldPath.documentId, whereIn: clinicIds.take(30).toList())
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClinicProfile.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<ClinicProfile>> streamAllClinics() =>
      _db.collection('clinics').snapshots().map((snapshot) {
        final clinics = snapshot.docs
            .map((doc) => ClinicProfile.fromMap(doc.data(), doc.id))
            .toList();
        clinics.sort((a, b) => a.name.compareTo(b.name));
        return clinics;
      });

  Stream<PlatformNotificationSettings> streamPlatformNotificationSettings() =>
      _db
          .collection('platform_settings')
          .doc('notifications')
          .snapshots()
          .map(
            (snapshot) => PlatformNotificationSettings.fromMap(
              snapshot.data() ?? const <String, dynamic>{},
            ),
          );

  Future<void> savePlatformNotificationSettings(
    PlatformNotificationSettings settings,
  ) => _queueWrite(
    _db
        .collection('platform_settings')
        .doc('notifications')
        .set(settings.toMap(), SetOptions(merge: true)),
  );

  Stream<PlatformModuleSettings> streamPlatformModuleSettings() => _db
      .collection('platform_settings')
      .doc('modules')
      .snapshots()
      .map(
        (snapshot) =>
            PlatformModuleSettings.fromMap(snapshot.data() ?? const {}),
      );

  Future<void> savePlatformModuleSettings(PlatformModuleSettings settings) =>
      _queueWrite(
        _db
            .collection('platform_settings')
            .doc('modules')
            .set(settings.toMap(), SetOptions(merge: true)),
      );

  static String moduleCollectionPath(ClinicModule module) => switch (module) {
    ClinicModule.patients => pathPatients,
    ClinicModule.reception || ClinicModule.appointments => pathAppointments,
    ClinicModule.clinical => pathPrescriptions,
    ClinicModule.pharmacy => pathStock,
    ClinicModule.vaccination => pathVaccinations,
    ClinicModule.reminders => pathReminders,
    ClinicModule.billing => pathInvoices,
    ClinicModule.expenses => pathFinance,
    ClinicModule.laboratory => 'laboratory',
    ClinicModule.reports || ClinicModule.dataExchange => '',
  };

  Stream<List<PlatformModuleRecord>> streamAllModuleRecords(
    ClinicModule module,
  ) {
    final path = moduleCollectionPath(module);
    if (path.isEmpty) return Stream.value(const []);
    return _db
        .collectionGroup(path)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where(
                (doc) => isClinicModuleRecordPath(doc.reference.path, path),
              )
              .map(
                (doc) => PlatformModuleRecord(
                  id: doc.id,
                  clinicId: doc.reference.parent.parent?.id ?? '',
                  data: doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<void> deletePlatformModuleRecord(
    ClinicModule module,
    PlatformModuleRecord record,
  ) => _queueWrite(
    _db
        .collection('clinics')
        .doc(record.clinicId)
        .collection(moduleCollectionPath(module))
        .doc(record.id)
        .delete(),
  );

  Future<int> deleteModuleData(ClinicModule module, {String? clinicId}) async {
    final path = moduleCollectionPath(module);
    if (path.isEmpty) return 0;
    final snapshot = clinicId == null
        ? await _db.collectionGroup(path).get()
        : await _db.collection('clinics').doc(clinicId).collection(path).get();
    final records = snapshot.docs
        .where((doc) => isClinicModuleRecordPath(doc.reference.path, path))
        .toList();
    for (var offset = 0; offset < records.length; offset += 400) {
      final batch = _db.batch();
      for (final doc in records.skip(offset).take(400)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return records.length;
  }

  Stream<List<TeamInvitation>> streamTeamInvitations({
    bool allClinics = false,
  }) =>
      (allClinics
              ? _db.collectionGroup(pathTeamInvites).snapshots()
              : _collection(pathTeamInvites).snapshots())
          .map((snapshot) {
            final invitations = snapshot.docs
                .map(
                  (doc) => TeamInvitation.fromMap(
                    doc.data(),
                    doc.id,
                    clinicId:
                        doc.reference.parent.parent?.id ?? _activeClinicId,
                  ),
                )
                .toList();
            invitations.sort(
              (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
                a.createdAt ?? DateTime(1970),
              ),
            );
            return invitations;
          });

  Future<void> approveTeamInvitation(TeamInvitation invitation) async {
    final clinicId = invitation.clinicId.isEmpty
        ? _activeClinicId
        : invitation.clinicId;
    await _queueWrite(
      _db
          .collection('clinics')
          .doc(clinicId)
          .collection(pathTeamInvites)
          .doc(invitation.id)
          .update({
            'approval_status': 'processing',
            'approval_error': FieldValue.delete(),
            'approval_requested_at': FieldValue.serverTimestamp(),
            'approval_requested_by':
                FirebaseAuth.instance.currentUser?.uid ?? '',
          }),
    );
  }

  Future<void> deleteTeamInvitation(TeamInvitation invitation) {
    final clinicId = invitation.clinicId.isEmpty
        ? _activeClinicId
        : invitation.clinicId;
    return _queueWrite(
      _db
          .collection('clinics')
          .doc(clinicId)
          .collection(pathTeamInvites)
          .doc(invitation.id)
          .delete(),
    );
  }

  Future<void> resendTeamInvitation(TeamInvitation invitation) {
    final clinicId = invitation.clinicId.isEmpty
        ? _activeClinicId
        : invitation.clinicId;
    return _queueWrite(
      _db
          .collection('clinics')
          .doc(clinicId)
          .collection(pathTeamInvites)
          .doc(invitation.id)
          .update({
            'notification_status': 'queued',
            'notification_error': FieldValue.delete(),
            'resend_requested_at': FieldValue.serverTimestamp(),
            'resend_requested_by': FirebaseAuth.instance.currentUser?.uid ?? '',
          }),
    );
  }

  Future<String> createClinic(
    String name, {
    bool sharePrescriptionsWithPatients = false,
  }) async {
    await _ensureUniqueClinicName(name);
    final document = _db.collection('clinics').doc();
    await saveClinic(
      ClinicProfile(
        id: document.id,
        name: name,
        enabledModules: ClinicProfile.defaultModules,
        sharePrescriptionsWithPatients: sharePrescriptionsWithPatients,
      ),
    );
    return document.id;
  }

  Future<String> createClinicForApproval(String name) async {
    await _ensureUniqueClinicName(name);
    final document = _db.collection('clinics').doc();
    final clinic = ClinicProfile(
      id: document.id,
      name: name,
      enabledModules: ClinicProfile.defaultModules,
    );
    await _saveClinicWithUniqueName(clinic);
    return document.id;
  }

  Future<void> inviteTeamMember(
    String email,
    AppRole role, {
    String? clinicId,
    List<AppRole>? roles,
    String phone = '',
    String locale = 'en',
  }) async {
    final targetClinicId = clinicId ?? _activeClinicId;
    final normalizedEmail = email.trim().toLowerCase();
    final selectedRoles = (roles ?? [role]).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final existingUsers = await _db
        .collection(pathUser)
        .where('email_normalized', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (existingUsers.docs.isNotEmpty &&
        (existingUsers.docs.first.data()['clinic_ids'] as Iterable? ?? const [])
            .map((value) => value.toString())
            .contains(targetClinicId)) {
      throw StateError('This member already belongs to the selected clinic.');
    }
    final document = _db
        .collection('clinics')
        .doc(targetClinicId)
        .collection(pathTeamInvites)
        .doc(
          base64Url.encode(utf8.encode(normalizedEmail)).replaceAll('=', ''),
        );
    final existingInvitation = await document.get();
    if (existingInvitation.exists &&
        existingInvitation.data()?['status'] == 'pending') {
      throw StateError('A pending invitation already exists for this clinic.');
    }
    await _queueWrite(
      document.set({
        'email': normalizedEmail,
        'phone': phone.trim(),
        'locale': locale,
        'role': selectedRoles.first.storageValue,
        'roles': selectedRoles.map((item) => item.storageValue).toList(),
        'status': 'pending',
        'notification_status': 'queued',
        'invited_by': FirebaseAuth.instance.currentUser?.uid ?? '',
        'created_at': FieldValue.serverTimestamp(),
      }),
    );
    await _writeAuditToClinic(targetClinicId, 'team.invited', document.id);
  }

  Future<void> _ensureUniqueClinicName(
    String name, {
    String excludeClinicId = '',
  }) async {
    final normalized = name.trim().toLowerCase();
    final matches = await _db
        .collection('clinics')
        .where('name_normalized', isEqualTo: normalized)
        .limit(1)
        .get();
    final duplicate =
        matches.docs.any((doc) => doc.id != excludeClinicId) ||
        (matches.docs.isEmpty &&
            (await _db.collection('clinics').get()).docs.any(
              (doc) =>
                  doc.id != excludeClinicId &&
                  doc.data()['name']?.toString().trim().toLowerCase() ==
                      normalized,
            ));
    if (duplicate) {
      throw StateError('A clinic with this name already exists.');
    }
  }

  Future<void> saveClinic(ClinicProfile clinic) async {
    final previous = await _db.collection('clinics').doc(clinic.id).get();
    final previouslyShared =
        previous.data()?['share_prescriptions_with_patients'] == true;
    await _ensureUniqueClinicName(clinic.name, excludeClinicId: clinic.id);
    await _saveClinicWithUniqueName(clinic);
    if (previouslyShared && !clinic.sharePrescriptionsWithPatients) {
      await _revokePatientPrescriptionSharing(clinic.id);
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _queueWrite(
        _db.collection(pathUser).doc(user.uid).set({
          'active_clinic_id': clinic.id,
          'clinic_ids': FieldValue.arrayUnion([clinic.id]),
        }, SetOptions(merge: true)),
      );
    }
    await _writeAuditToClinic(clinic.id, 'clinic.updated', clinic.id);
  }

  Future<void> _revokePatientPrescriptionSharing(String clinicId) async {
    final snapshot = await _db
        .collection('clinics')
        .doc(clinicId)
        .collection(pathPrescriptions)
        .where('shared_with_patient', isEqualTo: true)
        .get();
    for (var offset = 0; offset < snapshot.docs.length; offset += 400) {
      final batch = _db.batch();
      for (final doc in snapshot.docs.skip(offset).take(400)) {
        batch.update(doc.reference, {
          'shared_with_patient': false,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      await _queueWrite(batch.commit());
    }
  }

  String _clinicNameKey(String name) => base64Url
      .encode(utf8.encode(name.trim().toLowerCase()))
      .replaceAll('=', '');

  Future<void> _saveClinicWithUniqueName(ClinicProfile clinic) async {
    final clinicReference = _db.collection('clinics').doc(clinic.id);
    final newKey = _clinicNameKey(clinic.name);
    final keyReference = _db.collection('clinic_name_keys').doc(newKey);
    await _db.runTransaction((transaction) async {
      final existingClinic = await transaction.get(clinicReference);
      final existingKey = await transaction.get(keyReference);
      if (existingKey.exists &&
          existingKey.data()?['clinic_id']?.toString() != clinic.id) {
        throw StateError('A clinic with this name already exists.');
      }
      final previousName = existingClinic.data()?['name']?.toString() ?? '';
      final previousKey = previousName.isEmpty
          ? ''
          : _clinicNameKey(previousName);
      if (previousKey.isNotEmpty && previousKey != newKey) {
        transaction.delete(_db.collection('clinic_name_keys').doc(previousKey));
      }
      transaction.set(clinicReference, clinic.toMap(), SetOptions(merge: true));
      transaction.set(keyReference, {
        'clinic_id': clinic.id,
        'name_normalized': clinic.name.trim().toLowerCase(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteClinic(String clinicId) async {
    final reference = _db.collection('clinics').doc(clinicId);
    await _db.runTransaction((transaction) async {
      final clinic = await transaction.get(reference);
      final name = clinic.data()?['name']?.toString() ?? '';
      if (name.isNotEmpty) {
        transaction.delete(
          _db.collection('clinic_name_keys').doc(_clinicNameKey(name)),
        );
      }
      transaction.delete(reference);
    });
  }

  Stream<List<ClinicInvoice>> streamInvoices() =>
      _collection(pathInvoices).snapshots().map((snapshot) {
        final items = snapshot.docs
            .map((doc) => ClinicInvoice.fromMap(doc.data(), doc.id))
            .toList();
        items.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
        return items;
      });

  Future<void> saveInvoice(ClinicInvoice invoice) async {
    final document = invoice.id.isEmpty
        ? _collection(pathInvoices).doc()
        : _collection(pathInvoices).doc(invoice.id);
    await _queueWrite(document.set(invoice.toMap(), SetOptions(merge: true)));
    await logAudit('invoice.saved', document.id);
  }

  Stream<List<VaccinationRecord>> streamVaccinations() =>
      _collection(pathVaccinations).snapshots().map((snapshot) {
        final items = snapshot.docs
            .map((doc) => VaccinationRecord.fromMap(doc.data(), doc.id))
            .toList();
        items.sort((a, b) => b.administeredAt.compareTo(a.administeredAt));
        return items;
      });

  Future<void> saveVaccination(VaccinationRecord record) async {
    final document = record.id.isEmpty
        ? _collection(pathVaccinations).doc()
        : _collection(pathVaccinations).doc(record.id);
    await _queueWrite(document.set(record.toMap(), SetOptions(merge: true)));
    await logAudit('vaccination.saved', document.id);
  }

  Stream<List<ClinicReminder>> streamReminders() =>
      _collection(pathReminders).snapshots().map((snapshot) {
        final items = snapshot.docs
            .map((doc) => ClinicReminder.fromMap(doc.data(), doc.id))
            .toList();
        items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        return items;
      });

  Future<void> saveReminder(ClinicReminder reminder) async {
    final document = reminder.id.isEmpty
        ? _collection(pathReminders).doc()
        : _collection(pathReminders).doc(reminder.id);
    await _queueWrite(document.set(reminder.toMap(), SetOptions(merge: true)));
    await logAudit('reminder.saved', document.id);
  }

  Future<void> logAudit(String action, String recordId) async {
    await _writeAuditToClinic(_activeClinicId, action, recordId);
  }

  Future<void> _writeAuditToClinic(
    String clinicId,
    String action,
    String recordId,
  ) async {
    final document = _db
        .collection('clinics')
        .doc(clinicId)
        .collection(pathAuditLogs)
        .doc();
    await _queueWrite(
      document.set({
        'action': action,
        'record_id': recordId,
        'actor_id': FirebaseAuth.instance.currentUser?.uid ?? '',
        'created_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  //---------------------------

  // Fetch Collection with State Management
  Future<UserModel?> fetchUser(String id) async {
    _isLoading = true;
    notifyListeners();
    debugPrint('Fetch user ID: $id');
    try {
      return await getDocument(
        path: pathUser,
        id: id,
        builder: (data, documentId) => UserModel.fromMap(data, documentId),
      );
    } catch (e, stacktrace) {
      debugPrint(stacktrace.toString());
      debugPrint('Error fetching users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  // Fetch Collection with State Management
  Future<void> fetchAllUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _users = await getCollection(
        path: pathUser,
        builder: (data, documentId) => UserModel.fromMap(data, documentId),
      );
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new User
  Future<void> addUser(UserModel user) async {
    try {
      await setSpecificDocument(
        path: pathUser,
        docId: user.id,
        data: user.toMap(),
      );
      // await _db.collection(pathUser).add(user.toMap());
      //await fetchUsers(); // Refresh data after adding a new user
    } catch (e) {
      debugPrint('Error adding user: $e');
    }
  }

  // Update a User
  Future<void> updateUser(String id, UserModel user) async {
    try {
      await updateDocument(path: pathUser, id: id, data: user.toMap());
      //await fetchUsers(); // Refresh data after updating a user
    } catch (e) {
      debugPrint('Error updating user: $e');
    }
  }

  Future<void> updateUserRole(String id, String role) async {
    return updateUserClinicRole(id, _activeClinicId, role);
  }

  Future<void> updateUserClinicRole(
    String id,
    String clinicId,
    String role,
  ) async {
    return updateUserClinicRoles(id, clinicId, [AppRole.fromValue(role)]);
  }

  Future<void> updateUserClinicRoles(
    String id,
    String clinicId,
    List<AppRole> roles,
  ) async {
    if (roles.isEmpty) throw StateError('Select at least one role.');
    final orderedRoles = roles.toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final values = orderedRoles.map((role) => role.storageValue).toList();
    await _queueWrite(
      _db.collection(pathUser).doc(id).update({
        'clinic_roles.$clinicId': values.first,
        'clinic_role_lists.$clinicId': values,
        'clinic_ids': FieldValue.arrayUnion([clinicId]),
        'status': 'approved',
        'updated_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> updateMemberDetails(
    String id, {
    required String name,
    required String phone,
  }) => _queueWrite(
    _db.collection(pathUser).doc(id).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'updated_at': FieldValue.serverTimestamp(),
    }),
  );

  Future<void> removeUserFromClinic(String id, String clinicId) async {
    final snapshot = await _db.collection(pathUser).doc(id).get();
    final remainingClinics =
        (snapshot.data()?['clinic_ids'] as Iterable? ?? const [])
            .map((value) => value.toString())
            .where((value) => value != clinicId)
            .toList();
    await _queueWrite(
      _db.collection(pathUser).doc(id).update({
        'clinic_ids': FieldValue.arrayRemove([clinicId]),
        'clinic_roles.$clinicId': FieldValue.delete(),
        'clinic_role_lists.$clinicId': FieldValue.delete(),
        'active_clinic_id': remainingClinics.isEmpty
            ? ''
            : remainingClinics.first,
        'updated_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> approveUser(String id) => _queueWrite(
    _db.collection(pathUser).doc(id).update({
      'status': 'approved',
      'updated_at': FieldValue.serverTimestamp(),
    }),
  );

  Future<void> approveUserForClinic(String id, String clinicId, AppRole role) =>
      _queueWrite(
        _db.collection(pathUser).doc(id).update({
          'role': role.storageValue,
          'clinic_ids': FieldValue.arrayUnion([clinicId]),
          'clinic_roles.$clinicId': role.storageValue,
          'clinic_role_lists.$clinicId': [role.storageValue],
          'active_clinic_id': clinicId,
          'status': 'approved',
          'approved_by': FirebaseAuth.instance.currentUser?.uid ?? '',
          'approved_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }),
      );

  // Delete a User
  Future<void> deleteUser(String id) async {
    try {
      await deleteDocument(path: pathUser, id: id);
      //await fetchUsers(); // Refresh data after deleting a user
    } catch (e) {
      debugPrint('Error deleting user: $e');
    }
  }

  // Listen to Firestore Changes in Real-Time (Optional)
  Stream<List<UserModel>> streamUsers({bool allClinics = false}) {
    final query = allClinics
        ? _db.collection(pathUser)
        : _db
              .collection(pathUser)
              .where('clinic_ids', arrayContains: _activeClinicId);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList(),
    );
    /*return _db.collection(pathUser).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });*/
  }

  //---------------------------

  // Fetch data from a collection
  Future<List<T>> getCollection<T>({
    required String path,
    required T Function(Map<String, dynamic> data, String documentId) builder,
  }) async {
    final snapshot = await _collection(path).get();
    return snapshot.docs.map((doc) => builder(doc.data(), doc.id)).toList();
  }

  // Fetch a single document by ID
  Future<T?> getDocument<T>({
    required String path,
    required String id,
    required T Function(Map<String, dynamic> data, String documentId) builder,
  }) async {
    final doc = await _collection(path).doc(id).get();
    return doc.exists ? builder(doc.data()!, doc.id) : null;
  }

  Future<void> setSpecificDocument({
    required String path,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _collection(path).doc(docId).set(data);
  }

  // Add a new document
  Future<void> addDocument({
    required String path,
    required Map<String, dynamic> data,
  }) async {
    await _collection(path).add(data);
  }

  // Update a document by ID
  Future<void> updateDocument({
    required String path,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await _collection(path).doc(id).update(data);
  }

  // Delete a document by ID
  Future<void> deleteDocument({
    required String path,
    required String id,
  }) async {
    await _collection(path).doc(id).delete();
  }

  // Get a real-time stream of collection updates
  Stream<List<T>> collectionStream<T>({
    required String path,
    required T Function(Map<String, dynamic> data, String documentId) builder,
  }) {
    return _collection(path).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => builder(doc.data(), doc.id)).toList();
    });
  }

  // Get a real-time stream of document updates
  Stream<T?> documentStream<T>({
    required String path,
    required String id,
    required T Function(Map<String, dynamic> data, String documentId) builder,
  }) {
    return _collection(path).doc(id).snapshots().map((snapshot) {
      return snapshot.exists
          ? builder(snapshot.data() as Map<String, dynamic>, snapshot.id)
          : null;
    });
  }
}
