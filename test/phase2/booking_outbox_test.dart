import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/features/appointments/application/booking_sync.dart';
import 'package:clinic_solution/features/appointments/data/booking_outbox_store.dart';
import 'package:clinic_solution/features/appointments/data/operational_repository.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';

class _Remote implements OperationalRepository {
  final calls = <Map<String, Object?>>[];
  bool lostAck = true;
  OperationalFailure? failure;
  @override
  Future<void> command(Map<String, Object?> command) async {
    calls.add(Map.of(command));
    if (failure != null) throw failure!;
    if (lostAck) {
      lostAck = false;
      throw const OperationalFailure('unknown', unknown: true);
    }
  }

  @override
  Future<List<Practitioner>> practitioners() async =>
      throw const OperationalFailure('unknown', unknown: true);
  @override
  Stream<List<AppointmentModel>> appointments({String? doctorId}) =>
      const Stream.empty();
  @override
  String newOperationId() => 'request-a';
}

void main() {
  test(
    'encrypted booking survives reopen, lost acknowledgement and concurrent workers without changing identity',
    () async {
      final dir = await Directory.systemTemp.createTemp('clinic-booking-');
      final file = File('${dir.path}/booking.sqlite');
      const scope = '["project","user-a","clinic-a"]',
          password = 'synthetic booking passphrase';
      final remote = _Remote();
      var store = BookingOutboxStore(NativeDatabase(file));
      BookingSync? worker;
      BookingOutboxStore? secondStore;
      BookingVault? secondVault;
      try {
        final vault = await store.unlock(scope, password);
        final command = <String, Object?>{
          'kind': 'book',
          'operationId': 'request-a',
          'doctorId': 'doctor',
          'patientId': 'SYNTHETIC PRIVATE ID',
          'reason': 'SYNTHETIC PRIVATE REASON',
          'start': '2026-12-01T03:30:00Z',
          'duration': 20,
        };
        worker = BookingSync(
          vault: vault,
          remote: remote,
          authorized: () => true,
          clock: () => DateTime(2026, 11, 1),
        );
        await worker.queue(command);
        await worker.synchronize();
        expect((await vault.requests()).single.state, 'uncertain');
        final raw =
            (await store
                    .customSelect('SELECT envelope FROM booking_requests')
                    .get())
                .single
                .read<String>('envelope');
        expect(raw, isNot(contains('SYNTHETIC PRIVATE')));
        await expectLater(
          vault.enqueue({...command, 'duration': 30}),
          throwsStateError,
        );
        await vault.cache('practitioners', {
          'at': DateTime.now().millisecondsSinceEpoch,
          'items': [
            {'id': 'doctor', 'name': 'Synthetic doctor'},
          ],
        });
        worker.dispose();
        worker = null;
        await store.close();
        store = BookingOutboxStore(NativeDatabase(file));
        await expectLater(
          store.unlock(scope, 'wrong synthetic passphrase'),
          throwsA(anything),
        );
        final reopened = await store.unlock(scope, password);
        expect((await reopened.requests()).single.command, command);
        expect(await reopened.cached('practitioners'), isNotNull);
        final cached = CachedOperationalRepository(remote, reopened);
        expect((await cached.practitioners()).single.id, 'doctor');
        var authorized = true;
        worker = BookingSync(
          vault: reopened,
          remote: remote,
          authorized: () => authorized,
          clock: () => DateTime(2026, 11, 2),
        );
        await worker.synchronize();
        expect((await reopened.requests()).single.state, 'confirmed');
        expect(remote.calls.length, 2);
        expect(remote.calls.first, remote.calls.last);
        await worker.synchronize();
        expect(remote.calls.length, 2);
        remote.failure = const OperationalFailure('PERMISSION_DENIED');
        await reopened.enqueue({...command, 'operationId': 'request-paused'});
        await worker.synchronize();
        expect((await reopened.requests()).last.state, 'paused');
        final sends = remote.calls.length;
        await worker.synchronize(force: true);
        expect(remote.calls.length, sends);
        authorized = false;
        await expectLater(
          worker.queue({...command, 'operationId': 'wrong-user'}),
          throwsA(isA<OperationalFailure>()),
        );
        await worker.synchronize();
        expect(remote.calls.length, sends);
        authorized = true;
        await reopened.resume('request-paused');
        remote.failure = const OperationalFailure('ALREADY_EXISTS');
        await worker.synchronize();
        expect((await reopened.requests()).last.state, 'rejected');
        await worker.synchronize();
        expect(remote.calls.length, sends + 1);
        await reopened.enqueue({...command, 'operationId': 'request-b'});
        secondStore = BookingOutboxStore(NativeDatabase(file));
        secondVault = await secondStore.unlock(scope, password);
        final claims = await Future.wait([
          reopened.claim('request-b', 'tab-a', 100),
          secondVault.claim('request-b', 'tab-b', 100),
        ]);
        expect(claims.where((v) => v).length, 1);
        expect(await reopened.claim('request-b', 'tab-c', 60101), true);
        await reopened.finish('request-b', 'tab-a', 'confirmed');
        expect(
          (await reopened.requests()).last.state,
          'uncertain',
        ); // A stale owner cannot acknowledge another worker's lease.
        final other = await store.unlock(
          '["project","user-b","clinic-a"]',
          password,
        );
        expect(await other.requests(), isEmpty);
        other.lock();
      } finally {
        worker?.dispose();
        secondVault?.lock();
        await secondStore?.close();
        await store.close();
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
