import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/booking_outbox_store.dart';
import '../data/operational_repository.dart';

/// Polling and resume retry are deliberately independent of connectivity hints.
/// Only a server acknowledgement can confirm an offline request.
class BookingSync extends ChangeNotifier {
  BookingSync({
    required this.vault,
    required this.remote,
    required this.authorized,
    DateTime Function()? clock,
    String? worker,
  }) : clock = clock ?? DateTime.now,
       worker =
           worker ??
           '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
  final BookingVault vault;
  final OperationalRepository remote;
  final bool Function() authorized;
  final DateTime Function() clock;
  final String worker;
  List<BookingRequest> requests = [];
  bool unavailable = false, _disposed = false;
  Timer? _timer;
  Future<void>? _running;
  void start() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(synchronize()),
    );
    unawaited(synchronize());
  }

  Future<void> queue(Map<String, Object?> command) async {
    if (!authorized() || _disposed) {
      throw const OperationalFailure('unauthenticated');
    }
    await vault.enqueue(
      Map.of(command),
    ); // Commit before making any network call.
    await refresh();
    unawaited(synchronize());
  }

  Future<void> refresh() async {
    if (_disposed || !authorized()) return;
    final items = await vault.requests();
    if (_disposed || !authorized()) return;
    requests = items;
    notifyListeners();
  }

  Future<void> retry() async {
    if (_disposed || !authorized()) return;
    try {
      for (final request in requests.where((r) => r.state == 'paused')) {
        if (_disposed || !authorized()) return;
        await vault.resume(request.id);
      }
      await synchronize(force: true);
    } catch (_) {
      if (!_disposed) {
        unavailable = true;
        notifyListeners();
      }
    }
  }

  Future<void> synchronize({bool force = false}) {
    if (_disposed || !authorized()) return Future.value();
    return _running ??= _drain(force).whenComplete(() => _running = null);
  }

  Future<void> _drain(bool force) async {
    try {
      final items = await vault.requests();
      for (final request in items) {
        if (_disposed || !authorized()) return;
        if (!await vault.claim(
          request.id,
          worker,
          clock().millisecondsSinceEpoch,
          force: force,
        )) {
          continue;
        }
        if (_disposed || !authorized()) return;
        try {
          await remote
              .command(request.command)
              .timeout(const Duration(seconds: 25));
          if (_disposed || !authorized()) return;
          await vault.finish(request.id, worker, 'confirmed');
        } catch (error) {
          if (_disposed || !authorized()) return;
          final failure = error is OperationalFailure
              ? error
              : const OperationalFailure('unknown', unknown: true);
          final code = failure.code.toLowerCase().replaceAll('_', '-');
          final paused = [
            'unauthenticated',
            'permission-denied',
          ].contains(code);
          final retry =
              failure.unknown ||
              [
                'unavailable',
                'deadline-exceeded',
                'resource-exhausted',
                'internal',
                'unknown',
              ].contains(code);
          await vault.finish(
            request.id,
            worker,
            paused
                ? 'paused'
                : retry
                ? 'uncertain'
                : 'rejected',
            error: paused
                ? 'access'
                : retry
                ? 'network'
                : 'rejected',
            nextAttempt:
                clock().millisecondsSinceEpoch +
                min(300000, 2000 * (1 << min(request.attempts, 7))).toInt() +
                Random.secure().nextInt(1000),
          );
        }
      }
      unavailable = false;
      await refresh();
    } catch (_) {
      if (!_disposed) {
        unavailable = true;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    requests = [];
    vault.lock();
    super.dispose();
  }
}
