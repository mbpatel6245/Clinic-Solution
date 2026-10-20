import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../services/firestore_services.dart';

class PracticeQueuePanel extends StatefulWidget {
  const PracticeQueuePanel({super.key, required this.onQueue, this.onBook});
  final VoidCallback onQueue;
  final VoidCallback? onBook;
  @override
  State<PracticeQueuePanel> createState() => _PracticeQueuePanelState();
}

class _PracticeQueuePanelState extends State<PracticeQueuePanel> {
  late final _appointments = context
      .read<FirebaseFireStore>()
      .streamAppointments();
  bool _recent = false;
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    return StreamBuilder<List<AppointmentModel>>(
      stream: _appointments,
      builder: (context, snapshot) {
        final now = DateTime.now();
        final items =
            (snapshot.data ?? [])
                .where(
                  (item) => _recent
                      ? item.status == 'completed'
                      : item.status == 'confirmed' &&
                            DateUtils.isSameDay(item.scheduledAt, now),
                )
                .toList()
              ..sort(
                (a, b) => _recent
                    ? b.scheduledAt.compareTo(a.scheduledAt)
                    : a.scheduledAt.compareTo(b.scheduledAt),
              );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _recent = false),
                      style: TextButton.styleFrom(
                        backgroundColor: !_recent ? AppColors.soft : null,
                      ),
                      child: Text(l.text('live')),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _recent = true),
                      style: TextButton.styleFrom(
                        backgroundColor: _recent ? AppColors.soft : null,
                      ),
                      child: Text(l.text('activity')),
                    ),
                  ),
                ],
              ),
            ),
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.text('loadError')),
              )
            else if (!snapshot.hasData)
              const LinearProgressIndicator()
            else
              Expanded(
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 24),
                            const Icon(
                              Icons.people_outline,
                              color: AppColors.inkMuted,
                              size: 30,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l.text(_recent ? 'noActivity' : 'noQueue'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            if (widget.onBook != null) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: widget.onBook,
                                icon: const Icon(
                                  Icons.event_outlined,
                                  size: 16,
                                ),
                                label: Text(l.text('bookNav')),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          for (final item in items.take(15))
                            ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 14,
                                child: Icon(Icons.person_outline, size: 16),
                              ),
                              title: Text(item.patientName),
                              subtitle: Text(
                                DateFormat.jm(
                                  Localizations.localeOf(context).toString(),
                                ).format(item.scheduledAt),
                              ),
                              onTap: widget.onQueue,
                            ),
                        ],
                      ),
              ),
          ],
        );
      },
    );
  }
}
