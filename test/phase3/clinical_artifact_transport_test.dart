// SDK interfaces are replaced only inside this isolated transport test.
// ignore_for_file: subtype_of_sealed_class
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clinic_solution/core/platform/scoped_clinic_callable.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'synthetic-token';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements FirebaseAuth {
  User? user = _User('synthetic-doctor');
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test(
    'artifact transport binds clinic and identity and keeps duplicate details',
    () async {
      final auth = _Auth();
      var sends = 0;
      final client = ScopedClinicCallable(
        'synthetic-clinic',
        auth: auth,
        projectId: 'demo-clinic-artifacts',
        client: MockClient((request) async {
          sends++;
          expect(request.url.path, '/clinicalArtifactCommand');
          expect(
            (jsonDecode(request.body) as Map)['data']['clinicId'],
            'synthetic-clinic',
          );
          return http.Response(
            '{"error":{"status":"ALREADY_EXISTS","details":{"existingId":"existing-order"}}}',
            409,
          );
        }),
      );
      addTearDown(client.close);
      await expectLater(
        client.call('clinicalArtifactCommand', {'clinicId': 'other'}),
        throwsA(isA<ClinicCallableFailure>()),
      );
      expect(sends, 0);
      await expectLater(
        client.call('clinicalArtifactCommand', {'action': 'issue'}),
        throwsA(
          isA<ClinicCallableFailure>()
              .having((e) => e.code, 'code', 'already-exists')
              .having(
                (e) => e.details['existingId'],
                'existing order',
                'existing-order',
              ),
        ),
      );
      auth.user = _User('other-doctor');
      await expectLater(
        client.call('clinicalArtifactCommand', {}),
        throwsA(
          isA<ClinicCallableFailure>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
      expect(sends, 1);
    },
  );
  for (final status in [200, 401, 503]) {
    test(
      'HTTP $status without a valid artifact acknowledgement cannot confirm an issue',
      () async {
        final client = ScopedClinicCallable(
          'clinic',
          auth: _Auth(),
          projectId: 'demo-clinic-artifacts',
          client: MockClient((_) async => http.Response('{}', status)),
        );
        addTearDown(client.close);
        await expectLater(
          client.call('clinicalArtifactCommand', {}),
          throwsA(
            isA<ClinicCallableFailure>().having(
              (e) => e.uncertain,
              'uncertain',
              status != 401,
            ),
          ),
        );
      },
    );
  }
  test(
    'identity changing during the request discards its acknowledgement',
    () async {
      final auth = _Auth();
      final client = ScopedClinicCallable(
        'clinic',
        auth: auth,
        projectId: 'demo-clinic-artifacts',
        client: MockClient((_) async {
          auth.user = null;
          return http.Response('{"result":{"state":"issued"}}', 200);
        }),
      );
      addTearDown(client.close);
      await expectLater(
        client.call('clinicalArtifactCommand', {}),
        throwsA(
          isA<ClinicCallableFailure>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
    },
  );
}
