import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

class DraftConflict implements Exception {}

Future<List<int>> _deriveDraftKey((String, List<int>) input) async =>
    (await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 600000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(input.$1)),
          nonce: input.$2,
        ))
        .extractBytes();

/// Only encrypted payloads enter SQLite. A draft passphrase is never persisted.
/// One draft per authenticated user/clinic; a revision prevents tab overwrites.
class RegistrationDraftStore extends GeneratedDatabase {
  RegistrationDraftStore(super.executor);
  factory RegistrationDraftStore.open() => RegistrationDraftStore(
    driftDatabase(
      name: 'uvilo_registration_drafts_v1',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
        onResult: (result) {
          if (result.chosenImplementation.name == 'unsafeIndexedDb' ||
              result.chosenImplementation.name == 'inMemory') {
            throw StateError('Durable draft storage unavailable');
          }
        },
      ),
    ),
  );
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement(
      'CREATE TABLE registration_drafts (scope TEXT PRIMARY KEY, revision INTEGER NOT NULL, envelope TEXT NOT NULL)',
    ),
  );

  static String scope(String project, String user, String clinic) {
    if ([project, user, clinic].any((v) => v.isEmpty)) {
      throw ArgumentError('Authenticated clinic scope required');
    }
    return jsonEncode([project, user, clinic]);
  }

  Future<SecretKey> _key(String password, List<int> salt) async =>
      SecretKey(await compute(_deriveDraftKey, (password, salt)));

  Future<int> save(
    String scope,
    Map<String, Object?> payload,
    String passphrase, {
    required int expectedRevision,
  }) async {
    if (passphrase.length < 16) {
      throw ArgumentError('Use at least 16 characters');
    }
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final cipher = AesGcm.with256bits();
    final box = await cipher.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: await _key(passphrase, salt),
      aad: utf8.encode('v1:$scope'),
    );
    final envelope = jsonEncode({
      'v': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
    return transaction(() async {
      final rows = await customSelect(
        'SELECT revision, envelope FROM registration_drafts WHERE scope = ?',
        variables: [Variable(scope)],
      ).get();
      final current = rows.isEmpty ? 0 : rows.single.read<int>('revision');
      final removed =
          rows.isNotEmpty && rows.single.read<String>('envelope').isEmpty;
      if (current != expectedRevision && !(removed && expectedRevision == 0)) {
        throw DraftConflict();
      }
      await customStatement(
        'INSERT OR REPLACE INTO registration_drafts VALUES (?, ?, ?)',
        [scope, current + 1, envelope],
      );
      return current + 1;
    });
  }

  Future<({int revision, Map<String, Object?> payload})?> restore(
    String scope,
    String passphrase,
  ) async {
    final rows = await customSelect(
      'SELECT * FROM registration_drafts WHERE scope = ?',
      variables: [Variable(scope)],
    ).get();
    if (rows.isEmpty) return null;
    final envelope = rows.single.read<String>('envelope');
    if (envelope.isEmpty) return null;
    final data = jsonDecode(envelope) as Map;
    if (data['v'] != 1) {
      throw const FormatException('Unsupported draft version');
    }
    List<int> bytes(String name) => base64Decode(data[name] as String);
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(bytes('cipher'), nonce: bytes('nonce'), mac: Mac(bytes('mac'))),
      secretKey: await _key(passphrase, bytes('salt')),
      aad: utf8.encode('v1:$scope'),
    );
    return (
      revision: rows.single.read<int>('revision'),
      payload: Map<String, Object?>.from(jsonDecode(utf8.decode(plain)) as Map),
    );
  }

  Future<void> remove(
    String scope,
    int expectedRevision,
  ) => transaction(() async {
    final changed = await customUpdate(
      // Retain only a revision tombstone. Deleting it would let a recreated
      // draft reuse an old tab's revision and bypass the stale-write check.
      "UPDATE registration_drafts SET envelope = '', revision = revision + 1 WHERE scope = ? AND revision = ? AND envelope != ''",
      variables: [Variable(scope), Variable(expectedRevision)],
    );
    if (changed != 1) throw DraftConflict();
  });
}
