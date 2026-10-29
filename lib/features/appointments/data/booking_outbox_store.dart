import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

Future<List<int>> _derive((String, List<int>) input) async =>
    (await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 600000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(input.$1)),
          nonce: input.$2,
        ))
        .extractBytes();

class BookingRequest {
  const BookingRequest(
    this.id,
    this.command,
    this.state,
    this.attempts,
    this.nextAttempt,
    this.error,
  );
  final String id, state, error;
  final Map<String, Object?> command;
  final int attempts, nextAttempt;
}

/// A separate encrypted journal. No Firebase cache or synthetic database is used.
class BookingOutboxStore extends GeneratedDatabase {
  BookingOutboxStore(super.executor);
  factory BookingOutboxStore.open() => BookingOutboxStore(
    driftDatabase(
      name: 'uvilo_booking_outbox_v1',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
        onResult: (r) {
          if ([
            'unsafeIndexedDb',
            'inMemory',
          ].contains(r.chosenImplementation.name)) {
            throw StateError('Durable booking storage unavailable');
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
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE booking_vaults (scope TEXT PRIMARY KEY, salt TEXT NOT NULL, verifier TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE booking_requests (scope TEXT NOT NULL, id TEXT NOT NULL, envelope TEXT NOT NULL, state TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER NOT NULL DEFAULT 0, error TEXT NOT NULL DEFAULT \'\', lease_owner TEXT NOT NULL DEFAULT \'\', lease_until INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(scope,id))',
      );
      await customStatement(
        'CREATE TABLE booking_cache (scope TEXT NOT NULL, name TEXT NOT NULL, envelope TEXT NOT NULL, PRIMARY KEY(scope,name))',
      );
    },
  );

  Future<BookingVault> unlock(String scope, String password) async {
    if (password.length < 16) throw ArgumentError('Use at least 16 characters');
    if (scope.isEmpty) {
      throw ArgumentError('Authenticated clinic scope required');
    }
    Future<List<QueryRow>> metadata() => customSelect(
      'SELECT * FROM booking_vaults WHERE scope = ?',
      variables: [Variable(scope)],
    ).get();
    var rows = await metadata();
    final salt = rows.isEmpty
        ? List<int>.generate(16, (_) => Random.secure().nextInt(256))
        : base64Decode(rows.single.read<String>('salt'));
    var key = SecretKey(await compute(_derive, (password, salt)));
    if (rows.isEmpty) {
      final verifier = await _seal(key, 'vault:$scope', {'version': 1});
      await customStatement(
        'INSERT OR IGNORE INTO booking_vaults VALUES (?, ?, ?)',
        [scope, base64Encode(salt), verifier],
      );
      rows = await metadata();
      if (rows.single.read<String>('salt') != base64Encode(salt)) {
        key = SecretKey(
          await compute(_derive, (
            password,
            base64Decode(rows.single.read<String>('salt')),
          )),
        );
      }
    }
    final check = await _open(
      key,
      'vault:$scope',
      rows.single.read<String>('verifier'),
    );
    if (check['version'] != 1) throw const FormatException('Invalid vault');
    return BookingVault._(this, scope, key);
  }
}

Future<String> _seal(
  SecretKey key,
  String aad,
  Map<String, Object?> value,
) async {
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(value)),
    secretKey: key,
    aad: utf8.encode(aad),
  );
  return jsonEncode({
    'nonce': base64Encode(box.nonce),
    'cipher': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  });
}

Future<Map<String, Object?>> _open(
  SecretKey key,
  String aad,
  String value,
) async {
  final box = jsonDecode(value) as Map;
  final plain = await AesGcm.with256bits().decrypt(
    SecretBox(
      base64Decode(box['cipher'] as String),
      nonce: base64Decode(box['nonce'] as String),
      mac: Mac(base64Decode(box['mac'] as String)),
    ),
    secretKey: key,
    aad: utf8.encode(aad),
  );
  return Map<String, Object?>.from(jsonDecode(utf8.decode(plain)) as Map);
}

class BookingVault {
  BookingVault._(this.store, this.scope, this._key);
  final BookingOutboxStore store;
  final String scope;
  SecretKey? _key;
  void lock() => _key = null;
  SecretKey get key => _key ?? (throw StateError('Booking vault is locked'));
  Future<void> enqueue(Map<String, Object?> command) async {
    final id = command['operationId'];
    if (command['kind'] != 'book' ||
        id is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw ArgumentError('Invalid booking command');
    }
    final envelope = await _seal(key, '$scope:request:$id', command);
    await store.transaction(() async {
      final existing = await store
          .customSelect(
            'SELECT envelope FROM booking_requests WHERE scope = ? AND id = ?',
            variables: [Variable(scope), Variable(id)],
          )
          .get();
      if (existing.isNotEmpty) {
        final previous = await _open(
          key,
          '$scope:request:$id',
          existing.single.read<String>('envelope'),
        );
        if (!mapEquals(previous, command)) {
          throw StateError('Request ID already used');
        }
        return;
      }
      await store.customStatement(
        'INSERT INTO booking_requests (scope,id,envelope,state) VALUES (?, ?, ?, ?)',
        [scope, id, envelope, 'pending'],
      );
    });
  }

