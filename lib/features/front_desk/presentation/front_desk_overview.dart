import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/app_role.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../core/design/revamp_labels.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../data/datasources/enterprise_models.dart';
import '../../../data/datasources/patient_intake.dart';
import '../../../ui/widgets/app_design.dart';
import 'front_desk_components.dart';

class FrontDeskOverview extends StatelessWidget {
  const FrontDeskOverview({
    super.key,
    required this.appointments,
    required this.invoices,
    required this.available,
    required this.onOpen,
    required this.clinic,
    this.unavailable = const {},
    this.displayName = '',
    this.now,
  });
  final List<AppointmentModel> appointments;
  final List<ClinicInvoice> invoices;
  final Set<AppFeature> available;
  final Set<String> unavailable;
  final ValueChanged<AppFeature> onOpen;
  final ClinicProfile clinic;
  final String displayName;
  final DateTime? now;
  @override
  Widget build(BuildContext context) {
    final d = DeskLabels.of(context),
        l = RevampLabels.of(context),
        day = now ?? DateTime.now();
    final rows = deskDay(appointments, clinic, day),
        waiting = rows.where((a) => a.status == 'confirmed').toList();
    final todaysInvoices = invoices
        .where((i) => ClinicSchedule.sameDay(clinic, i.issuedAt, day))
        .toList();
    final activity = rows.where((a) => a.arrivalAt != null).toList()
      ..sort((a, b) => b.arrivalAt!.compareTo(a.arrivalAt!));
    String money(double value) => NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toString(),
      name: clinic.currency,
      decimalDigits: 0,
    ).format(value);
    String value(String source, String text) =>
        unavailable.contains(source) ? '—' : text;
    Widget open(String label, AppFeature feature, String icon) =>
        OutlinedButton.icon(
          onPressed: available.contains(feature) ? () => onOpen(feature) : null,
          icon: DeskIcon(icon, size: 16),
          label: Text(label),
        );
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeskPanel(
          title: d('todayAppointments'),
          trailing: available.contains(AppFeature.appointments)
              ? TextButton(
                  onPressed: () => onOpen(AppFeature.appointments),
                  child: Text('${d('calendar')} →'),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (unavailable.contains('appointments'))
                Text(l.text('loadError'))
              else if (rows.isEmpty)
                Text(l.text('noQueue'))
              else
                DeskAppointmentTable(
                  items: rows,
                  clinic: clinic,
                  onSelect: available.contains(AppFeature.reception)
                      ? (_) => onOpen(AppFeature.reception)
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        DeskPanel(
          title: d('activity'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (unavailable.contains('appointments'))
                Text(l.text('loadError'))
              else if (activity.isEmpty)
                Text(d('noActivity'))
              else
                for (final a in activity.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DeskIcon('imgClock'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${deskTime(context, clinic, a.arrivalAt!)} · ${a.patientName} · ${l.text('live')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: UviloTheme.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeskPanel(
          title: d('liveQueue'),
          soft: true,
          trailing: Text(value('appointments', '${waiting.length}')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (unavailable.contains('appointments'))
                Text(l.text('loadError'))
              else if (waiting.isEmpty)
                Text(l.text('noQueue'))
              else
                for (final a in waiting.take(2)) ...[
                  Text(
                    a.patientName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.practitionerName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: UviloTheme.muted,
                    ),
                  ),
                  Text(
                    a.arrivalAt == null
                        ? d('notRecorded')
                        : deskTime(context, clinic, a.arrivalAt!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: UviloTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              if (available.contains(AppFeature.reception))
                open(d('viewArrival'), AppFeature.reception, 'imgArrowRight'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        DeskPanel(
          title: d('tasks'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (available.contains(AppFeature.reception))
                open(d('reviewArrivals'), AppFeature.reception, 'imgSquare'),
              if (available.contains(AppFeature.billing))
                open(d('reviewBalance'), AppFeature.billing, 'imgSquare'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        DeskPanel(
          title: d('quick'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (available.contains(AppFeature.patients))
                open(d('register'), AppFeature.patients, 'imgUserPlus'),
              const SizedBox(height: 12),
              if (available.contains(AppFeature.billing))
                open(d('invoice'), AppFeature.billing, 'imgReceiptIndianRupee'),
              const SizedBox(height: 12),
              if (available.contains(AppFeature.appointments))
                open(d('schedule'), AppFeature.appointments, 'imgCalendar'),
            ],
          ),
        ),
      ],
    );
    return Theme(
      data: UviloTheme.light,
      child: AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 24,
              runSpacing: 12,
              children: [
                Text(
                  d('heading'),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (available.contains(AppFeature.appointments))
                  open(d('schedule'), AppFeature.appointments, 'imgPlus'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$displayName · ${clinic.name} · ${DateFormat.yMMMEd(Localizations.localeOf(context).toString()).format(ClinicSchedule.local(clinic, day))}',
              style: const TextStyle(color: UviloTheme.muted),
            ),
            const SizedBox(height: 24),
            DeskMetrics(
              values: [
                (d('today'), value('appointments', '${rows.length}')),
                (d('waiting'), value('appointments', '${waiting.length}')),
                if (available.contains(AppFeature.billing))
                  ...([
                    (
                      d('collected'),
                      value(
                        'invoices',
                        money(
                          todaysInvoices.fold(0.0, (v, i) => v + i.amountPaid),
                        ),
                      ),
                    ),
                    (
                      d('outstanding'),
                      value(
                        'invoices',
                        money(
                          todaysInvoices.fold(0.0, (v, i) => v + i.balance),
                        ),
                      ),
                    ),
                  ]),
              ],
            ),
            const SizedBox(height: 24),
            DeskColumns(main: main, side: side),
            const SizedBox(height: 24),
            Text(
              d('footer'),
              style: const TextStyle(fontSize: 10, color: UviloTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
