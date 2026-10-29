import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../data/datasources/enterprise_models.dart';
import '../../../ui/widgets/app_design.dart';
import '../../patients/presentation/patient_labels.dart';
import '../application/booking_sync.dart';
import '../data/booking_outbox_store.dart';
import '../data/operational_repository.dart';
import 'operational_schedule.dart';

class DurableBookingWorkspace extends StatefulWidget {
  const DurableBookingWorkspace({
    super.key,
    required this.clinic,
    required this.scope,
    required this.repository,
    required this.patients,
    required this.authorized,
    required this.authorizationChanges,
    this.ownDoctorId,
  });
  final ClinicProfile clinic;
  final String scope;
  final OperationalRepository repository;
  final Stream<List<PatientModel>> patients;
  final bool Function() authorized;
  final Listenable authorizationChanges;
  final String? ownDoctorId;
  @override
  State<DurableBookingWorkspace> createState() =>
      _DurableBookingWorkspaceState();
}

class _DurableBookingWorkspaceState extends State<DurableBookingWorkspace>
    with WidgetsBindingObserver {
  late final store = BookingOutboxStore.open();
  final password = TextEditingController();
  BookingSync? sync;
  CachedOperationalRepository? cached;
  Stream<List<PatientModel>>? patients;
  bool busy = false, failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> unlock() async {
    if (busy || password.text.length < 16 || !widget.authorized()) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final vault = await store.unlock(widget.scope, password.text);
      password.clear();
      if (!mounted || !widget.authorized()) {
        vault.lock();
        return;
      }
      final repository = CachedOperationalRepository(widget.repository, vault);
      final worker = BookingSync(
        vault: vault,
        remote: widget.repository,
        authorized: widget.authorized,
      );
      setState(() {
        sync = worker;
        cached = repository;
        patients = repository
            .patients(widget.patients)
            .asBroadcastStream(
              onCancel: (subscription) => subscription.cancel(),
            );
      });
      worker.start();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(sync?.synchronize() ?? Future.value());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sync?.dispose();
    password.dispose();
    unawaited(store.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = PatientLabels.of(context);
    return ListenableBuilder(
      listenable: widget.authorizationChanges,
      builder: (context, _) => !widget.authorized()
          ? Center(child: Text(l('scopeChanged')))
          : sync == null
          ? AppPage(
              child: AppSection(
                title: l('unlockBookings'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l('bookingUnlockHint')),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('booking-passphrase'),
                      controller: password,
                      obscureText: true,
                      enabled: !busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l('draftPassphrase'),
                      ),
                      onSubmitted: (_) => unlock(),
                    ),
                    const SizedBox(height: 16),
                    if (failed) Text(l('bookingUnlockError')),
                    FilledButton(
                      onPressed: busy ? null : unlock,
                      child: Text(l(busy ? 'saving' : 'unlockBookings')),
                    ),
                  ],
                ),
              ),
            )
          : OperationalScheduleView(
              clinic: widget.clinic,
              repository: cached!,
              patients: patients!,
              ownDoctorId: widget.ownDoctorId,
              sync: sync,
            ),
    );
  }
}

class BookingSyncStatus extends StatelessWidget {
  const BookingSyncStatus({super.key, required this.sync});
  final BookingSync sync;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sync,
    builder: (context, _) {
      final l = PatientLabels.of(context), items = sync.requests;
      return AppSection(
        title: l('bookingSync'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l('queuedHint')),
            if (sync.unavailable) Text(l('localBookingError')),
            for (final state in [
              'pending',
              'uncertain',
              'paused',
              'rejected',
              'confirmed',
            ])
              if (items.any((r) => r.state == state))
                Text(
                  '${l('request_$state')}: ${items.where((r) => r.state == state).length}',
                ),
            ExpansionTile(
              title: Text(l('reviewRequests')),
              tilePadding: EdgeInsets.zero,
              children: [
                for (final request in items.reversed.take(20))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${request.command['start']} · ${request.command['duration']} ${l('minutes')}',
                    ),
                    subtitle: Text(
                      '${l('request_${request.state}')} · ${request.id}',
                    ),
                  ),
              ],
            ),
            OutlinedButton(onPressed: sync.retry, child: Text(l('retry'))),
          ],
        ),
      );
    },
  );
}
