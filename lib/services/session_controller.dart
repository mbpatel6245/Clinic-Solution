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
  static const allClinicsId = '__all__';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _clinicSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _platformModulesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _ownerClinicsSubscription;

  AppRole _role = AppRole.doctor;
  Set<AppRole> _roles = {AppRole.doctor};
  String _displayName = '';
  String _activeClinicId = 'default-clinic';
  String _clinicName = 'Clinic';
  String _clinicTimezone = 'Asia/Kolkata';
  Set<ClinicModule> _enabledModules = ClinicProfile.defaultModules;
  Set<ClinicModule> _clinicEnabledModules = ClinicProfile.defaultModules;
  Set<ClinicModule> _platformEnabledModules = ClinicModule.values.toSet();
  List<String> _clinicIds = const ['default-clinic'];
  Map<String, String> _clinicNames = const {};
  bool _loading = true;
  bool _mustChangePassword = false;
  bool _sharePrescriptionsWithPatients = false;
  bool _clinicalV3 = false;
  bool _clinicalArtifactsV1 = false;
  bool _shareClinicalArtifactsWithPatients = false;

  AppRole get role => _role;
  Set<AppRole> get roles => Set.unmodifiable(_roles);
  String get displayName => _displayName;
  String get activeClinicId => _activeClinicId;
  String get clinicName => _clinicName;
  String get clinicTimezone => _clinicTimezone;
  Set<ClinicModule> get enabledModules => Set.unmodifiable(_enabledModules);
  Set<ClinicModule> get platformEnabledModules =>
      Set.unmodifiable(_platformEnabledModules);
  List<String> get clinicIds => List.unmodifiable(_clinicIds);
  String clinicNameFor(String clinicId) =>
      _clinicNames[clinicId] ??
      (clinicId == allClinicsId ? 'All clinics' : clinicId);
  bool get isAllClinics =>
      _role == AppRole.platformOwner && _activeClinicId == allClinicsId;
  bool get isLoading => _loading;
  bool get mustChangePassword => _mustChangePassword;
  bool get sharePrescriptionsWithPatients => _sharePrescriptionsWithPatients;
  bool get clinicalV3 => _clinicalV3;
  bool get clinicalArtifactsV1 => _clinicalArtifactsV1;
  bool get shareClinicalArtifactsWithPatients =>
      _shareClinicalArtifactsWithPatients;
  bool can(AppFeature feature) {
    if (_role == AppRole.patient && _activeClinicId.isEmpty) {
      return feature == AppFeature.dashboard;
    }
    if (isAllClinics) {
      return feature == AppFeature.dashboard ||
          feature == AppFeature.team ||
          feature == AppFeature.clinicSetup;
    }
    if (!_roles.any((role) => role.can(feature))) return false;
    final module = moduleForFeature(feature);
    return module == null || _enabledModules.contains(module);
  }

  bool isAllowed(AppPermission permission) =>
      _roles.any((role) => role.isAllowed(permission));

  Future<void> refresh() => _loadUser(_auth.currentUser);

  Future<void> _loadUser(User? user) async {
    await _profileSubscription?.cancel();
    await _clinicSubscription?.cancel();
    await _platformModulesSubscription?.cancel();
    await _ownerClinicsSubscription?.cancel();
    _loading = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    _role = AppRole.fromValue(preferences.getString(_roleKey));
    _roles = {_role};
    _displayName = preferences.getString(_nameKey) ?? user?.displayName ?? '';
    _activeClinicId = preferences.getString(_clinicKey) ?? 'default-clinic';

    if (user == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    // Render the last verified clinic workspace immediately on repeat visits;
    // the live profile listener below remains the source of truth.
    if (preferences.containsKey(_roleKey)) {
      _loading = false;
      notifyListeners();
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
              final clinicRoleLists = data['clinic_role_lists'];
              final storedRoles = clinicRoleLists is Map
                  ? clinicRoleLists[_activeClinicId]
                  : null;
              final globalRole = AppRole.fromValue(data['role']?.toString());
              _mustChangePassword = data['must_change_password'] == true;
              _role = globalRole == AppRole.platformOwner
                  ? globalRole
                  : AppRole.fromValue(clinicRole ?? data['role']?.toString());
              _roles = globalRole == AppRole.platformOwner
                  ? {AppRole.platformOwner}
                  : (storedRoles is Iterable
                        ? storedRoles
                              .map(
                                (value) => AppRole.fromValue(value.toString()),
                              )
                              .toSet()
                        : <AppRole>{_role});
              if (_roles.isEmpty) _roles = {_role};
              if (_role == AppRole.patient && clinicIds.isEmpty) {
                _clinicIds = const [];
                _activeClinicId = '';
              }
              if (_role == AppRole.platformOwner && clinicId.isEmpty) {
                _activeClinicId = allClinicsId;
              }
              _listenToPlatformModules();
              _listenToOwnerClinics();
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
    if (_activeClinicId.isEmpty) {
      _clinicName = 'Choose a clinic';
      _clinicEnabledModules = ClinicModule.values.toSet();
      _refreshEffectiveModules();
      notifyListeners();
      return;
    }
    if (_activeClinicId == allClinicsId) {
      _clinicName = 'All clinics';
      _sharePrescriptionsWithPatients = false;
      _clinicalV3 = false;
      _clinicalArtifactsV1 = false;
      _shareClinicalArtifactsWithPatients = false;
      _clinicEnabledModules = ClinicModule.values.toSet();
      _refreshEffectiveModules();
      notifyListeners();
      return;
    }
    _clinicSubscription = _firestore
        .collection('clinics')
        .doc(_activeClinicId)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          final data = snapshot.data();
          if (data == null) {
            _clinicName = 'Clinic';
            _clinicTimezone = 'Asia/Kolkata';
            _clinicEnabledModules = ClinicProfile.defaultModules;
            _sharePrescriptionsWithPatients = false;
            _clinicalV3 = false;
            _clinicalArtifactsV1 = false;
            _shareClinicalArtifactsWithPatients = false;
          } else {
            final clinic = ClinicProfile.fromMap(data, snapshot.id);
            _clinicalV3 = clinic.clinicalV3;
            _clinicalArtifactsV1 = clinic.clinicalArtifactsV1;
            _shareClinicalArtifactsWithPatients =
                clinic.shareClinicalArtifactsWithPatients;
            _clinicName = clinic.name;
            _clinicTimezone = clinic.timezone;
            _clinicNames = {..._clinicNames, snapshot.id: clinic.name};
            _clinicEnabledModules = clinic.enabledModules;
            _sharePrescriptionsWithPatients =
                clinic.sharePrescriptionsWithPatients;
          }
          _refreshEffectiveModules();
          notifyListeners();
        });
  }

  void _listenToPlatformModules() {
    _platformModulesSubscription?.cancel();
    _platformModulesSubscription = _firestore
        .collection('platform_settings')
        .doc('modules')
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          _platformEnabledModules = PlatformModuleSettings.fromMap(
            snapshot.data() ?? const {},
          ).enabledModules;
          _refreshEffectiveModules();
          notifyListeners();
        });
  }

  void _listenToOwnerClinics() {
    _ownerClinicsSubscription?.cancel();
    if (_role != AppRole.platformOwner) return;
    _ownerClinicsSubscription = _firestore
        .collection('clinics')
        .snapshots()
        .listen((snapshot) {
          _clinicIds = snapshot.docs.map((doc) => doc.id).toList()..sort();
          _clinicNames = {
            for (final doc in snapshot.docs)
              doc.id: doc.data()['name']?.toString() ?? doc.id,
          };
          if (_activeClinicId != allClinicsId &&
              !_clinicIds.contains(_activeClinicId)) {
            unawaited(showAllClinics());
          }
          notifyListeners();
        });
  }

  void _refreshEffectiveModules() {
    _enabledModules = _clinicEnabledModules.intersection(
      _platformEnabledModules,
    );
  }

  Future<void> selectClinic(String clinicId) async {
    if (clinicId.trim().isEmpty || _auth.currentUser == null) return;
    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
      'active_clinic_id': clinicId,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> showAllClinics() async {
    if (_role != AppRole.platformOwner || _auth.currentUser == null) return;
    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
      'active_clinic_id': allClinicsId,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_roleKey);
    await preferences.remove(_nameKey);
    await preferences.remove(_clinicKey);
  }

  Future<void> markPasswordChanged() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'must_change_password': false,
      'updated_at': FieldValue.serverTimestamp(),
    });
    _mustChangePassword = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _clinicSubscription?.cancel();
    _platformModulesSubscription?.cancel();
    _ownerClinicsSubscription?.cancel();
    super.dispose();
  }
}
