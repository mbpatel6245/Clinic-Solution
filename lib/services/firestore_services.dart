import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../core/auth/app_role.dart';
import '../data/datasources/stock_model.dart';
import '../data/datasources/clinical_models.dart';
import '../data/datasources/enterprise_models.dart';
import '../data/datasources/user_model.dart';
import 'auth_services.dart';

class FirebaseFireStore with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
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
  ) async {
    UserCredential userCredential = await _authService
        .createUserWithEmailAndPassword(email, password);

    await addUser(
      UserModel(
        id: userCredential.user?.uid ?? "",
        name: name,
        email: email,
        phone: phone,
        role: role,
        activeClinicId: 'default-clinic',
        clinicIds: const ['default-clinic'],
        clinicRoles: {'default-clinic': role},
        createdAt: Timestamp.now(),
      ),
    );
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

  Future<String> savePrescription(PrescriptionModel prescription) async {
    final patientReference = prescription.patient.id.isEmpty
        ? _collection(pathPatients).doc()
        : _collection(pathPatients).doc(prescription.patient.id);
    final prescriptionReference = prescription.id.isEmpty
        ? _collection(pathPrescriptions).doc()
        : _collection(pathPrescriptions).doc(prescription.id);
    final batch = _db.batch();
    batch.set(
      patientReference,
      prescription.patient.toMap(),
      SetOptions(merge: true),
    );
    batch.set(
      prescriptionReference,
      prescription.toMap(patientReference.id),
      SetOptions(merge: true),
    );
    await _queueWrite(batch.commit());
    return prescriptionReference.id;
  }

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
    return streamAppointments().map(
      (items) => items.where((item) => item.createdBy == userId).toList(),
    );
  }

  Future<void> saveAppointment(AppointmentModel appointment) async {
    final data = appointment.toMap();
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
    var users = await _db
        .collection(pathUser)
        .where('email_normalized', isEqualTo: invitation.email.toLowerCase())
        .limit(1)
        .get();
    if (users.docs.isEmpty) {
      users = await _db
          .collection(pathUser)
          .where('email', isEqualTo: invitation.email)
          .limit(1)
          .get();
    }
    if (users.docs.isEmpty) {
      throw StateError(
        'The invited person must register with ${invitation.email} before approval.',
      );
    }
    final batch = _db.batch();
    batch.set(users.docs.first.reference, {
      'clinic_ids': FieldValue.arrayUnion([clinicId]),
      'clinic_roles.$clinicId': invitation.role.storageValue,
      'status': 'approved',
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.update(
      _db
          .collection('clinics')
          .doc(clinicId)
          .collection(pathTeamInvites)
          .doc(invitation.id),
      {
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': FirebaseAuth.instance.currentUser?.uid ?? '',
      },
    );
    await _queueWrite(batch.commit());
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

  Future<String> createClinic(String name) async {
    final document = _db.collection('clinics').doc();
    await saveClinic(
      ClinicProfile(
        id: document.id,
        name: name,
        enabledModules: ClinicProfile.defaultModules,
      ),
    );
    return document.id;
  }

  Future<void> inviteTeamMember(
    String email,
    AppRole role, {
    String? clinicId,
  }) async {
    final targetClinicId = clinicId ?? _activeClinicId;
    final document = _db
        .collection('clinics')
        .doc(targetClinicId)
        .collection(pathTeamInvites)
        .doc();
    await _queueWrite(
      document.set({
        'email': email.trim().toLowerCase(),
        'role': role.storageValue,
        'status': 'pending',
        'invited_by': FirebaseAuth.instance.currentUser?.uid ?? '',
        'created_at': FieldValue.serverTimestamp(),
      }),
    );
    await _writeAuditToClinic(targetClinicId, 'team.invited', document.id);
  }

  Future<void> saveClinic(ClinicProfile clinic) async {
    await _queueWrite(
      _db
          .collection('clinics')
          .doc(clinic.id)
          .set(clinic.toMap(), SetOptions(merge: true)),
    );
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
    await _queueWrite(
      _db.collection(pathUser).doc(id).set({
        'clinic_roles.$clinicId': role,
        'clinic_ids': FieldValue.arrayUnion([clinicId]),
        'status': 'approved',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  Future<void> approveUser(String id) => _queueWrite(
    _db.collection(pathUser).doc(id).update({
      'status': 'approved',
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
