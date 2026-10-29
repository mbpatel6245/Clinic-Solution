import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clinic_solution/core/domain/clinic_scope.dart';
import 'package:clinic_solution/core/platform/firebase_rest_client.dart';
import 'package:clinic_solution/core/sync/https_sync_transport.dart';
import 'package:clinic_solution/core/sync/sync_contract.dart';

void main() {
  final scope = ClinicScope(
    projectId: 'demo-project',
    userId: 'u',
    clinicId: 'c',
  );
  final now = DateTime.utc(2026);
  RestAuthSession session({String uid = 'u', DateTime? expiry}) =>
      RestAuthSession(
        userId: uid,
        idToken: 'synthetic-token',
        refreshToken: 'synthetic-refresh',
        expiresAt: expiry ?? now.add(const Duration(hours: 1)),
      );
  FirebaseRestClient rest(http.Client client) => FirebaseRestClient(
    projectId: scope.projectId,
    apiKey: 'test-key',
    client: client,
    clock: () => now,
  );
  SyncOperation operation() => SyncOperation(
    id: 'op',
    scope: scope,
    entityId: 'p',
    kind: MutationKind.put,
    payload: const {'first_name': 'Demo'},
    baseRevision: 0,
  );

  test(
    'desktop sign-in and refresh retain identity and send correct requests',
    () async {
      final client = rest(
        MockClient((request) async {
          if (request.url.path.endsWith('accounts:signInWithPassword')) {
            expect(request.url.scheme, 'https');
            expect(request.url.host, 'identitytoolkit.googleapis.com');
            expect(request.url.queryParameters['key'], 'test-key');
            expect(jsonDecode(request.body)['returnSecureToken'], isTrue);
            return http.Response(
              jsonEncode({
                'localId': 'u',
                'idToken': 'first',
                'refreshToken': 'refresh',
                'expiresIn': '3600',
              }),
              200,
            );
          }
          expect(request.bodyFields['grant_type'], 'refresh_token');
          expect(request.bodyFields['refresh_token'], 'refresh');
          return http.Response(
            jsonEncode({
              'user_id': 'u',
              'id_token': 'second',
              'refresh_token': 'next',
              'expires_in': '1800',
            }),
            200,
          );
        }),
      );
      final signedIn = await client.signIn(
        'demo@example.test',
        'fake-password',
      );
      final renewed = await client.refresh(signedIn);
      expect(renewed.userId, 'u');
      expect(renewed.idToken, 'second');
      expect(renewed.expiresAt, now.add(const Duration(minutes: 30)));
      expect(renewed.toString(), isNot(contains('second')));
    },
  );

  test(
    'authorized Firestore read uses scoped path, token and pagination',
    () async {
      var calls = 0;
      final client = rest(
        MockClient((request) async {
          calls++;
          expect(
            request.url.path,
            '/v1/projects/demo-project/databases/(default)/documents/clinics/c/patients',
          );
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          expect(request.url.queryParameters, {
            'pageSize': '25',
            'pageToken': 'page two',
          });
          return http.Response('{"documents":[],"nextPageToken":"three"}', 200);
        }),
      );
      expect(
        (await client.listPatients(
          scope,
          session(),
          pageSize: 25,
          pageToken: 'page two',
        ))['nextPageToken'],
        'three',
      );
      await expectLater(
        client.listPatients(scope, session(uid: 'other')),
        throwsStateError,
      );
      await expectLater(
        client.listPatients(scope, session(expiry: now)),
        throwsA(isA<SyncTransportException>()),
      );
      expect(calls, 1);
    },
  );

  test(
    'refresh rejects changed identity and errors never include server bodies',
    () async {
      await expectLater(
        rest(
          MockClient(
            (_) async =>
                http.Response('{"user_id":"other","id_token":"secret"}', 200),
          ),
        ).refresh(session()),
        throwsFormatException,
      );
      await expectLater(
        rest(
          MockClient((_) async => http.Response('secret patient body', 403)),
        ).listPatients(scope, session()),
        throwsA(
          isA<SyncTransportException>()
              .having((e) => e.code, 'sanitized code', 'http-403')
              .having(
                (e) => e.kind,
                'classification',
                TransportFailureKind.permanent,
              ),
        ),
      );
    },
  );

  test(
    'sync contract carries scope, stable ID and base revision; validates receipts',
    () async {
      var wrongScope = false, wrongReceipt = false;
      final transport = HttpsSyncTransport(
        endpoint: Uri.https('example.test', '/sync'),
        idToken: (_) async => 'synthetic-token',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['scope'], scope.toJson());
          expect(body['operationId'], 'op');
          expect(body['baseRevision'], 0);
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          return http.Response(
            jsonEncode({
              'scope': wrongScope
                  ? {...scope.toJson(), 'userId': 'other'}
                  : scope.toJson(),
              'operationId': wrongReceipt ? 'other' : 'op',
              'status': 'accepted',
              'revision': 1,
            }),
            200,
          );
        }),
      );
      expect(
        await transport.push(operation()),
        isA<Accepted>().having((r) => r.revision, 'revision', 1),
      );
      wrongReceipt = true;
      await expectLater(transport.push(operation()), throwsFormatException);
      wrongScope = true;
      await expectLater(transport.push(operation()), throwsFormatException);
    },
  );

  test(
    'missing token blocks network and non-loopback plain HTTP is rejected',
    () async {
      final client = MockClient((_) async => throw StateError('Must not send'));
      final transport = HttpsSyncTransport(
        endpoint: Uri.https('example.test', '/sync'),
        client: client,
        idToken: (_) async => null,
      );
      await expectLater(
        transport.push(operation()),
        throwsA(
          isA<SyncTransportException>().having(
            (e) => e.kind,
            'classification',
            TransportFailureKind.authentication,
          ),
        ),
      );
      expect(
        () => HttpsSyncTransport(
          endpoint: Uri.http('example.test', '/sync'),
          client: client,
          idToken: (_) async => null,
        ),
        throwsArgumentError,
      );
      expect(
        () => FirebaseRestClient(
          projectId: 'p',
          apiKey: 'k',
          client: client,
          authBase: Uri.http('example.test', '/'),
        ),
        throwsArgumentError,
      );
    },
  );
}
