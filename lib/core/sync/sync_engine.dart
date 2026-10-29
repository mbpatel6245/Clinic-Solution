import 'dart:async';
import 'dart:math';
import '../domain/clinic_scope.dart';
import '../persistence/clinic_database.dart';
import 'sync_contract.dart';

/// Scoped single writer. dispose() prevents in-flight responses being applied.
/// A network timeout keeps the original operation ID for receipt reconciliation.
final class SyncEngine {
  SyncEngine({
    required this.database,
    required this.scope,
    required this.transport,
    required this.workerId,
    this.changeSource,
    DateTime Function()? clock,
    int Function(int)? jitter,
    this.requestTimeout = const Duration(seconds: 20),
  }) : clock = clock ?? DateTime.now,
       jitter = jitter ?? Random().nextInt {
    if (requestTimeout >= const Duration(seconds: 50)) {
      throw ArgumentError('Request timeout must be shorter than the lease.');
    }
  }
  final ClinicDatabase database;
  final ClinicScope scope;
  final SyncTransport transport;
  final PatientChangeSource? changeSource;
  final String workerId;
  final DateTime Function() clock;
  final int Function(int) jitter;
  final Duration requestTimeout;
  Timer? _timer;
  Future<void>? _running;
  bool _disposed = false;
  String? lastErrorCode;
  DateTime? lastDownloadAt, lastUploadAt;

  void start({Duration interval = const Duration(seconds: 15)}) {
    if (_disposed || _timer != null) return;
    if (interval < const Duration(seconds: 1)) {
      throw ArgumentError('Invalid sync interval.');
    }
    _timer = Timer.periodic(interval, (_) => unawaited(synchronize()));
    unawaited(synchronize());
  }

  Future<void> synchronize({bool force = false}) {
    if (_disposed) return Future.value();
    return _running ??= _drain(force).whenComplete(() => _running = null);
  }

  Future<void> _drain(bool force) async {
    var leased = false;
    try {
      leased = await database.acquireLease(
        scope,
        workerId,
        clock().millisecondsSinceEpoch,
      );
      if (!leased || _disposed) return;
      lastErrorCode = null;
      final operations = await database.operations(scope);
      for (final op in operations) {
        if (_disposed) return;
        if (op.state != DeliveryState.pending ||
            (!force && op.nextAttemptAt > clock().millisecondsSinceEpoch)) {
          continue;
        }
        if (!await database.acquireLease(
          scope,
          workerId,
          clock().millisecondsSinceEpoch,
        )) {
          return;
        }
        try {
          final response = await transport.push(op).timeout(requestTimeout);
          if (_disposed) return;
          switch (response) {
            case Accepted(:final revision):
              await database.accept(op, revision);
              lastUploadAt = clock();
            case Conflicted(:final revision, :final serverPayload):
              if (revision < 0) throw const FormatException('Invalid revision');
              await database.defer(
                op,
                state: DeliveryState.conflict,
                code: 'revision-conflict',
                nextAttempt: 0,
                remoteRevision: revision,
                remotePayload: serverPayload,
              );
            case Rejected(:final code):
              await database.defer(
                op,
                state: DeliveryState.rejected,
                code: code,
                nextAttempt: 0,
              );
          }
        } on SyncTransportException catch (error) {
          if (_disposed) return;
          await _failed(op, error.kind, error.code);
          // One unavailable/expired connection applies to this entire run.
          if (error.kind != TransportFailureKind.permanent) return;
        } on TimeoutException {
          if (_disposed) return;
          await _failed(op, TransportFailureKind.transient, 'timeout');
          return;
        } on FormatException {
          if (_disposed) return;
          await _failed(op, TransportFailureKind.permanent, 'invalid-response');
          return;
        }
      }
      if (!_disposed && changeSource != null) {
        if (!await database.acquireLease(
          scope,
          workerId,
          clock().millisecondsSinceEpoch,
        )) {
          return;
        }
        final cursor = await database.cursor(scope);
        final page = await changeSource!
            .pull(scope, cursor)
            .timeout(requestTimeout);
        if (_disposed) return;
        await database.applyPage(scope, page);
        lastDownloadAt = clock();
      }
    } on SyncTransportException catch (error) {
      lastErrorCode = error.code;
    } on TimeoutException {
      lastErrorCode = 'timeout';
    } catch (_) {
      // Durable operations remain available. Do not leak storage/server bodies.
      lastErrorCode = 'sync-unavailable';
    } finally {
      if (leased) await database.releaseLease(scope, workerId);
    }
  }

  Future<void> _failed(
    SyncOperation op,
    TransportFailureKind kind,
    String code,
  ) async {
    lastErrorCode = code;
    final delay = min(300, 2 << min(op.attempts, 7)) * 1000 + jitter(1000);
    await database.defer(
      op,
      state: switch (kind) {
        TransportFailureKind.transient => DeliveryState.pending,
        TransportFailureKind.authentication =>
          DeliveryState.authenticationRequired,
        TransportFailureKind.permanent => DeliveryState.rejected,
      },
      code: code,
      nextAttempt: clock().millisecondsSinceEpoch + delay,
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _running;
  }
}
