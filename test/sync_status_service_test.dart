// Test doubles model Firestore metadata without contacting the live backend.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:clinic_solution/services/sync_status_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_test/flutter_test.dart';

class TestUser extends Fake implements User {
  TestUser(this.uid);
  @override
  final String uid;
}

class TestAuth extends Fake implements FirebaseAuth {
  final events = StreamController<User?>.broadcast(sync: true);
  @override
  User? get currentUser => TestUser('member');
  @override
  Stream<User?> authStateChanges() => events.stream;
}

class TestMetadata extends Fake implements SnapshotMetadata {
  TestMetadata(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

class TestSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  TestSnapshot({bool cached = false, bool pending = false})
    : metadata = TestMetadata(cached, pending);
  @override
  final SnapshotMetadata metadata;
}

class TestDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final events =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
        sync: true,
      );
  final _watches = <bool>[];
  int get watches => _watches.length;
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    _watches.add(true);
    return events.stream;
  }
}

class TestCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  TestCollection(this.document);
  final TestDocument document;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => document;
}

class TestFirestore extends Fake implements FirebaseFirestore {
  final document = TestDocument();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      TestCollection(document);
}

void main() {
  late TestAuth auth;
  late TestFirestore firestore;
  SyncStatusService create(Future<void> Function(String) probe) {
    auth = TestAuth();
    firestore = TestFirestore();
    final service = SyncStatusService(
      auth: auth,
      firestore: firestore,
      serverProbe: probe,
    );
    addTearDown(() async {
      service.dispose();
      await auth.events.close();
      await firestore.document.events.close();
    });
    return service;
  }

  testWidgets(
    'transient cached snapshots and duplicate login events do not flicker',
    (tester) async {
      final service = create((_) async {});
      var notifications = 0;
      service.addListener(() => notifications++);
      firestore.document.events.add(TestSnapshot(cached: true));
      await tester.pump(const Duration(seconds: 1));
      expect(service.state, ClinicSyncState.checking);
      firestore.document.events.add(TestSnapshot());
      expect(service.state, ClinicSyncState.synced);
      auth.events.add(TestUser('member'));
      expect(firestore.document.watches, 1);
      firestore.document.events.add(TestSnapshot(cached: true));
      await tester.pump(const Duration(seconds: 1));
      firestore.document.events.add(TestSnapshot());
      await tester.pump(const Duration(seconds: 4));
      expect(service.state, ClinicSyncState.synced);
      expect(notifications, 1);
    },
  );

  testWidgets(
    'offline requires a failed server check and recovers on server data',
    (tester) async {
      final service = create(
        (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      firestore.document.events.add(TestSnapshot(cached: true));
      await tester.pump(const Duration(seconds: 2));
      expect(service.state, ClinicSyncState.checking);
      await tester.pump(const Duration(seconds: 1));
      expect(service.state, ClinicSyncState.offline);
      firestore.document.events.add(TestSnapshot());
      expect(service.state, ClinicSyncState.synced);
    },
  );

  testWidgets(
    'reachable server keeps cached pending writes visible as pending',
    (tester) async {
      final service = create((_) async {});
      firestore.document.events.add(TestSnapshot(cached: true, pending: true));
      expect(service.state, ClinicSyncState.pending);
      await tester.pump(const Duration(seconds: 3));
      expect(service.state, ClinicSyncState.pending);
      firestore.document.events.add(TestSnapshot());
      expect(service.state, ClinicSyncState.synced);
    },
  );

  testWidgets('late probe failures cannot undo a newer recovery snapshot', (
    tester,
  ) async {
    final completer = Completer<void>();
    final service = create((_) => completer.future);
    firestore.document.events.add(TestSnapshot(cached: true));
    await tester.pump(const Duration(seconds: 3));
    firestore.document.events.add(TestSnapshot());
    completer.completeError(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );
    await tester.pump();
    expect(service.state, ClinicSyncState.synced);
  });

  testWidgets('permission errors do not falsely report offline', (
    tester,
  ) async {
    final service = create(
      (_) async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    );
    firestore.document.events.add(TestSnapshot(cached: true));
    await tester.pump(const Duration(seconds: 3));
    expect(service.state, ClinicSyncState.checking);
  });

  testWidgets(
    'sign out cancels pending checks and resets the old account state',
    (tester) async {
      final completer = Completer<void>();
      final service = create((_) => completer.future);
      firestore.document.events.add(TestSnapshot(cached: true));
      await tester.pump(const Duration(seconds: 3));
      auth.events.add(null);
      completer.complete();
      await tester.pump();
      expect(service.state, ClinicSyncState.checking);
      expect(service.lastSyncedAt, isNull);
    },
  );
}
