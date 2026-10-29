import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/core/domain/clinic_scope.dart';
import 'package:clinic_solution/core/persistence/clinic_database.dart';
import 'package:clinic_solution/core/sync/sync_contract.dart';
import 'package:clinic_solution/core/sync/sync_engine.dart';
import 'package:clinic_solution/core/sync/synthetic_sync_transport.dart';
import 'package:clinic_solution/features/patients/data/offline_patient_repository.dart';
import 'package:clinic_solution/features/patients/domain/patient_repository.dart';
import 'package:clinic_solution/features/foundation/foundation_controller.dart';

class CallbackTransport implements SyncTransport {
  CallbackTransport(this.callback);
  final Future<PushResult> Function(SyncOperation) callback;
  @override
  Future<PushResult> push(SyncOperation operation) => callback(operation);
}

void main() {
  // These tests intentionally use independent executors/files for two devices.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final scope = ClinicScope(
    projectId: 'demo-project',
    userId: 'user',
    clinicId: 'clinic',
  );
  late ClinicDatabase db, server;
  late OfflinePatientRepository repository;
  late SyntheticSyncTransport transport;
  late SyncEngine engine;
  var sequence = 0;
  String nextId() => 'op-${++sequence}';
  PatientProfile patient([String name = 'Demo']) =>
      PatientProfile(id: 'p1', firstName: name);
  OfflinePatientRepository repo(
    ClinicDatabase database, [
    ClinicScope? other,
  ]) => OfflinePatientRepository(
    database: database,
    scope: other ?? scope,
    newId: nextId,
  );
  setUp(() {
    db = ClinicDatabase(NativeDatabase.memory());
    server = ClinicDatabase(NativeDatabase.memory());
    repository = repo(db);
    transport = SyntheticSyncTransport(server);
    engine = SyncEngine(
      database: db,
      scope: scope,
      transport: transport,
      workerId: 'worker',
      jitter: (_) => 0,
    );
  });
  tearDown(() async {
    await engine.dispose();
    await db.close();
    await server.close();
  });

  test(
    'offline create and stable outbox survive an actual file reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp('uvilo-restart-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/local.sqlite');
      var disk = ClinicDatabase(NativeDatabase(file));
      final save = await repo(disk).save(patient());
      await disk.close();
      disk = ClinicDatabase(NativeDatabase(file));
      try {
        expect((await repo(disk).list()).single.patient.firstName, 'Demo');
        expect((await disk.operations(scope)).single.id, save.operationId);
        expect((await disk.operations(scope)).single.baseRevision, 0);
      } finally {
        await disk.close();
      }
    },
  );

  test(
    'offline retries preserve IDs; lost acknowledgement applies exactly once',
    () async {
      final save = await repository.save(patient());
      await engine.synchronize();
      expect((await db.operations(scope)).single.id, save.operationId);
      expect(
        (await repository.list()).single.syncState,
        RecordSyncState.pending,
      );
      transport.online = true;
      transport.loseNextAcknowledgement = true;
      await engine.synchronize(force: true);
      expect(
        (await db.operations(scope)).single.errorCode,
        'acknowledgement-lost',
      );
      await engine.synchronize(force: true);
      expect(await db.operations(scope), isEmpty);
      expect((await repository.list()).single.revision, 1);
      expect(
        (await server
                .customSelect('SELECT count(*) AS n FROM demo_receipts')
                .getSingle())
            .read<int>('n'),
        1,
      );
    },
  );

  test(
    'confirmed records support offline updates and tombstone deletion',
    () async {
      transport.online = true;
      await repository.save(patient());
      await engine.synchronize(force: true);
      transport.online = false;
      await repository.save(patient('Updated'));
      expect((await repository.list()).single.patient.firstName, 'Updated');
      expect((await db.operations(scope)).single.baseRevision, 1);
      transport.online = true;
      await engine.synchronize(force: true);
      await repository.remove('p1');
      expect(await repository.list(), isEmpty);
      expect((await db.operations(scope)).single.kind, MutationKind.delete);
      await engine.synchronize(force: true);
      final row = await server
          .customSelect('SELECT revision, payload FROM demo_remote')
          .getSingle();
      expect(row.read<int>('revision'), 3);
      expect(row.readNullable<String>('payload'), isNull);
    },
  );

  test(
    'duplicate operation ID rolls back the local write atomically',
    () async {
      final fixed = OfflinePatientRepository(
        database: db,
        scope: scope,
        newId: () => 'same-id',
      );
      await fixed.save(patient());
      await expectLater(
        fixed.save(PatientProfile(id: 'p2', firstName: 'Other')),
        throwsA(anything),
      );
      expect((await repository.list()).map((r) => r.patient.id), ['p1']);
      await expectLater(
        repository.save(patient('Overwrite')),
        throwsStateError,
      );
      expect((await repository.list()).single.patient.firstName, 'Demo');
    },
  );

  test(
    'project, account and clinic partitions isolate records and outboxes',
    () async {
      await repository.save(patient());
      for (final other in [
        ClinicScope(projectId: 'other', userId: 'user', clinicId: 'clinic'),
        ClinicScope(
          projectId: 'demo-project',
          userId: 'other',
          clinicId: 'clinic',
        ),
        ClinicScope(
          projectId: 'demo-project',
          userId: 'user',
          clinicId: 'other',
        ),
      ]) {
        expect(await repo(db, other).list(), isEmpty);
        expect(await db.operations(other), isEmpty);
        await repo(db, other).save(patient('Separate'));
      }
      expect((await repository.list()).single.patient.firstName, 'Demo');
    },
  );

  for (final keepLocal in [false, true]) {
    test(
      'conflict review ${keepLocal ? 'rebases with a fresh ID' : 'adopts server'}',
      () async {
        transport.online = true;
        await transport.push(
          SyncOperation(
            id: 'other-device',
            scope: scope,
            entityId: 'p1',
            kind: MutationKind.put,
            payload: const {'first_name': 'Server'},
            baseRevision: 0,
          ),
        );
        final save = await repository.save(patient('Local'));
        await engine.synchronize(force: true);
        final conflict = (await db.operations(scope)).single;
        expect(conflict.state, DeliveryState.conflict);
        expect(conflict.remotePayload?['first_name'], 'Server');
        await db.resolveConflict(
          conflict,
          keepLocal: keepLocal,
          newOperationId: 'reviewed',
        );
        if (keepLocal) {
          final rebased = (await db.operations(scope)).single;
          expect(rebased.id, isNot(save.operationId));
          expect(rebased.baseRevision, 1);
          await engine.synchronize(force: true);
        }
        expect(await db.operations(scope), isEmpty);
        expect(
          (await repository.list()).single.patient.firstName,
          keepLocal ? 'Local' : 'Server',
        );
        expect((await repository.list()).single.revision, keepLocal ? 2 : 1);
      },
    );
  }

  test('cursor and rows roll back together for a malformed page', () async {
    await expectLater(
      db.applyPage(
        scope,
        const ChangePage(
          cursor: 'bad',
          records: [
            RemotePatient('p1', 1, {'first_name': 'Valid'}),
            RemotePatient('bad/id', 1, null),
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(await repository.list(), isEmpty);
    expect(await db.cursor(scope), isNull);
  });

  test(
    'malformed downloaded payload cannot poison the cached directory',
    () async {
      await expectLater(
        db.applyPage(
          scope,
          const ChangePage(
            cursor: 'invalid-data',
            records: [
              RemotePatient('valid', 1, {'first_name': 'Demo'}),
              RemotePatient('invalid', 1, {'first_name': 123}),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(await repository.list(), isEmpty);
      expect(await db.cursor(scope), isNull);
    },
  );

  test(
    'pull replays skipped records after lost acknowledgement without losing newer state',
    () async {
      await repository.save(patient());
      const page = ChangePage(
        cursor: 'after-revision-2',
        records: [
          RemotePatient('p1', 2, {'first_name': 'Newer server'}),
        ],
      );
      await db.applyPage(scope, page);
      expect(await db.cursor(scope), isNull);
      expect((await repository.list()).single.patient.firstName, 'Demo');
      await db.accept((await db.operations(scope)).single, 1);
      await db.applyPage(scope, page);
      expect(await db.cursor(scope), 'after-revision-2');
      expect(
        (await repository.list()).single.patient.firstName,
        'Newer server',
      );
      await db.applyPage(
        scope,
        const ChangePage(
          cursor: 'deleted',
          records: [RemotePatient('p1', 3, null)],
        ),
      );
      expect(await repository.list(), isEmpty);
    },
  );

  test('leases exclude another worker and recover after expiry', () async {
    expect(await db.acquireLease(scope, 'one', 0), isTrue);
    expect(await db.acquireLease(scope, 'two', 1000), isFalse);
    await db.releaseLease(scope, 'two');
    expect(await db.acquireLease(scope, 'two', 2000), isFalse);
    expect(await db.acquireLease(scope, 'two', 60000), isTrue);
  });

  test(
    'transient failures back off; auth and permanent failures require explicit action',
    () async {
      var calls = 0;
      var now = DateTime.fromMillisecondsSinceEpoch(1000);
      var kind = TransportFailureKind.transient;
      final worker = SyncEngine(
        database: db,
        scope: scope,
        workerId: 'errors',
        clock: () => now,
        jitter: (_) => 0,
        transport: CallbackTransport((_) async {
          calls++;
          throw SyncTransportException(kind, 'sanitized');
        }),
      );
      addTearDown(worker.dispose);
      await repository.save(patient());
      await worker.synchronize();
      await worker.synchronize();
      expect(calls, 1);
      now = now.add(const Duration(seconds: 3));
      kind = TransportFailureKind.authentication;
      await worker.synchronize();
      expect(
        (await db.operations(scope)).single.state,
        DeliveryState.authenticationRequired,
      );
      await worker.synchronize(force: true);
      expect(calls, 2);
      await db.resumeAuthentication(scope);
      kind = TransportFailureKind.permanent;
      await worker.synchronize(force: true);
      expect((await db.operations(scope)).single.state, DeliveryState.rejected);
      await worker.synchronize(force: true);
      expect(calls, 3);
    },
  );

  test(
    'single flight and disposal leave an in-flight operation recoverable',
    () async {
      final response = Completer<PushResult>();
      final started = Completer<void>();
      var calls = 0;
      final worker = SyncEngine(
        database: db,
        scope: scope,
        workerId: 'slow',
        transport: CallbackTransport((_) {
          calls++;
          started.complete();
          return response.future;
        }),
      );
      await repository.save(patient());
      final first = worker.synchronize();
      await started.future;
      final second = worker.synchronize();
      final disposal = worker.dispose();
      response.complete(const Accepted(1));
      await Future.wait([first, second, disposal]);
      expect(calls, 1);
      expect((await db.operations(scope)).single.state, DeliveryState.pending);
      expect((await repository.list()).single.revision, 0);
    },
  );

  test('controller can shut down during a save and close only once', () async {
    final controller = FoundationController(
      database: ClinicDatabase(NativeDatabase.memory()),
      remoteDatabase: ClinicDatabase(NativeDatabase.memory()),
    );
    await controller.initialize();
    final save = controller.addSample();
    await Future.wait([save, controller.shutdown(), controller.shutdown()]);
    controller.dispose();
  });
}
