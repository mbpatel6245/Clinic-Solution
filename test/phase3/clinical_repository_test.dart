// Test-only SDK interface doubles.
// ignore_for_file: subtype_of_sealed_class
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clinic_solution/features/clinical/data/firebase_clinical_repository.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_repository.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/data/datasources/prescription_print_settings.dart';
import 'package:clinic_solution/services/prescription_document.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'synthetic-token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  User? user = _User('doctor-a');
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'the clinical adapter rejects scope overrides and changed users before sending',
    () async {
      var sends = 0;
      final auth = _Auth();
      final repository = FirebaseClinicalRepository(
        'clinic-a',
        auth: auth,
        firestore: _Store(),
        projectId: 'demo-clinic-clinical',
        client: MockClient((request) async {
          sends++;
          expect(
            (jsonDecode(request.body) as Map)['data']['clinicId'],
            'clinic-a',
          );
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          return http.Response(
            '{"result":{"state":"signed","revision":2,"version":1}}',
            200,
          );
        }),
      );
      addTearDown(repository.close);
      await expectLater(
        repository.command({'clinicId': 'other'}),
        throwsA(isA<ClinicalFailure>()),
      );
      await repository.command({
        'kind': 'sign',
        'operationId': 'immutable-operation',
      });
      auth.user = _User('doctor-b');
      await expectLater(
        repository.command({'kind': 'sign'}),
        throwsA(
          isA<ClinicalFailure>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
      expect(sends, 1);
    },
  );
  for (final status in [403, 503, 200]) {
    test(
      'HTTP $status without a valid callable result cannot confirm clinical actions',
      () async {
        final repository = FirebaseClinicalRepository(
          'clinic-a',
          auth: _Auth(),
          firestore: _Store(),
          projectId: 'demo-clinic-clinical',
          client: MockClient(
            (_) async => http.Response(
              status == 200 ? '{}' : 'Gateway response',
              status,
            ),
          ),
        );
        addTearDown(repository.close);
        await expectLater(
          repository.command({'kind': 'sign'}),
          throwsA(
            isA<ClinicalFailure>().having(
              (e) => e.uncertain,
              'uncertain',
              status != 403,
            ),
          ),
        );
      },
    );
  }
  test(
    'clinical payloads and patient PDF sections whitelist fields and identify signed versions',
    () {
      final model = PrescriptionModel.fromMap({
        'patient_id': 'patient',
        'patient': {
          'first_name': 'Synthetic',
          'user_id': 'PRIVATE-UID',
          'abha_id': 'PRIVATE-ABHA',
        },
        'clinical_state': 'signed',
        'clinical_version': 3,
        'clinical_author_id': 'PRIVATE-DOCTOR',
        'private_notes': 'PRIVATE-NOTE',
        'diagnoses': ['Synthetic assessment'],
        'visit_date': Timestamp.fromDate(DateTime(2026, 10, 28)),
      }, 'PRIVATE-INTERNAL-ID');
      final payload = jsonEncode(clinicalRecordPayload(model));
      for (final secret in [
        'PRIVATE-UID',
        'PRIVATE-ABHA',
        'PRIVATE-DOCTOR',
        'PRIVATE-NOTE',
        'PRIVATE-INTERNAL-ID',
      ]) {
        expect(payload, isNot(contains(secret)));
      }
      final sections = PrescriptionDocument.sections(
        model,
        const PrescriptionPrintSettings(),
        'en',
      );
      expect(sections.first, ('Signed clinical version', '3'));
      expect(
        jsonEncode(sections.map((v) => [v.$1, v.$2]).toList()),
        isNot(contains('PRIVATE-')),
      );
      final clinic = ClinicProfile.fromMap({
        'name': 'Synthetic',
        'clinical_v3': true,
      }, 'clinic');
      expect(clinic.clinicalV3, true);
      expect(clinic.copyWith(name: 'Updated').clinicalV3, true);
      expect(clinic.toMap().containsKey('clinical_v3'), false);
    },
  );
}
