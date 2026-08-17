import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/app_role.dart';

class SessionController extends ChangeNotifier {
  SessionController({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _authSubscription = _auth.authStateChanges().listen(_loadUser);
  }

  static const _roleKey = 'SESSION_ROLE';
  static const _nameKey = 'SESSION_NAME';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  AppRole _role = AppRole.doctor;
  String _displayName = '';
  bool _loading = true;

  AppRole get role => _role;
  String get displayName => _displayName;
  bool get isLoading => _loading;
  bool can(AppFeature feature) => _role.can(feature);

  Future<void> refresh() => _loadUser(_auth.currentUser);

  Future<void> _loadUser(User? user) async {
    await _profileSubscription?.cancel();
    _loading = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    _role = AppRole.fromValue(preferences.getString(_roleKey));
    _displayName = preferences.getString(_nameKey) ?? user?.displayName ?? '';

    if (user == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    _profileSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) async {
            final data = snapshot.data();
            if (data != null) {
              _role = AppRole.fromValue(data['role']?.toString());
              _displayName = data['name']?.toString().trim().isNotEmpty == true
                  ? data['name'].toString().trim()
                  : _displayName;
              await preferences.setString(_roleKey, _role.storageValue);
              await preferences.setString(_nameKey, _displayName);
            }
            _loading = false;
            notifyListeners();
          },
          onError: (_) {
            // The last known role remains available when the clinic is offline.
            _loading = false;
            notifyListeners();
          },
        );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_roleKey);
    await preferences.remove(_nameKey);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
