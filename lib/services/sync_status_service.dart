import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum ClinicSyncState { checking, synced, pending, offline }

class SyncStatusService extends ChangeNotifier {
  SyncStatusService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.offlineDelay = const Duration(seconds: 3),
    Future<void> Function(String uid)? serverProbe,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _serverProbe = serverProbe {
    _authSubscription = _auth.authStateChanges().listen(_watchUser);
    _watchUser(_auth.currentUser);
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Duration offlineDelay;
  final Future<void> Function(String uid)? _serverProbe;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _offlineTimer;
  String? _watchedUid;
  bool _watchStarted = false;
  bool _disposed = false;
  bool _hasPendingWrites = false;
  bool _probeInFlight = false;
  int _generation = 0;
  ClinicSyncState _state = ClinicSyncState.checking;
  DateTime? _lastSyncedAt;

  ClinicSyncState get state => _state;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isOffline => _state == ClinicSyncState.offline;

  void _setState(ClinicSyncState value) {
    if (_disposed || value == _state) return;
    _state = value;
    notifyListeners();
  }

  void _watchUser(User? user) {
    if (_disposed || (_watchStarted && user?.uid == _watchedUid)) return;
    _watchStarted = true;
    _watchedUid = user?.uid;
    final generation = ++_generation;
    _subscription?.cancel();
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _probeInFlight = false;
    _hasPendingWrites = false;
    _lastSyncedAt = null;
    _setState(ClinicSyncState.checking);
    if (user == null) return;
    _subscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (_disposed || generation != _generation) return;
            _hasPendingWrites = snapshot.metadata.hasPendingWrites;
            if (snapshot.metadata.isFromCache) {
              // Cache is a source of data, not proof that the device is offline.
              if (_hasPendingWrites && _state != ClinicSyncState.offline) {
                _setState(ClinicSyncState.pending);
              }
              _scheduleServerCheck(generation, user.uid);
            } else {
              // Invalidate an earlier probe so its delayed failure cannot undo recovery.
              _offlineTimer?.cancel();
              _offlineTimer = null;
              _probeRevision++;
              if (!_hasPendingWrites) _lastSyncedAt = DateTime.now();
              _setState(
                _hasPendingWrites
                    ? ClinicSyncState.pending
                    : ClinicSyncState.synced,
              );
            }
          },
          onError: (Object error) {
            if (!_disposed && generation == _generation) {
              _scheduleServerCheck(generation, user.uid);
            }
          },
        );
  }

  int _probeRevision = 0;

  void _scheduleServerCheck(int generation, String uid) {
    if (_offlineTimer != null || _probeInFlight) return;
    _offlineTimer = Timer(offlineDelay, () {
      _offlineTimer = null;
      unawaited(_checkServer(generation, uid));
    });
  }

  Future<void> _checkServer(int generation, String uid) async {
    final revision = _probeRevision;
    _probeInFlight = true;
    bool current() =>
        !_disposed && generation == _generation && revision == _probeRevision;
    try {
      if (_serverProbe != null) {
        await _serverProbe(uid).timeout(const Duration(seconds: 5));
      } else {
        await _firestore
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
      }
      if (current()) {
        if (!_hasPendingWrites) _lastSyncedAt = DateTime.now();
        _setState(
          _hasPendingWrites ? ClinicSyncState.pending : ClinicSyncState.synced,
        );
      }
    } on TimeoutException {
      if (current()) _setState(ClinicSyncState.offline);
    } on FirebaseException catch (error) {
      if (current() &&
          [
            'unavailable',
            'deadline-exceeded',
            'network-request-failed',
          ].contains(error.code)) {
        _setState(ClinicSyncState.offline);
      }
      // Permission/configuration errors do not establish a network outage.
    } finally {
      if (!_disposed && generation == _generation) _probeInFlight = false;
    }
  }

  Future<void> syncNow() async {
    try {
      await _firestore.waitForPendingWrites().timeout(
        const Duration(seconds: 8),
      );
    } on TimeoutException {
      // Queued writes remain in Firestore's local cache until connectivity returns.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _offlineTimer?.cancel();
    _authSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
