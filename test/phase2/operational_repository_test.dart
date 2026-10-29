// Test-only SDK interface doubles.
// ignore_for_file: subtype_of_sealed_class
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clinic_solution/features/appointments/data/operational_repository.dart';

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
  User? user = _User('user-a');
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
  for (final status in [403, 503]) {
    test(
      'HTTP $status is classified even when the gateway response is not JSON',
      () async {
        final repository = FirebaseOperationalRepository(
          'clinic-a',
          auth: _Auth(),
          firestore: _Store(),
          projectId: 'demo-clinic-operations',
          client: MockClient(
            (_) async => http.Response('Gateway response', status),
          ),
        );
        addTearDown(repository.close);
        await expectLater(
          repository.command({'kind': 'book'}),
          throwsA(
            isA<OperationalFailure>()
                .having((e) => e.unknown, 'unknown', status == 503)
                .having(
                  (e) => e.code,
                  'code',
                  status == 503 ? 'unavailable' : 'permission-denied',
                ),
          ),
        );
      },
    );
  }
  test(
    'callable requests retain their captured clinic and authenticated identity',
    () async {
      var sends = 0;
      final auth = _Auth();
      final repository = FirebaseOperationalRepository(
        'clinic-a',
        auth: auth,
        firestore: _Store(),
        projectId: 'demo-clinic-operations',
        client: MockClient((request) async {
          sends++;
          expect(
            request.url.host,
            'asia-south1-demo-clinic-operations.cloudfunctions.net',
          );
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          expect(
            (jsonDecode(request.body) as Map)['data']['clinicId'],
            'clinic-a',
          );
          return http.Response('{"result":{"status":"booked"}}', 200);
        }),
      );
      addTearDown(repository.close);
      await repository.command({
        'kind': 'book',
        'clinicId': 'attempted-override',
      });
      auth.user = _User('user-b');
      await expectLater(
        repository.command({'kind': 'book'}),
        throwsA(
          isA<OperationalFailure>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
      expect(sends, 1);
    },
  );
  test('an ambiguous reply cannot become a confirmed booking', () async {
    final repository = FirebaseOperationalRepository(
      'clinic-a',
      auth: _Auth(),
      firestore: _Store(),
      projectId: 'demo-clinic-operations',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(repository.close);
    await expectLater(
      repository.command({'kind': 'book'}),
      throwsA(
        isA<OperationalFailure>().having((e) => e.unknown, 'unknown', true),
      ),
    );
  });
}
