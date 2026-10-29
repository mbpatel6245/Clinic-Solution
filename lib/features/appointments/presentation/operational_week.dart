import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../data/datasources/enterprise_models.dart';
import '../../../data/datasources/patient_intake.dart';
import '../../patients/presentation/patient_labels.dart';

class OperationalWeek extends StatelessWidget {
  const OperationalWeek({
    super.key,
    required this.clinic,
    required this.day,
    required this.items,
    required this.onDay,
  });
  final ClinicProfile clinic;
  final DateTime day;
  final List<AppointmentModel> items;
  final ValueChanged<DateTime>? onDay;
  @override
  Widget build(BuildContext context) {
    final l = PatientLabels.of(context),
        monday = day.subtract(Duration(days: day.weekday - 1));
    final days = [
      for (var i = 0; i < 7; i++)
        if (clinic.workingDays.contains(i + 1))
          DateTime(monday.year, monday.month, monday.day + i),
    ];
    if (days.isEmpty) return Text(l('noAppointments'));
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(box.maxWidth, days.length * 150.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final date in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton(
                          onPressed: onDay == null ? null : () => onDay!(date),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: DateUtils.isSameDay(day, date)
                                ? UviloTheme.soft
                                : UviloTheme.canvas,
                          ),
                          child: Text(
                            DateFormat.MMMEd(
                              Localizations.localeOf(context).toString(),
                            ).format(date),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(minHeight: 240),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: UviloTheme.canvas,
                            border: Border.all(color: UviloTheme.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${clinic.openingTime}–${clinic.closingTime}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: UviloTheme.muted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (!items.any(
                                (a) => ClinicSchedule.sameDay(
                                  clinic,
                                  a.scheduledAt,
                                  date,
                                ),
                              ))
                                Text(
                                  l('noAppointments'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: UviloTheme.muted,
                                  ),
                                ),
                              for (final a in items.where(
                                (a) => ClinicSchedule.sameDay(
                                  clinic,
                                  a.scheduledAt,
                                  date,
                                ),
                              ))
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: UviloTheme.border,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat.jm(
                                          Localizations.localeOf(
                                            context,
                                          ).toString(),
                                        ).format(
                                          ClinicSchedule.local(
                                            clinic,
                                            a.scheduledAt,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: UviloTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        a.patientName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        a.status,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: UviloTheme.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
