import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../data/datasources/stock_model.dart';
import '../data/datasources/user_model.dart';
import 'auth_services.dart';

class FirebaseFireStore with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  bool _isLoading = true;

  static const String pathUser = "users";
  static const String pathStock = "stocks";

  bool get isLoading => _isLoading;
  List<UserModel> _users = [];

  List<UserModel> get users => _users;

  Future<void> registerUserData(String email, String password, String name,
      String phone, String role) async {
    UserCredential userCredential =
        await _authService.createUserWithEmailAndPassword(email, password);

    await addUser(UserModel(
        id: userCredential.user?.uid ?? "",
        name: name,
        email: email,
        password: password,
        phone: phone,
        role: role,
        createdAt: Timestamp.now()));
  }

  //---------------------------
  Future<void> deleteStock(String stockDocumentId) async {
    try {
      deleteDocument(path: pathStock, id: stockDocumentId);
    } catch (e) {
      print('Error deleting stock: $e');
    }
  }

  Future<void> addNewStock(StockModel stock, Function successCallback,
      Function errorCallback) async {
    try {
      final docRef = _db.collection(pathStock).withConverter(
            fromFirestore: StockModel.fromFirestore,
            toFirestore: (StockModel stockModel, options) =>
                stockModel.toFirestore(),
          );
      await docRef
          .add(stock)
          .then((onValue) => successCallback(), onError: (e) => errorCallback);
    } catch (e) {
      print('Error adding stock: $e');
    }
  }

  Future<void> updateStock(StockModel stock, String documentId,
      Function successCallback, Function errorCallback) async {
    try {
      final docRef = _db.collection(pathStock).doc(documentId);
      /*.withConverter(
        fromFirestore: StockModel.fromFirestore,
        toFirestore: (StockModel stockModel, options) => stockModel.toFirestore(),
      );*/
      await docRef
          .update(stock.toFirestore())
          .then((onValue) => successCallback(), onError: (e) => errorCallback);
      //await docRef.add(stock);
    } catch (e) {
      print('Error adding stock: $e');
    }
  }

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
      setSpecificDocument(path: pathUser, docId: user.id, data: user.toMap());
      // await _db.collection(pathUser).add(user.toMap());
      //await fetchUsers(); // Refresh data after adding a new user
    } catch (e) {
      print('Error adding user: $e');
    }
  }

  // Update a User
  Future<void> updateUser(String id, UserModel user) async {
    try {
      updateDocument(path: pathUser, id: id, data: user.toMap());
      //await fetchUsers(); // Refresh data after updating a user
    } catch (e) {
      print('Error updating user: $e');
    }
  }

  // Delete a User
  Future<void> deleteUser(String id) async {
    try {
      deleteDocument(path: pathUser, id: id);
      //await fetchUsers(); // Refresh data after deleting a user
    } catch (e) {
      print('Error deleting user: $e');
    }
  }

  // Listen to Firestore Changes in Real-Time (Optional)
  Stream<List<UserModel>> streamUsers() {
    return collectionStream(
        path: pathUser,
        builder: (data, documentId) => UserModel.fromMap(data, documentId));
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
