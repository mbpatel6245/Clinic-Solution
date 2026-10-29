import 'dart:convert';
import 'package:drift/drift.dart';
import '../persistence/clinic_database.dart';
import 'sync_contract.dart';

/// Local simulation, never calls Firebase. Used only by the sandbox and tests.
/// The remote's own state/receipts are stored in a separate SQLite database.
final class SyntheticSyncTransport implements SyncTransport {
  SyntheticSyncTransport(this.database);
  final ClinicDatabase database;
  bool online = false;
  bool loseNextAcknowledgement = false;
  Future<void>? _initialized;
  Future<void> _initialize() => _initialized ??= () async {
    await database.customStatement(
      '''CREATE TABLE IF NOT EXISTS demo_remote (
      scope TEXT, id TEXT, revision INTEGER, payload TEXT, PRIMARY KEY(scope,id))''',
    );
    await database.customStatement(
      '''CREATE TABLE IF NOT EXISTS demo_receipts (
      scope TEXT, id TEXT, fingerprint TEXT, revision INTEGER, PRIMARY KEY(scope,id))''',
    );
  }();

  @override
  Future<PushResult> push(SyncOperation op) async {
    if (!online) {
      throw const SyncTransportException(
        TransportFailureKind.transient,
        'offline',
      );
    }
    await _initialize();
    final result = await syntheticCommit(database, op);
    if (loseNextAcknowledgement) {
      loseNextAcknowledgement = false;
      throw const SyncTransportException(
        TransportFailureKind.transient,
        'acknowledgement-lost',
      );
    }
    return result;
  }
}

Future<PushResult> syntheticCommit(
  ClinicDatabase db,
  SyncOperation op,
) => db.transaction(() async {
  final fingerprint = jsonEncode([
    op.entityId,
    op.kind.name,
    op.baseRevision,
    op.payload,
  ]);
  final receipt = await db
      .customSelect(
        'SELECT * FROM demo_receipts WHERE scope=? AND id=?',
        variables: [Variable(op.scope.key), Variable(op.id)],
      )
      .get();
  if (receipt.isNotEmpty) {
    if (receipt.single.read<String>('fingerprint') != fingerprint) {
      return const Rejected('operation-id-reused');
    }
    return Accepted(receipt.single.read<int>('revision'));
  }
  final rows = await db
      .customSelect(
        'SELECT * FROM demo_remote WHERE scope=? AND id=?',
        variables: [Variable(op.scope.key), Variable(op.entityId)],
      )
      .get();
  final revision = rows.isEmpty ? 0 : rows.single.read<int>('revision');
  if (revision != op.baseRevision) {
    final value = rows.isEmpty
        ? null
        : rows.single.readNullable<String>('payload');
    return Conflicted(
      revision,
      value == null
          ? null
          : Map<String, Object?>.from(jsonDecode(value) as Map),
    );
  }
  final next = revision + 1;
  await db.customStatement(
    '''INSERT INTO demo_remote(scope,id,revision,payload) VALUES(?,?,?,?)
    ON CONFLICT(scope,id) DO UPDATE SET revision=excluded.revision,payload=excluded.payload''',
    [
      op.scope.key,
      op.entityId,
      next,
      op.kind == MutationKind.delete ? null : jsonEncode(op.payload),
    ],
  );
  await db.customStatement(
    'INSERT INTO demo_receipts(scope,id,fingerprint,revision) VALUES(?,?,?,?)',
    [op.scope.key, op.id, fingerprint, next],
  );
  return Accepted(next);
});