  Future<List<BookingRequest>> requests() async {
    final rows = await store
        .customSelect(
          'SELECT * FROM booking_requests WHERE scope = ? ORDER BY rowid',
          variables: [Variable(scope)],
        )
        .get();
    final result = <BookingRequest>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      result.add(
        BookingRequest(
          id,
          await _open(key, '$scope:request:$id', row.read<String>('envelope')),
          row.read<String>('state'),
          row.read<int>('attempts'),
          row.read<int>('next_attempt'),
          row.read<String>('error'),
        ),
      );
    }
    return result;
  }

  Future<bool> claim(
    String id,
    String owner,
    int now, {
    bool force = false,
  }) async =>
      (await store.customUpdate(
        "UPDATE booking_requests SET state = 'uncertain', attempts = attempts + 1, lease_owner = ?, lease_until = ? WHERE scope = ? AND id = ? AND state IN ('pending','uncertain') AND lease_until <= ? AND (? = 1 OR next_attempt <= ?)",
        variables: [
          Variable(owner),
          Variable(now + 60000),
          Variable(scope),
          Variable(id),
          Variable(now),
          Variable(force ? 1 : 0),
          Variable(now),
        ],
      )) ==
      1;
  Future<void> finish(
    String id,
    String owner,
    String state, {
    String error = '',
    int nextAttempt = 0,
  }) async {
    key; // Refuse applying a response to a locked workspace.
    await store.customUpdate(
      'UPDATE booking_requests SET state = ?, error = ?, next_attempt = ?, lease_owner = \'\', lease_until = 0 WHERE scope = ? AND id = ? AND lease_owner = ?',
      variables: [
        Variable(state),
        Variable(error),
        Variable(nextAttempt),
        Variable(scope),
        Variable(id),
        Variable(owner),
      ],
    );
  }

  Future<void> resume(String id) => store.customUpdate(
    "UPDATE booking_requests SET state = 'pending', next_attempt = 0, error = '' WHERE scope = ? AND id = ? AND state = 'paused'",
    variables: [Variable(scope), Variable(id)],
  );
  Future<void> cache(String name, Map<String, Object?> value) async {
    final envelope = await _seal(key, '$scope:cache:$name', value);
    await store.customStatement(
      'INSERT OR REPLACE INTO booking_cache VALUES (?, ?, ?)',
      [scope, name, envelope],
    );
  }

  Future<Map<String, Object?>?> cached(String name) async {
    final rows = await store
        .customSelect(
          'SELECT envelope FROM booking_cache WHERE scope = ? AND name = ?',
          variables: [Variable(scope), Variable(name)],
        )
        .get();
    return rows.isEmpty
        ? null
        : _open(
            key,
            '$scope:cache:$name',
            rows.single.read<String>('envelope'),
          );
  }
}
