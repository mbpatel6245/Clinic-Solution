import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum ClinicSyncState { checking, synced, pending, offline }

class SyncStatusService extends ChangeNotifier {
  SyncStatusService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance {
    _authSubscription = _auth.authStateChanges().listen(_watchUser);
    _watchUser(_auth.currentUser);
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  ClinicSyncState _state = ClinicSyncState.checking;
  DateTime? _lastSyncedAt;

  ClinicSyncState get state => _state;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isOffline => _state == ClinicSyncState.offline;

  void _watchUser(User? user) {
    _subscription?.cancel();
    _state = ClinicSyncState.checking;
    if (user == null) {
      notifyListeners();
      return;
    }
    _subscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (snapshot.metadata.isFromCache) {
              _state = ClinicSyncState.offline;
            } else if (snapshot.metadata.hasPendingWrites) {
              _state = ClinicSyncState.pending;
            } else {
              _state = ClinicSyncState.synced;
              _lastSyncedAt = DateTime.now();
            }
            notifyListeners();
          },
          onError: (_) {
            _state = ClinicSyncState.offline;
            notifyListeners();
          },
        );
  }

  Future<void> syncNow() async {
    try {
      await _firestore.waitForPendingWrites().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Queued writes remain in Firestore's local cache until connectivity returns.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
