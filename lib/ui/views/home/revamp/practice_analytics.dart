import 'package:flutter/material.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../core/design/app_theme.dart';
import '../../../widgets/app_design.dart';
import 'practice_metrics.dart';

class PracticeAnalytics extends StatelessWidget {
  const PracticeAnalytics({
    super.key,
    required this.metrics,
    required this.patientsAvailable,
    required this.visitsAvailable,
    required this.appointmentsAvailable,
  });
  final PracticeMetrics metrics;
  final bool patientsAvailable, visitsAvailable, appointmentsAvailable;
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    Widget distribution(
      String title,
      Iterable<MapEntry<String, int>> values, {
      bool localize = false,
    }) {
      final entries = values.toList();
      final maximum = entries.fold<int>(1, (m, e) => e.value > m ? e.value : m);
      return AppSection(
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${localize || entry.key == 'unspecified' ? l.text(entry.key) : entry.key}: ${entry.value}',
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: entry.value / maximum,
                      color: AppColors.primary,
                      backgroundColor: AppColors.soft,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (patientsAvailable)
          ResponsiveGrid(
            minimumItemWidth: 300,
            children: [
              distribution(
                l.text('ageDistribution'),
                metrics.ageGroups.entries,
              ),
              distribution(
                l.text('genderDistribution'),
                metrics.genders.entries,
                localize: true,
              ),
            ],
          ),
        const SizedBox(height: 16),
        if (visitsAvailable)
          AppSection(
            title: l.text('topMedicines'),
            child: metrics.medications.isEmpty
                ? Text(l.text('noActivity'))
                : Column(
                    children: [
                      for (final e in metrics.medications.take(10))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.key),
                          trailing: Text('${e.value}'),
                        ),
                    ],
                  ),
          ),
        if (appointmentsAvailable) ...[
          const SizedBox(height: 16),
          AppSection(
            title: l.text('attendance'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.text('attendanceHint')),
                const SizedBox(height: 12),
                Text(
                  metrics.noShowRate == null
                      ? '—'
                      : '${(metrics.noShowRate! * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
