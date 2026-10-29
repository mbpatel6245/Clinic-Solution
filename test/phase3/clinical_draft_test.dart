import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_draft_repository.dart';
import 'package:clinic_solution/features/clinical/data/encrypted_clinical_draft_repository.dart';
import 'package:clinic_solution/features/patients/data/registration_draft_store.dart';

String scope({
  String user = 'clinician',
  String patient = 'patient',
  String encounter = 'queue',
}) => ClinicalDraftIdentity(
  project: 'synthetic',
  user: user,
  clinic: 'clinic',
  patient: patient,
  encounter: encounter,
).scope;

void main() {
  test(
    'clinical recovery identities isolate users, patients, encounters and registration',
    () {
      expect(scope(), isNot(scope(user: 'other')));
      expect(scope(), isNot(scope(patient: 'other')));
      expect(scope(), isNot(scope(encounter: 'other')));
      expect(
        scope(),
        isNot(RegistrationDraftStore.scope('synthetic', 'clinician', 'clinic')),
      );
      expect(
        () => ClinicalDraftIdentity(
          project: '',
          user: 'u',
          clinic: 'c',
          patient: 'p',
          encounter: 'e',
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'clinical draft and private notes recover after restart without plaintext storage or silent overwrite',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clinical-recovery-',
      );
      final file = File('${directory.path}/recovery.sqlite');
      const password = 'synthetic consultation passphrase';
      EncryptedClinicalDraftRepository open([String? key]) =>
          EncryptedClinicalDraftRepository(
            key ?? scope(),
            RegistrationDraftStore(NativeDatabase(file)),
          );
      var repository = open();
      try {
        final payload = <String, Object?>{
          'version': 1,
          'id': 'stable-rx',
          'fields': {
            'privateNotes': 'PRIVATE SYNTHETIC NOTE',
            'diagnosis': 'SYNTHETIC ASSESSMENT',
          },
          'medicines': [
            {'name': 'Synthetic medicine'},
          ],
        };
        expect(
          await repository.save(payload, password, expectedRevision: 0),
          1,
        );
        await repository.close();
        expect(
          String.fromCharCodes(await file.readAsBytes()),
          isNot(contains('PRIVATE SYNTHETIC NOTE')),
        );
        repository = open();
        final recovered = await repository.restore(password);
        expect(recovered?.payload, payload);
        await expectLater(
          repository.restore('incorrect synthetic passphrase'),
          throwsA(anything),
        );
        await repository.close();
        final other = open(scope(patient: 'other'));
        expect(await other.restore(password), isNull);
        await other.close();
        repository = open();
        await expectLater(
          repository.save({'id': 'stale-rx'}, password, expectedRevision: 0),
          throwsA(isA<DraftConflict>()),
        );
        expect(
          (await repository.restore(password))?.payload['id'],
          'stable-rx',
        );
        await repository.remove(recovered!.revision);
        expect(await repository.restore(password), isNull);
      } finally {
        await repository.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
