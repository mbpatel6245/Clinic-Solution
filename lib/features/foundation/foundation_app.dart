import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/uvilo_theme.dart';
import '../../core/persistence/open_clinic_database.dart';
import '../../core/sync/sync_contract.dart';
import '../../shared/presentation/adaptive_workspace.dart';
import '../patients/domain/patient_repository.dart';
import 'foundation_controller.dart';

/// Separately launched sandbox. Never initializes Firebase or accepts real PHI.
class FoundationApp extends StatefulWidget {
  const FoundationApp({super.key});
  @override
  State<FoundationApp> createState() => _FoundationAppState();
}

class _FoundationAppState extends State<FoundationApp>
    with WidgetsBindingObserver {
  late final FoundationController controller;
  String persistence = 'Native SQLite · local files', selected = 'patients';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = FoundationController(
      database: openFoundationDatabase(
        onPersistence: (mode, durable) {
          if (mounted) {
            setState(
              () => persistence = durable
                  ? 'Browser storage · $mode'
                  : 'Memory only · changes will not survive closing',
            );
          }
        },
      ),
      remoteDatabase: openFoundationDatabase(
        name: 'uvilo_foundation_synthetic_server_v1',
      ),
    );
    controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: controller,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Uvilo foundation sandbox',
      theme: UviloTheme.light,
      home: Consumer<FoundationController>(
        builder: (context, state, _) => AdaptiveWorkspace(
          title: 'Foundation sandbox',
          clinicLabel: 'Demo clinic · Synthetic data only',
          selectedId: selected,
          onSelect: (value) => setState(() => selected = value),
          destinations: const [
            WorkspaceDestination(
              id: 'patients',
              label: 'Patients',
              icon: Icons.people_outline,
            ),
            WorkspaceDestination(
              id: 'sync',
              label: 'Synchronization',
              icon: Icons.sync,
            ),
            WorkspaceDestination(
              id: 'about',
              label: 'Foundation',
              icon: Icons.layers_outlined,
            ),
          ],
          actions: [
            FilledButton.icon(
              onPressed: state.busy ? null : state.addSample,
              icon: const Icon(Icons.add),
              label: const Text('Add demo patient'),
            ),
          ],
          child: AdaptiveContent(
            primary: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(switch (selected) {
                  'sync' => 'Changes on this device',
                  'about' => 'A shared Flutter foundation',
                  _ => 'Patient directory',
                }, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                  'Phase 1 preview. Generated demo records only; no Firebase connection, notifications or real patient data.',
                ),
                const SizedBox(height: 24),
                if (state.error != null)
                  _panel(context, 'Storage needs attention', [
                    Text(state.error!),
                    TextButton(
                      onPressed: state.refresh,
                      child: const Text('Retry'),
                    ),
                  ]),
                if (state.loading)
                  const Center(child: CircularProgressIndicator())
                else if (selected == 'patients')
                  _patients(context, state)
                else if (selected == 'sync')
                  _outbox(context, state)
                else
                  _panel(context, 'Available in this prototype', const [
                    Text(
                      'Responsive shell • scoped repository • transactional SQLite outbox',
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Offline create, update and delete; restart recovery; idempotent replay; explicit conflicts; isolated user and clinic data.',
                    ),
                    SizedBox(height: 12),
                    Text(
                      'The remote service here is simulated in a separate local database. Encryption, real sync endpoints, production access policy and full feature migration remain separate work.',
                    ),
                  ]),
              ],
            ),
            aside: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _panel(context, 'Connection simulation', [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Simulated server online'),
                    value: state.transport.online,
                    onChanged: state.busy ? null : state.setOnline,
                  ),
                  Text(
                    '${state.operations.length} changes awaiting confirmation',
                  ),
                  const SizedBox(height: 12),
                  Text(persistence),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.busy ? null : state.syncNow,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Turn online off, add a demo record, close and reopen this preview, then turn online on. Pending work stays on this device.',
                  ),
                ]),
                const SizedBox(height: 16),
                _panel(context, 'Save states', const [
                  Text('Saved on this device ≠ confirmed by server.'),
                  SizedBox(height: 12),
                  Text(
                    'Only confirmed rows can be edited again in this prototype. Conflicts remain visible for review.',
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _panel(BuildContext c, String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
  Widget _patients(
    BuildContext c,
    FoundationController state,
  ) => _panel(c, 'Local records', [
    if (state.records.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'No demo patients yet. Add a demo patient to test an offline save.',
        ),
      ),
    for (final record in state.records)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.patient.displayName,
                  style: Theme.of(c).textTheme.titleSmall,
                ),
                Text('Revision ${record.revision} · ${record.syncState.name}'),
              ],
            ),
            Wrap(
              children: [
                IconButton(
                  tooltip: 'Update demo patient',
                  onPressed:
                      state.busy ||
                          record.syncState != RecordSyncState.confirmed
                      ? null
                      : () => state.updateSample(record),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete demo patient',
                  onPressed:
                      state.busy ||
                          record.syncState != RecordSyncState.confirmed
                      ? null
                      : () => state.removeSample(record),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
  ]);
  Widget _outbox(
    BuildContext c,
    FoundationController state,
  ) => _panel(c, 'Pending operations', [
    if (state.operations.isEmpty)
      const Text('All local changes are confirmed by the simulated server.'),
    for (final operation in state.operations)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${operation.kind.name} · ${operation.state.name}',
              style: Theme.of(c).textTheme.titleSmall,
            ),
            Text(
              'Attempts: ${operation.attempts} · ${operation.errorCode ?? 'Waiting to send'}',
            ),
            if (operation.state == DeliveryState.conflict)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => state.resolve(operation, false),
                    child: const Text('Use server version'),
                  ),
                  OutlinedButton(
                    onPressed: state.busy
                        ? null
                        : () => state.resolve(operation, true),
                    child: const Text('Retry local draft'),
                  ),
                ],
              ),
          ],
        ),
      ),
  ]);
}
