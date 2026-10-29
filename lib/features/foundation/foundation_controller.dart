import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/domain/clinic_scope.dart';
import '../../core/persistence/clinic_database.dart';
import '../../core/sync/sync_contract.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/synthetic_sync_transport.dart';
import '../patients/data/offline_patient_repository.dart';
import '../patients/domain/patient_repository.dart';

String foundationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Preview-only composition. All records are generated synthetic fixtures.
final class FoundationController extends ChangeNotifier {
  FoundationController({required this.database, required this.remoteDatabase}) {
    repository = OfflinePatientRepository(
      database: database,
      scope: scope,
      newId: foundationId,
    );
    transport = SyntheticSyncTransport(remoteDatabase);
    engine = SyncEngine(
      database: database,
      scope: scope,
      transport: transport,
      workerId: foundationId(),
    );
  }
  final ClinicDatabase database, remoteDatabase;
  final scope = ClinicScope(
    projectId: 'demo-uvilo-foundation',
    userId: 'demo-staff',
    clinicId: 'demo-clinic',
  );
  late final OfflinePatientRepository repository;
  late final SyntheticSyncTransport transport;
  late final SyncEngine engine;
  List<PatientRecord> records = [];
  List<SyncOperation> operations = [];
  bool loading = true, busy = false, _disposed = false;
  String? error;
  StreamSubscription<void>? _subscription;
  Timer? _refreshTimer;
  int _generation = 0;
  Future<void>? _action, _shutdown;
  final Set<Future<void>> _reads = {};

  Future<void> initialize() async {
    _subscription = database.changes.listen((_) => unawaited(refresh()));
    await refresh();
    if (_disposed) return;
    engine.start();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(refresh()),
    );
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    late final Future<void> read;
    read = _refresh().whenComplete(() => _reads.remove(read));
    _reads.add(read);
    return read;
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    try {
      final loaded = await repository.list();
      final queued = await database.operations(scope);
      if (_disposed || generation != _generation) return;
      records = loaded;
      operations = queued;
      error = null;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error =
            'Local storage could not be opened. Retry or check browser persistence.';
      }
    }
    if (_disposed || generation != _generation) return;
    loading = false;
    notifyListeners();
  }

  Future<void> perform(Future<void> Function() action) {
    if (_disposed) return Future.value();
    return _action ??= _perform(action).whenComplete(() => _action = null);
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    String? failure;
    try {
      await action();
    } catch (_) {
      failure =
          'The change could not be saved. Resolve any pending change, then retry.';
    }
    await refresh();
    if (_disposed) return;
    busy = false;
    error = failure ?? error;
    notifyListeners();
  }

  Future<void> addSample() => perform(() async {
    final id = foundationId();
    await repository.save(
      PatientProfile(
        id: id,
        firstName: 'Demo patient',
        lastName: id.substring(0, 6),
      ),
    );
    unawaited(engine.synchronize(force: true));
  });
  Future<void> updateSample(PatientRecord row) => perform(() async {
    await repository.save(
      PatientProfile(
        id: row.patient.id,
        firstName: 'Updated demo',
        lastName: row.patient.lastName,
      ),
    );
    unawaited(engine.synchronize(force: true));
  });
  Future<void> removeSample(PatientRecord row) => perform(() async {
    await repository.remove(row.patient.id);
    unawaited(engine.synchronize(force: true));
  });
  Future<void> setOnline(bool value) => perform(() async {
    transport.online = value;
    if (value) await engine.synchronize(force: true);
  });
  Future<void> syncNow() => perform(() => engine.synchronize(force: true));
  Future<void> resolve(SyncOperation op, bool keepLocal) => perform(() async {
    await database.resolveConflict(
      op,
      keepLocal: keepLocal,
      newOperationId: foundationId(),
    );
    await engine.synchronize(force: true);
  });
  Future<void> shutdown() => _shutdown ??= _close();
  Future<void> _close() async {
    _disposed = true;
    ++_generation;
    _refreshTimer?.cancel();
    await _subscription?.cancel();
    await engine.dispose();
    await _action;
    await Future.wait(_reads.toList());
    await database.close();
    await remoteDatabase.close();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}
