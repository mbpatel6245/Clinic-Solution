import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:clinic_solution/features/patients/data/registration_draft_store.dart';

void main() {
  test(
    'encrypted draft survives process reopen; wrong passphrase and stale tab are rejected',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clinic-draft-test-',
      );
      final file = File('${directory.path}/draft.sqlite');
      final scope = RegistrationDraftStore.scope(
        'project',
        'user-a',
        'clinic-a',
      );
      const password = 'synthetic test passphrase only';
      var store = RegistrationDraftStore(NativeDatabase(file));
      try {
        final revision = await store.save(
          scope,
          {'name': 'SYNTHETIC PRIVATE NAME', 'patientId': 'stable-1'},
          password,
          expectedRevision: 0,
        );
        expect(revision, 1);
        final raw = await store
            .customSelect('SELECT envelope FROM registration_drafts')
            .get();
        expect(
          raw.single.read<String>('envelope'),
          isNot(contains('SYNTHETIC PRIVATE NAME')),
        );
        await store.close();
        store = RegistrationDraftStore(NativeDatabase(file));
        expect(
          (await store.restore(scope, password))!.payload['patientId'],
          'stable-1',
        );
        expect(
          await store.restore(
            RegistrationDraftStore.scope('project', 'user-b', 'clinic-a'),
            password,
          ),
          isNull,
        );
        await expectLater(
          store.restore(scope, 'wrong synthetic passphrase'),
          throwsA(anything),
        );
        await expectLater(
          store.save(
            scope,
            {'name': 'stale-tab'},
            password,
            expectedRevision: 0,
          ),
          throwsA(isA<DraftConflict>()),
        );
        expect(
          (await store.restore(scope, password))!.payload['name'],
          'SYNTHETIC PRIVATE NAME',
        );
        await store.remove(scope, 1);
        expect(await store.restore(scope, password), isNull);
        final recreated = await store.save(
          scope,
          {'patientId': 'stable-2'},
          password,
          expectedRevision: 0,
        );
        expect(recreated, 3);
        await expectLater(
          store.remove(scope, revision),
          throwsA(isA<DraftConflict>()),
        );
        await expectLater(
          store.save(
            scope,
            {'patientId': 'stale-before-removal'},
            password,
            expectedRevision: revision,
          ),
          throwsA(isA<DraftConflict>()),
        );
        expect(
          (await store.restore(scope, password))!.payload['patientId'],
          'stable-2',
        );
      } finally {
        await store.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
