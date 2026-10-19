import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../widgets/app_design.dart';

enum QueueStage { scheduled, live, done, cancelled, noShow }

List<AppointmentModel> filterQueue(
  List<AppointmentModel> items,
  DateTime day,
  QueueStage stage,
  String search,
) {
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  final query = search.trim().toLowerCase();
  return items.where((item) {
    final matchesStage = switch (stage) {
      QueueStage.scheduled =>
        item.status == 'booked' || item.status == 'pending',
      QueueStage.live => item.status == 'confirmed',
      QueueStage.done => item.status == 'completed',
      QueueStage.cancelled => item.status == 'cancelled',
      QueueStage.noShow => item.status == 'no_show',
    };
    return !item.scheduledAt.isBefore(start) &&
        item.scheduledAt.isBefore(end) &&
        matchesStage &&
        '${item.patientName} ${item.phone}'.toLowerCase().contains(query);
  }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
}

class QueueWorkspace extends StatefulWidget {
  const QueueWorkspace({
    super.key,
    required this.items,
    this.onRegister,
    required this.onAction,
    this.canPrescribe = false,
    this.loading = false,
    this.hasError = false,
    this.now,
  });
  final List<AppointmentModel> items;
  final VoidCallback? onRegister;
  final Future<void> Function(AppointmentModel, String) onAction;
  final bool canPrescribe, loading, hasError;
  final DateTime? now;
  @override
  State<QueueWorkspace> createState() => _QueueWorkspaceState();
}

class _QueueWorkspaceState extends State<QueueWorkspace> {
  QueueStage _stage = QueueStage.live;
  String _query = '';
  final _busy = <String>{};
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final now = widget.now ?? DateTime.now();
    final items = filterQueue(widget.items, now, _stage, _query);
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                l.text('queue'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (widget.onRegister != null)
                FilledButton.icon(
                  onPressed: widget.onRegister,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(l.text('walkIn')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.text('queueHint'),
            style: const TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat.yMMMMEEEEd(
              Localizations.localeOf(context).toString(),
            ).format(now),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.text('search'),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stage in QueueStage.values)
                ChoiceChip(
                  label: Text(
                    '${l.text(stage.name)} (${filterQueue(widget.items, now, stage, '').length})',
                  ),
                  selected: _stage == stage,
                  onSelected: (_) => setState(() => _stage = stage),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (widget.loading)
            const LinearProgressIndicator()
          else if (widget.hasError)
            AppSection(child: Text(l.text('loadError')))
          else if (items.isEmpty)
            AppSection(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      size: 40,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(l.text('noQueue')),
                  ],
                ),
              ),
            )
          else
            for (final item in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.patientName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            [
                              DateFormat.jm(
                                Localizations.localeOf(context).toString(),
                              ).format(item.scheduledAt),
                              if (item.phone.isNotEmpty) item.phone,
                            ].join(' · '),
                          ),
                          if (item.reason.isNotEmpty) Text(item.reason),
                        ],
                      ),
                      if (_busy.contains(item.id))
                        const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_stage == QueueStage.scheduled)
                              FilledButton.tonal(
                                onPressed: () => _action(item, 'confirmed'),
                                child: Text(l.text('checkIn')),
                              ),
                            if (_stage == QueueStage.live &&
                                widget.canPrescribe)
                              FilledButton(
                                onPressed: () => _action(item, 'prescribe'),
                                child: Text(l.text('startVisit')),
                              ),
                            if (_stage == QueueStage.live)
                              OutlinedButton(
                                onPressed: () => _action(item, 'completed'),
                                child: Text(l.text('done')),
                              ),
                            if (_stage == QueueStage.live ||
                                _stage == QueueStage.scheduled)
                              PopupMenuButton<String>(
                                onSelected: (action) => _action(item, action),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'cancelled',
                                    child: Text(l.text('cancelled')),
                                  ),
                                  PopupMenuItem(
                                    value: 'no_show',
                                    child: Text(l.text('noShow')),
                                  ),
                                ],
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _action(AppointmentModel item, String action) async {
    setState(() => _busy.add(item.id));
    try {
      await widget.onAction(item, action);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(RevampLabels.of(context).text('saveError'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }
}
