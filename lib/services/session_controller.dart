import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/app_role.dart';
import '../data/datasources/enterprise_models.dart';

class SessionController extends ChangeNotifier {
  SessionController({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _authSubscription = _auth.authStateChanges().listen(_loadUser);
  }

  static const _roleKey = 'SESSION_ROLE';
  static const _nameKey = 'SESSION_NAME';
  static const _clinicKey = 'SESSION_CLINIC';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _clinicSubscription;

  AppRole _role = AppRole.doctor;
  String _displayName = '';
  String _activeClinicId = 'default-clinic';
  String _clinicName = 'Clinic';
  Set<ClinicModule> _enabledModules = ClinicProfile.defaultModules;
  List<String> _clinicIds = const ['default-clinic'];
  bool _loading = true;

  AppRole get role => _role;
  String get displayName => _displayName;
  String get activeClinicId => _activeClinicId;
  String get clinicName => _clinicName;
  Set<ClinicModule> get enabledModules => Set.unmodifiable(_enabledModules);
  List<String> get clinicIds => List.unmodifiable(_clinicIds);
  bool get isLoading => _loading;
  bool can(AppFeature feature) {
    if (!_role.can(feature)) return false;
    final module = moduleForFeature(feature);
    return module == null || _enabledModules.contains(module);
  }

  bool isAllowed(AppPermission permission) => _role.isAllowed(permission);

  Future<void> refresh() => _loadUser(_auth.currentUser);

  Future<void> _loadUser(User? user) async {
    await _profileSubscription?.cancel();
    await _clinicSubscription?.cancel();
    _loading = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    _role = AppRole.fromValue(preferences.getString(_roleKey));
    _displayName = preferences.getString(_nameKey) ?? user?.displayName ?? '';
    _activeClinicId = preferences.getString(_clinicKey) ?? 'default-clinic';

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
              _displayName = data['name']?.toString().trim().isNotEmpty == true
                  ? data['name'].toString().trim()
                  : _displayName;
              final clinicId =
                  data['active_clinic_id']?.toString().trim() ?? '';
              final clinicIds = (data['clinic_ids'] as Iterable? ?? const [])
                  .map((value) => value.toString())
                  .where((value) => value.isNotEmpty)
                  .toList();
              _clinicIds = clinicIds.isEmpty
                  ? const ['default-clinic']
                  : clinicIds;
              _activeClinicId = clinicId.isNotEmpty
                  ? clinicId
                  : clinicIds.isNotEmpty
                  ? clinicIds.first
                  : 'default-clinic';
              final clinicRoles = data['clinic_roles'];
              final clinicRole = clinicRoles is Map
                  ? clinicRoles[_activeClinicId]?.toString()
                  : null;
              _role = AppRole.fromValue(clinicRole ?? data['role']?.toString());
              await preferences.setString(_roleKey, _role.storageValue);
              await preferences.setString(_nameKey, _displayName);
              await preferences.setString(_clinicKey, _activeClinicId);
              _listenToClinic();
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

  void _listenToClinic() {
    _clinicSubscription?.cancel();
    _clinicSubscription = _firestore
        .collection('clinics')
        .doc(_activeClinicId)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          final data = snapshot.data();
          if (data == null) {
            _clinicName = 'Clinic';
            _enabledModules = ClinicProfile.defaultModules;
          } else {
            final clinic = ClinicProfile.fromMap(data, snapshot.id);
            _clinicName = clinic.name;
            _enabledModules = clinic.enabledModules;
          }
          notifyListeners();
        });
  }

  Future<void> selectClinic(String clinicId) async {
    if (clinicId.trim().isEmpty || _auth.currentUser == null) return;
    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
      'active_clinic_id': clinicId,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_roleKey);
    await preferences.remove(_nameKey);
    await preferences.remove(_clinicKey);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _clinicSubscription?.cancel();
    super.dispose();
  }
}
