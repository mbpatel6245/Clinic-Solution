// Synthetic native feasibility probe. No production Firebase calls or secrets.
// Run with `dart run tool/foundation_desktop_probe.dart` on Windows and Linux.
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:clinic_solution/core/domain/clinic_scope.dart';
import 'package:clinic_solution/core/persistence/clinic_database.dart';
import 'package:clinic_solution/core/platform/firebase_rest_client.dart';
import 'package:clinic_solution/core/sync/sync_engine.dart';
import 'package:clinic_solution/core/sync/synthetic_sync_transport.dart';
import 'package:clinic_solution/features/patients/data/offline_patient_repository.dart';
import 'package:clinic_solution/features/patients/domain/patient_repository.dart';

void check(bool condition, String label) {
  if (!condition) throw StateError('Probe failed: $label');
}

Future<void> main() async {
  // Independent native connections are intentional in this feasibility probe.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final folder = await Directory.systemTemp.createTemp('uvilo-desktop-probe-');
  final scope = ClinicScope(
    projectId: 'demo-foundation',
    userId: 'demo-user',
    clinicId: 'demo-clinic',
  );
  ClinicDatabase open(String name) =>
      ClinicDatabase(NativeDatabase(File('${folder.path}/$name.sqlite')));
  var local = open('local');
  var remote = open('synthetic-server');
  var sequence = 0;
  OfflinePatientRepository repository() => OfflinePatientRepository(
    database: local,
    scope: scope,
    newId: () => 'operation-${++sequence}',
  );
  final client = http.Client();
  HttpServer? server;
  SyncEngine? engine;
  try {
    final save = await repository().save(
      PatientProfile(id: 'demo-patient', firstName: 'Synthetic'),
    );
    await local.close();
    local = open('local');
    check(
      (await repository().list()).single.patient.firstName == 'Synthetic',
      'restart data',
    );
    check(
      (await local.operations(scope)).single.id == save.operationId,
      'restart outbox',
    );
    var transport = SyntheticSyncTransport(remote)..online = true;
    engine = SyncEngine(
      database: local,
      scope: scope,
      transport: transport,
      workerId: 'probe',
    );
    transport.loseNextAcknowledgement = true;
    await engine.synchronize(force: true);
    check(
      (await local.operations(scope)).single.errorCode ==
          'acknowledgement-lost',
      'lost acknowledgement retained',
    );
    await engine.dispose();
    await remote.close();
    remote = open('synthetic-server');
    transport = SyntheticSyncTransport(remote)..online = true;
    engine = SyncEngine(
      database: local,
      scope: scope,
      transport: transport,
      workerId: 'probe-restarted',
    );
    await engine.synchronize(force: true);
    check((await local.operations(scope)).isEmpty, 'receipt replay');
    check(
      (await repository().list()).single.revision == 1,
      'no duplicate revision',
    );

    // Same physical database, separate connection: lease visibility is not just
    // an in-memory lock on one repository instance.
    final secondConnection = open('local');
    try {
      check(await local.acquireLease(scope, 'one', 0), 'first lease');
      check(
        !await secondConnection.acquireLease(scope, 'two', 1),
        'cross-connection exclusion',
      );
      check(
        await secondConnection.acquireLease(scope, 'two', 60000),
        'expired lease recovery',
      );
    } finally {
      await secondConnection.close();
    }

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('accounts:signInWithPassword')) {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        if (body['email'] != 'demo@example.test' ||
            body['password'] != 'synthetic-only') {
          request.response.statusCode = 401;
          request.response.write('{}');
        } else {
          request.response.write(
            jsonEncode({
              'localId': scope.userId,
              'idToken': 'synthetic-token',
              'refreshToken': 'synthetic-refresh',
              'expiresIn': '3600',
            }),
          );
        }
      } else if (request.uri.path ==
              '/v1/projects/demo-foundation/databases/(default)/documents/clinics/demo-clinic/patients' &&
          request.headers.value('Authorization') == 'Bearer synthetic-token') {
        request.response.write('{"documents":[{"name":"synthetic-patient"}]}');
      } else {
        request.response.statusCode = 403;
        request.response.write('{}');
      }
      await request.response.close();
    });
    final base = Uri.parse('http://127.0.0.1:${server.port}/v1/');
    final rest = FirebaseRestClient(
      projectId: scope.projectId,
      apiKey: 'synthetic-key',
      client: client,
      authBase: base,
      firestoreBase: base,
      tokenBase: base,
    );
    final session = await rest.signIn('demo@example.test', 'synthetic-only');
    final page = await rest.listPatients(scope, session);
    check((page['documents'] as List).length == 1, 'authorized loopback read');
    stdout.writeln(
      jsonEncode({
        'platform': Platform.operatingSystem,
        'passed': true,
        'checks': [
          'sqlite-restart',
          'durable-outbox',
          'lost-ack-replay',
          'durable-receipts',
          'cross-connection-lease',
          'auth-rest-wire-format',
          'scoped-authorized-http-read',
        ],
        'firebase': 'synthetic loopback server; real Firebase not contacted',
      }),
    );
  } finally {
    client.close();
    await server?.close(force: true);
    await engine?.dispose();
    await local.close();
    await remote.close();
    await folder.delete(recursive: true);
  }
}
