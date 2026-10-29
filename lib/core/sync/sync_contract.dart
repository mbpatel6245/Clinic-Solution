import '../domain/clinic_scope.dart';

enum MutationKind { put, delete }

enum DeliveryState { pending, conflict, rejected, authenticationRequired }

final class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.scope,
    required this.entityId,
    required this.kind,
    required this.payload,
    required this.baseRevision,
    this.attempts = 0,
    this.nextAttemptAt = 0,
    this.state = DeliveryState.pending,
    this.errorCode,
    this.remoteRevision,
    this.remotePayload,
  });
  final String id, entityId;
  final ClinicScope scope;
  final MutationKind kind;
  final Map<String, Object?> payload;
  final int baseRevision, attempts, nextAttemptAt;
  final DeliveryState state;
  final String? errorCode;
  final int? remoteRevision;
  final Map<String, Object?>? remotePayload;
}

sealed class PushResult {
  const PushResult();
}

final class Accepted extends PushResult {
  const Accepted(this.revision);
  final int revision;
}

final class Conflicted extends PushResult {
  const Conflicted(this.revision, this.serverPayload);
  final int revision;
  final Map<String, Object?>? serverPayload;
}

final class Rejected extends PushResult {
  const Rejected(this.code);
  final String code;
}

enum TransportFailureKind { transient, authentication, permanent }

final class SyncTransportException implements Exception {
  const SyncTransportException(this.kind, this.code);
  final TransportFailureKind kind;

  /// Sanitized machine code only; no server bodies, tokens or patient data.
  final String code;
  @override
  String toString() => 'SyncTransportException($code)';
}

/// Implementations must enforce scope, base revision and idempotency on server.
/// They must return the original receipt when an operation ID is replayed.
abstract interface class SyncTransport {
  Future<PushResult> push(SyncOperation operation);
}

final class RemotePatient {
  const RemotePatient(this.id, this.revision, this.payload);
  final String id;
  final int revision;

  /// Null is an explicit tombstone, not an omitted page result.
  final Map<String, Object?>? payload;
}

final class ChangePage {
  const ChangePage({required this.records, required this.cursor});
  final List<RemotePatient> records;
  final String cursor;
}

abstract interface class PatientChangeSource {
  Future<ChangePage> pull(ClinicScope scope, String? cursor);
}
