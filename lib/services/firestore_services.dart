import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../data/datasources/stock_model.dart';
import '../data/datasources/clinical_models.dart';
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
        createdAt: Timestamp.now(),
      ),
    );
  }

  //---------------------------
  Future<void> deleteStock(String stockDocumentId) async {
    try {
      await deleteDocument(path: pathStock, id: stockDocumentId);
    } catch (e) {
      print('Error deleting stock: $e');
    }
  }

  Future<void> addNewStock(
    StockModel stock,
    Function successCallback,
    Function errorCallback,
  ) async {
    try {
      final docRef = _db
          .collection(pathStock)
          .withConverter(
            fromFirestore: StockModel.fromFirestore,
            toFirestore: (StockModel stockModel, options) =>
                stockModel.toFirestore(),
          );
      await docRef.add(stock);
      successCallback();
    } catch (e) {
      print('Error adding stock: $e');
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
      final docRef = _db.collection(pathStock).doc(documentId);
      /*.withConverter(
        fromFirestore: StockModel.fromFirestore,
        toFirestore: (StockModel stockModel, options) => stockModel.toFirestore(),
      );*/
      await docRef.update(stock.toFirestore());
      successCallback();
      //await docRef.add(stock);
    } catch (e) {
      print('Error adding stock: $e');
      errorCallback(e);
    }
  }

  //---------------------------

  Stream<List<InventoryItem>> streamInventory() {
    return _db.collection(pathStock).snapshots().map((snapshot) {
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
      final document = _db.collection(pathStock).doc();
      await _queueWrite(document.set(data));
      return;
    }
    await _queueWrite(
      _db
          .collection(pathStock)
          .doc(item.id)
          .set(data, SetOptions(merge: true)),
    );
  }

  Future<void> adjustInventory(String id, double adjustment) async {
    final reference = _db.collection(pathStock).doc(id);
    await _queueWrite(
      reference.update({
        if (adjustment > 0) 'quantity_in': FieldValue.increment(adjustment),
        'remaining_quantity': FieldValue.increment(adjustment),
        'updated_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> removeInventoryItem(String id) =>
      _queueWrite(_db.collection(pathStock).doc(id).delete());

  Stream<List<PrescriptionModel>> streamPrescriptions() {
    return _db.collection(pathPrescriptions).snapshots().map((snapshot) {
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
    return _db.collection(pathPatients).snapshots().map((snapshot) {
      final patients = snapshot.docs
          .map((doc) => PatientModel.fromMap(doc.data(), doc.id))
          .toList();
      patients.sort((a, b) => a.fullName.compareTo(b.fullName));
      return patients;
    });
  }

  Future<String> savePrescription(PrescriptionModel prescription) async {
    final patientReference = prescription.patient.id.isEmpty
        ? _db.collection(pathPatients).doc()
        : _db.collection(pathPatients).doc(prescription.patient.id);
    final prescriptionReference = prescription.id.isEmpty
        ? _db.collection(pathPrescriptions).doc()
        : _db.collection(pathPrescriptions).doc(prescription.id);
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
      _db.collection(pathPrescriptions).doc(id).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> removePrescription(String id) =>
      _queueWrite(_db.collection(pathPrescriptions).doc(id).delete());

  Stream<List<AppointmentModel>> streamAppointments() {
    return _db.collection(pathAppointments).snapshots().map((snapshot) {
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
      final document = _db.collection(pathAppointments).doc();
      await _queueWrite(document.set(data));
      return;
    }
    await _queueWrite(
      _db
          .collection(pathAppointments)
          .doc(appointment.id)
          .set(data, SetOptions(merge: true)),
    );
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    await _queueWrite(
      _db.collection(pathAppointments).doc(id).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> removeAppointment(String id) =>
      _queueWrite(_db.collection(pathAppointments).doc(id).delete());

  Stream<List<FinanceEntry>> streamFinanceEntries() {
    return _db.collection(pathFinance).snapshots().map((snapshot) {
      final entries = snapshot.docs
          .map((doc) => FinanceEntry.fromMap(doc.data(), doc.id))
          .toList();
      entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return entries;
    });
  }

  Future<void> saveFinanceEntry(FinanceEntry entry) async {
    final document = entry.id.isEmpty
        ? _db.collection(pathFinance).doc()
        : _db.collection(pathFinance).doc(entry.id);
    await _queueWrite(document.set(entry.toMap(), SetOptions(merge: true)));
  }

  Future<void> removeFinanceEntry(String id) =>
      _queueWrite(_db.collection(pathFinance).doc(id).delete());

  //---------------------------

  // Fetch Collection with State Management
  Future<UserModel?> fetchUser(String id) async {
    _isLoading = true;
    notifyListeners();
    print('Fetch user ID: $id');
    try {
      return await getDocument(
        path: pathUser,
        id: id,
        builder: (data, documentId) => UserModel.fromMap(data, documentId),
      );
    } catch (e, stacktrace) {
      print(stacktrace.toString());
      print('Error fetching users: $e');
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
      print('Error fetching users: $e');
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
      print('Error adding user: $e');
    }
  }

  // Update a User
  Future<void> updateUser(String id, UserModel user) async {
    try {
      await updateDocument(path: pathUser, id: id, data: user.toMap());
      //await fetchUsers(); // Refresh data after updating a user
    } catch (e) {
      print('Error updating user: $e');
    }
  }

  Future<void> updateUserRole(String id, String role) async {
    await _queueWrite(
      _db.collection(pathUser).doc(id).set({
        'role': role,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  // Delete a User
  Future<void> deleteUser(String id) async {
    try {
      await deleteDocument(path: pathUser, id: id);
      //await fetchUsers(); // Refresh data after deleting a user
    } catch (e) {
      print('Error deleting user: $e');
    }
  }

  // Listen to Firestore Changes in Real-Time (Optional)
  Stream<List<UserModel>> streamUsers() {
    return collectionStream(
      path: pathUser,
      builder: (data, documentId) => UserModel.fromMap(data, documentId),
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
    final snapshot = await _db.collection(path).get();
    return snapshot.docs
        .map((doc) => builder(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // Fetch a single document by ID
  Future<T?> getDocument<T>({
    required String path,
    required String id,
    required T Function(Map<String, dynamic> data, String documentId) builder,
  }) async {
    final doc = await _db.collection(path).doc(id).get();
    return doc.exists
        ? builder(doc.data() as Map<String, dynamic>, doc.id)
        : null;
  }

  Future<void> setSpecificDocument({
    required String path,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection(path).doc(docId).set(data);
  }

  // Add a new document
  Future<void> addDocument({
    required String path,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection(path).add(data);
  }

  // Update a document by ID
  Future<void> updateDocument({
    required String path,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection(path).doc(id).update(data);
  }

  // Delete a document by ID
  Future<void> deleteDocument({
    required String path,
    required String id,
  }) async {
    await _db.collection(path).doc(id).delete();
  }

  // Get a real-time stream of collection updates
  Stream<List<T>> collectionStream<T>({
    required String path,
    required T Function(Map<String, dynamic> data, String documentId) builder,
  }) {
    return _db.collection(path).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => builder(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  // Get a real-time stream of document updates
  Stream<T?> documentStream<T>({
    required String path,
    required String id,
    required T Function(Map<String, dynamic> data, String documentId) builder,
  }) {
    return _db.collection(path).doc(id).snapshots().map((snapshot) {
      return snapshot.exists
          ? builder(snapshot.data() as Map<String, dynamic>, snapshot.id)
          : null;
    });
  }
}
