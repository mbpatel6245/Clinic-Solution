import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../domain/clinic_scope.dart';
import '../sync/sync_contract.dart';

/// Phase 1 administrative prototype store. Not enabled for production PHI.
/// SQL is explicit so schema migrations are reviewable without generated code.
final class ClinicDatabase extends GeneratedDatabase {
  ClinicDatabase(super.executor);
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''CREATE TABLE patients (
        scope TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(scope, id))''');
      await customStatement('''CREATE TABLE outbox (
        scope TEXT NOT NULL, id TEXT NOT NULL, entity_id TEXT NOT NULL,
        kind TEXT NOT NULL, payload TEXT NOT NULL, base_revision INTEGER NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt INTEGER NOT NULL DEFAULT 0, error_code TEXT,
        remote_revision INTEGER, remote_payload TEXT,
        PRIMARY KEY(scope, id), UNIQUE(scope, entity_id))''');
      await customStatement('''CREATE TABLE sync_cursors (
        scope TEXT PRIMARY KEY, cursor TEXT NOT NULL)''');
      await customStatement(
        '''CREATE TABLE sync_leases (
        scope TEXT PRIMARY KEY, owner TEXT NOT NULL, expires_at INTEGER NOT NULL)''',
      );
    },
    onUpgrade: (_, from, to) =>
        throw StateError('Unsupported database migration $from → $to'),
  );

  Future<List<QueryRow>> _query(String sql, List<Object> values) =>
      customSelect(
        sql,
        variables: values
            .map(
              (v) =>
                  v is int ? Variable<int>(v) : Variable<String>(v as String),
            )
            .toList(),
      ).get();

  Map<String, Object?> _payload(String value) =>
      Map<String, Object?>.from(jsonDecode(value) as Map);

  void _validatePayload(Map<String, Object?> payload) {
    final first = payload['first_name'];
    final last = payload['last_name'];
    if (first is! String ||
        first.trim().isEmpty ||
        first.length > 120 ||
        (last != null && (last is! String || last.length > 120))) {
      throw const FormatException('Invalid administrative patient payload');
    }
  }

  Future<List<QueryRow>> patients(
    ClinicScope scope, {
    String search = '',
    int limit = 50,
    int offset = 0,
  }) {
    if (limit < 1 || limit > 200 || offset < 0) {
      throw ArgumentError('Invalid page.');
    }
    return _query(
      r'''SELECT p.*, o.state AS sync_state FROM patients p
      LEFT JOIN outbox o ON o.scope = p.scope AND o.entity_id = p.id
      WHERE p.scope = ? AND p.deleted = 0
      AND instr(lower(json_extract(p.payload, '$.first_name') || ' ' ||
          coalesce(json_extract(p.payload, '$.last_name'), '')), lower(?)) > 0
      ORDER BY lower(json_extract(p.payload, '$.first_name')), p.id LIMIT ? OFFSET ?''',
      [scope.key, search.trim(), limit, offset],
    );
  }

  Future<void> stage(
    ClinicScope scope, {
    required String operationId,
    required String entityId,
    required MutationKind kind,
    required Map<String, Object?> patch,
  }) async {
    if (operationId.isEmpty || entityId.isEmpty || entityId.contains('/')) {
      throw ArgumentError('Stable operation and entity IDs required.');
    }
    await transaction(() async {
      final waiting = await _query(
        'SELECT id FROM outbox WHERE scope = ? AND entity_id = ?',
        [scope.key, entityId],
      );
      if (waiting.isNotEmpty) {
        throw StateError(
          'Resolve or synchronize the existing change before editing this record.',
        );
      }
      final existing = await _query(
        'SELECT * FROM patients WHERE scope = ? AND id = ?',
        [scope.key, entityId],
      );
      if (kind == MutationKind.delete &&
          (existing.isEmpty || existing.single.read<int>('deleted') == 1)) {
        throw StateError('Patient is not available locally.');
      }
      final revision = existing.isEmpty
          ? 0
          : existing.single.read<int>('revision');
      final payload = {
        if (existing.isNotEmpty)
          ..._payload(existing.single.read<String>('payload')),
        ...patch,
      };
      final encoded = jsonEncode(payload);
      _validatePayload(payload);
      await customStatement(
        '''INSERT INTO patients(scope,id,payload,revision,deleted)
        VALUES(?,?,?,?,?) ON CONFLICT(scope,id) DO UPDATE SET payload=excluded.payload,deleted=excluded.deleted''',
        [
          scope.key,
          entityId,
          encoded,
          revision,
          kind == MutationKind.delete ? 1 : 0,
        ],
      );
      await customStatement(
        '''INSERT INTO outbox(scope,id,entity_id,kind,payload,base_revision)
        VALUES(?,?,?,?,?,?)''',
        [scope.key, operationId, entityId, kind.name, encoded, revision],
      );
    });
    _changes.add(null);
  }

  Future<List<SyncOperation>> operations(ClinicScope scope) async =>
      (await _query('SELECT * FROM outbox WHERE scope = ? ORDER BY rowid', [
            scope.key,
          ]))
          .map(
            (r) => SyncOperation(
              id: r.read<String>('id'),
              scope: scope,
              entityId: r.read<String>('entity_id'),
              kind: MutationKind.values.byName(r.read<String>('kind')),
              payload: _payload(r.read<String>('payload')),
              baseRevision: r.read<int>('base_revision'),
              attempts: r.read<int>('attempts'),
              nextAttemptAt: r.read<int>('next_attempt'),
              state: DeliveryState.values.byName(r.read<String>('state')),
              errorCode: r.readNullable<String>('error_code'),
              remoteRevision: r.readNullable<int>('remote_revision'),
              remotePayload: r.readNullable<String>('remote_payload') == null
                  ? null
                  : _payload(r.read<String>('remote_payload')),
            ),
          )
          .toList();

  Future<bool> acquireLease(ClinicScope scope, String owner, int now) =>
      transaction(() async {
        await customStatement(
          '''INSERT INTO sync_leases(scope,owner,expires_at) VALUES(?,?,?)
      ON CONFLICT(scope) DO UPDATE SET owner=excluded.owner,expires_at=excluded.expires_at
      WHERE sync_leases.expires_at <= ? OR sync_leases.owner = ?''',
          [scope.key, owner, now + 60000, now, owner],
        );
        final row = (await _query(
          'SELECT owner FROM sync_leases WHERE scope = ?',
          [scope.key],
        )).single;
        return row.read<String>('owner') == owner;
      });

  Future<void> releaseLease(ClinicScope scope, String owner) => customStatement(
    'DELETE FROM sync_leases WHERE scope = ? AND owner = ?',
    [scope.key, owner],
  );

  Future<void> accept(SyncOperation op, int revision) async {
    if (revision != op.baseRevision + 1) {
      throw const FormatException('Unexpected accepted revision');
    }
    await transaction(() async {
      final queued = await _query(
        'SELECT id FROM outbox WHERE scope = ? AND id = ?',
        [op.scope.key, op.id],
      );
      if (queued.isEmpty) return;
      await customStatement(
        'UPDATE patients SET revision = ? WHERE scope = ? AND id = ?',
        [revision, op.scope.key, op.entityId],
      );
      await customStatement('DELETE FROM outbox WHERE scope = ? AND id = ?', [
        op.scope.key,
        op.id,
      ]);
    });
    _changes.add(null);
  }

  Future<void> defer(
    SyncOperation op, {
    required DeliveryState state,
    required String code,
    required int nextAttempt,
    int? remoteRevision,
    Map<String, Object?>? remotePayload,
  }) async {
    if (state == DeliveryState.conflict && remotePayload != null) {
      _validatePayload(remotePayload);
    }
    await customStatement(
      '''UPDATE outbox SET state=?,error_code=?,attempts=attempts+1,
      next_attempt=?,remote_revision=?,remote_payload=? WHERE scope=? AND id=?''',
      [
        state.name,
        code,
        nextAttempt,
        remoteRevision,
        remotePayload == null ? null : jsonEncode(remotePayload),
        op.scope.key,
        op.id,
      ],
    );
    _changes.add(null);
  }

  /// Explicit user review: either adopt the remote record, or create a NEW
  /// operation based on that revision. Never mutate a previously sent payload.
  Future<void> resolveConflict(
    SyncOperation op, {
    required bool keepLocal,
    required String newOperationId,
  }) async {
    await transaction(() async {
      final rows = await _query(
        'SELECT * FROM outbox WHERE scope=? AND id=? AND state=?',
        [op.scope.key, op.id, DeliveryState.conflict.name],
      );
      if (rows.isEmpty) throw StateError('Conflict is no longer current.');
      final r = rows.single;
      final revision = r.read<int>('remote_revision');
      final remote = r.readNullable<String>('remote_payload');
      await customStatement('DELETE FROM outbox WHERE scope=? AND id=?', [
        op.scope.key,
        op.id,
      ]);
      if (keepLocal) {
        if (newOperationId.isEmpty || newOperationId == op.id) {
          throw ArgumentError('A new operation ID is required.');
        }
        await customStatement(
          'UPDATE patients SET revision=? WHERE scope=? AND id=?',
          [revision, op.scope.key, op.entityId],
        );
        await customStatement(
          '''INSERT INTO outbox(scope,id,entity_id,kind,payload,base_revision)
          VALUES(?,?,?,?,?,?)''',
          [
            op.scope.key,
            newOperationId,
            op.entityId,
            r.read<String>('kind'),
            r.read<String>('payload'),
            revision,
          ],
        );
      } else {
        await customStatement(
          'UPDATE patients SET payload=?,revision=?,deleted=? WHERE scope=? AND id=?',
          [
            remote ?? r.read<String>('payload'),
            revision,
            remote == null ? 1 : 0,
            op.scope.key,
            op.entityId,
          ],
        );
      }
    });
    _changes.add(null);
  }

  Future<void> resumeAuthentication(ClinicScope scope) async {
    await customStatement(
      'UPDATE outbox SET state=?,next_attempt=0,error_code=NULL WHERE scope=? AND state=?',
      [
        DeliveryState.pending.name,
        scope.key,
        DeliveryState.authenticationRequired.name,
      ],
    );
    _changes.add(null);
  }

  Future<String?> cursor(ClinicScope scope) async {
    final rows = await _query('SELECT cursor FROM sync_cursors WHERE scope=?', [
      scope.key,
    ]);
    return rows.isEmpty ? null : rows.single.read<String>('cursor');
  }

  Future<void> applyPage(ClinicScope scope, ChangePage page) async {
    await transaction(() async {
      var hasUnresolvedRecord = false;
      for (final record in page.records) {
        if (record.id.isEmpty ||
            record.id.contains('/') ||
            record.revision < 1) {
          throw const FormatException('Invalid remote record');
        }
        if (record.payload != null) _validatePayload(record.payload!);
        final pending = await _query(
          'SELECT * FROM outbox WHERE scope=? AND entity_id=?',
          [scope.key, record.id],
        );
        if (pending.isNotEmpty) {
          // A pull cannot prove whether an unacknowledged command succeeded.
          // Leave its stable payload/base untouched; push obtains the receipt.
          hasUnresolvedRecord = true;
          continue;
        }
        final existing = await _query(
          'SELECT revision FROM patients WHERE scope=? AND id=?',
          [scope.key, record.id],
        );
        if (existing.isNotEmpty &&
            existing.single.read<int>('revision') >= record.revision) {
          continue;
        }
        await customStatement(
          '''INSERT INTO patients(scope,id,payload,revision,deleted)
          VALUES(?,?,?,?,?) ON CONFLICT(scope,id) DO UPDATE SET
          payload=excluded.payload,revision=excluded.revision,deleted=excluded.deleted''',
          [
            scope.key,
            record.id,
            jsonEncode(record.payload ?? {}),
            record.revision,
            record.payload == null ? 1 : 0,
          ],
        );
      }
      // Replay this page after acknowledgement/review. Advancing past a skipped
      // record could permanently lose a newer server revision after a lost ACK.
      if (!hasUnresolvedRecord) {
        await customStatement(
          '''INSERT INTO sync_cursors(scope,cursor) VALUES(?,?)
          ON CONFLICT(scope) DO UPDATE SET cursor=excluded.cursor''',
          [scope.key, page.cursor],
        );
      }
    });
    _changes.add(null);
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await super.close();
  }
}
