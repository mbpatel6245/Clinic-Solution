import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/auth/app_role.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../data/datasources/enterprise_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import '../../../widgets/app_design.dart';
import 'practice_metrics.dart';
import 'practice_analytics.dart';

/// Subscriptions follow the active role/module grants. Dashboard-only users
/// never query collections that their role cannot read.
class PracticeDashboard extends StatefulWidget {
  const PracticeDashboard({super.key, required this.onOpen});
  final ValueChanged<AppFeature> onOpen;
  @override
  State<PracticeDashboard> createState() => _PracticeDashboardState();
}

class _PracticeDashboardState extends State<PracticeDashboard> {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _errors = <String>{};
  final _pending = <String>{};
  List<PatientModel> _patients = const [];
  List<PrescriptionModel> _visits = const [];
  List<AppointmentModel> _appointments = const [];
  List<ClinicInvoice> _invoices = const [];
  List<VaccinationRecord> _vaccines = const [];
  String? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final scope =
        '${session.activeClinicId}:${AppFeature.values.where(session.can).map((e) => e.name).join(',')}';
    if (_scope == scope) return;
    _scope = scope;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _errors.clear();
    _pending.clear();
    _patients = [];
    _visits = [];
    _appointments = [];
    _invoices = [];
    _vaccines = [];
    final service = context.read<FirebaseFireStore>();
    void listen<T>(String name, Stream<T> stream, void Function(T) assign) {
      _pending.add(name);
      _subscriptions.add(
        stream.listen(
          (value) {
            if (!mounted || _scope != scope) return;
            setState(() {
              assign(value);
              _errors.remove(name);
              _pending.remove(name);
            });
          },
          onError: (Object error) {
            if (mounted && _scope == scope) {
              setState(() {
                _errors.add(name);
                _pending.remove(name);
              });
            }
          },
        ),
      );
    }

    if (session.can(AppFeature.patients)) {
      listen('patients', service.streamPatients(), (v) => _patients = v);
    }
    if (session.can(AppFeature.prescriptionList)) {
      listen('visits', service.streamPrescriptions(), (v) => _visits = v);
    }
    if (session.can(AppFeature.appointments) ||
        session.can(AppFeature.reception)) {
      listen(
        'appointments',
        service.streamAppointments(),
        (v) => _appointments = v,
      );
    }
    if (session.can(AppFeature.billing)) {
      listen('invoices', service.streamInvoices(), (v) => _invoices = v);
    }
    if (session.can(AppFeature.vaccination)) {
      listen('vaccines', service.streamVaccinations(), (v) => _vaccines = v);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return PracticeDashboardView(
      patients: _patients,
      visits: _visits,
      appointments: _appointments,
      invoices: _invoices,
      vaccines: _vaccines,
      available: AppFeature.values.where(session.can).toSet(),
      loading: _pending.isNotEmpty,
      hasError: _errors.isNotEmpty,
      unavailable: _errors.union(_pending),
      onOpen: widget.onOpen,
    );
  }
}

/// Data-only view also used by responsive previews and tests; no Firebase
/// initialization or real patient information is needed to render it.
class PracticeDashboardView extends StatefulWidget {
  const PracticeDashboardView({
    super.key,
    this.patients = const [],
    this.visits = const [],
    this.appointments = const [],
    this.invoices = const [],
    this.vaccines = const [],
    required this.available,
    required this.onOpen,
    this.loading = false,
    this.hasError = false,
    this.unavailable = const {},
    this.now,
  });
  final List<PatientModel> patients;
  final List<PrescriptionModel> visits;
  final List<AppointmentModel> appointments;
  final List<ClinicInvoice> invoices;
  final List<VaccinationRecord> vaccines;
  final Set<AppFeature> available;
  final ValueChanged<AppFeature> onOpen;
  final bool loading, hasError;
  final Set<String> unavailable;
  final DateTime? now;
  @override
  State<PracticeDashboardView> createState() => _PracticeDashboardViewState();
}

class _PracticeDashboardViewState extends State<PracticeDashboardView> {
  PracticePeriod _period = PracticePeriod.week;
  DateTimeRange? _customRange;
  bool _hidden = false;
  String _tab = 'home';

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final s = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final now = widget.now ?? DateTime.now();
    final metrics = PracticeMetrics(
      now: now,
      period: _period,
      patients: widget.patients,
      prescriptions: widget.visits,
      appointments: widget.appointments,
      invoices: widget.invoices,
      rangeStart: _customRange?.start,
      rangeEnd: _customRange?.end,
    );
    bool can(AppFeature f) => widget.available.contains(f);
    String value(String source, String text) => _hidden
        ? '••••'
        : widget.unavailable.contains(source)
        ? '—'
        : text;
    String money(double amount) => NumberFormat.simpleCurrency(
      locale: locale,
      name: 'INR',
      decimalDigits: 0,
    ).format(amount);
    final tabs = [
      'home',
      if (can(AppFeature.patients) || can(AppFeature.prescriptionList))
        'analytics',
      if (can(AppFeature.billing)) 'payments',
      if (can(AppFeature.prescriptionList)) 'activity',
      if (can(AppFeature.vaccination)) 'vaccines',
    ];
    final selectedTab = tabs.contains(_tab) ? _tab : 'home';
    final periodLabel = _customRange == null
        ? l.text(_period.name)
        : '${DateFormat.yMMMd(locale).format(_customRange!.start)} – ${DateFormat.yMMMd(locale).format(_customRange!.end)}';
    final cards = <Widget>[
      if (can(AppFeature.patients))
        AppMetricCard(
          label: l.text('registered'),
          value: value('patients', '${widget.patients.length}'),
          caption: l.text('allTime'),
          icon: Icons.people_outline,
        ),
      if (can(AppFeature.prescriptionList))
        AppMetricCard(
          label: l.text('consultations'),
          value: value('visits', '${metrics.visits.length}'),
          caption: periodLabel,
          icon: Icons.medical_services_outlined,
        ),
      if (can(AppFeature.appointments) || can(AppFeature.reception))
        AppMetricCard(
          label: s.appointments,
          value: value('appointments', '${metrics.bookings}'),
          caption: periodLabel,
          icon: Icons.calendar_month_outlined,
        ),
      if (can(AppFeature.patients))
        AppMetricCard(
          label: l.text('newPatients'),
          value: value('patients', '${metrics.newPatients}'),
          caption: periodLabel,
          icon: Icons.person_add_alt_outlined,
        ),
      if (can(AppFeature.billing))
        AppMetricCard(
          label: l.text('collected'),
          value: value('invoices', money(metrics.collected)),
          caption: periodLabel,
          icon: Icons.payments_outlined,
        ),
      if (can(AppFeature.billing))
        AppMetricCard(
          label: l.text('outstanding'),
          value: value('invoices', money(metrics.outstanding)),
          caption: l.text('allTime'),
          icon: Icons.receipt_long_outlined,
        ),
    ];
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMMEEEEd(locale).format(now),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.text('welcome'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.text('welcomeHint'),
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                ],
              ),
              if (can(AppFeature.createPrescription))
                FilledButton.icon(
                  onPressed: () => widget.onOpen(AppFeature.createPrescription),
                  icon: const Icon(Icons.add),
                  label: Text(s.newVisit),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final period in PracticePeriod.values)
                ChoiceChip(
                  label: Text(l.text(period.name)),
                  selected: _period == period && _customRange == null,
                  onSelected: (_) => setState(() {
                    _period = period;
                    _customRange = null;
                  }),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final dates = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    initialDateRange: _customRange,
                  );
                  if (dates != null && mounted) {
                    setState(() => _customRange = dates);
                  }
                },
                icon: const Icon(Icons.date_range_outlined),
                label: Text(l.text('customRange')),
              ),
              IconButton(
                tooltip: l.text(_hidden ? 'show' : 'hide'),
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          if (widget.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l.text('loadError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          if (cards.isNotEmpty)
            ResponsiveGrid(minimumItemWidth: 225, children: cards),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tab in tabs)
                ChoiceChip(
                  label: Text(l.text(tab)),
                  selected: selectedTab == tab,
                  onSelected: (_) => setState(() => _tab = tab),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_hidden)
            const AppSection(
              child: Center(
                child: Icon(Icons.visibility_off_outlined, size: 36),
              ),
            )
          else if (selectedTab == 'home') ...[
            if (can(AppFeature.prescriptionList))
              LayoutBuilder(
                builder: (context, constraints) {
                  final trend = AppSection(
                    title: l.text('visitsTrend'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.text('lastSeven'),
                          style: const TextStyle(color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: 20),
                        if (widget.unavailable.contains('visits'))
                          const Text('—')
                        else
                          ConsultationChart(days: metrics.dailyVisits),
                        if (widget.visits.isEmpty &&
                            !widget.unavailable.contains('visits'))
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(l.text('noVisits')),
                          ),
                      ],
                    ),
                  );
                  final diagnoses = AppSection(
                    title: l.text('diagnoses'),
                    child: widget.unavailable.contains('visits')
                        ? const Text('—')
                        : metrics.diagnoses.isEmpty
                        ? Text(l.text('noDiagnoses'))
                        : Column(
                            children: [
                              for (final entry in metrics.diagnoses.take(5))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.key),
                                  trailing: Text('${entry.value}'),
                                ),
                            ],
                          ),
                  );
                  if (constraints.maxWidth < 900) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [trend, const SizedBox(height: 16), diagnoses],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: trend),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: diagnoses),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            AppSection(
              title: l.text('quickActions'),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (can(AppFeature.reception))
                    OutlinedButton.icon(
                      onPressed: () => widget.onOpen(AppFeature.reception),
                      icon: const Icon(Icons.how_to_reg_outlined),
                      label: Text(l.text('queue')),
                    ),
                  if (can(AppFeature.appointments))
                    OutlinedButton.icon(
                      onPressed: () => widget.onOpen(AppFeature.appointments),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(s.bookAppointment),
                    ),
                  if (can(AppFeature.patients))
                    OutlinedButton.icon(
                      onPressed: () => widget.onOpen(AppFeature.patients),
                      icon: const Icon(Icons.people_outline),
                      label: Text(l.text('patients')),
                    ),
                  if (can(AppFeature.reminders))
                    OutlinedButton.icon(
                      onPressed: () => widget.onOpen(AppFeature.reminders),
                      icon: const Icon(Icons.notifications_none),
                      label: Text(l.text('reminders')),
                    ),
                ],
              ),
            ),
          ] else if (selectedTab == 'analytics')
            PracticeAnalytics(
              metrics: metrics,
              patientsAvailable:
                  can(AppFeature.patients) &&
                  !widget.unavailable.contains('patients'),
              visitsAvailable:
                  can(AppFeature.prescriptionList) &&
                  !widget.unavailable.contains('visits'),
              appointmentsAvailable:
                  (can(AppFeature.appointments) || can(AppFeature.reception)) &&
                  !widget.unavailable.contains('appointments'),
            )
          else if (selectedTab == 'payments')
            AppSection(
              title: l.text('payments'),
              child: widget.unavailable.contains('invoices')
                  ? const Text('—')
                  : metrics.periodInvoices.isEmpty
                  ? Text(l.text('noPayments'))
                  : Column(
                      children: [
                        Text(l.text('invoicePeriodHint')),
                        const SizedBox(height: 12),
                        for (final invoice
                            in (metrics.periodInvoices..sort(
                                  (a, b) => b.issuedAt.compareTo(a.issuedAt),
                                ))
                                .take(10))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(invoice.patientName),
                            subtitle: Text(
                              DateFormat.yMMMd(locale).format(invoice.issuedAt),
                            ),
                            trailing: Text(money(invoice.amountPaid)),
                          ),
                      ],
                    ),
            )
          else if (selectedTab == 'activity')
            AppSection(
              title: l.text('activity'),
              child: widget.unavailable.contains('visits')
                  ? const Text('—')
                  : metrics.visits.isEmpty
                  ? Text(l.text('noActivity'))
                  : Column(
                      children: [
                        for (final visit
                            in (metrics.visits..sort(
                                  (a, b) =>
                                      (b.visitDate ??
                                              b.createdAt ??
                                              DateTime(1970))
                                          .compareTo(
                                            a.visitDate ??
                                                a.createdAt ??
                                                DateTime(1970),
                                          ),
                                ))
                                .take(10))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(visit.patient.fullName),
                            subtitle: Text(visit.diagnoses.join(', ')),
                          ),
                      ],
                    ),
            )
          else if (selectedTab == 'vaccines')
            AppSection(
              title: l.text('dueVaccines'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.text('doseHint')),
                  const SizedBox(height: 12),
                  if (widget.unavailable.contains('vaccines'))
                    const Text('—')
                  else if (widget.vaccines
                      .where((v) => v.nextDoseAt != null)
                      .isEmpty)
                    Text(l.text('noDoses'))
                  else
                    for (final vaccine
                        in (widget.vaccines
                                .where((v) => v.nextDoseAt != null)
                                .toList()
                              ..sort(
                                (a, b) =>
                                    a.nextDoseAt!.compareTo(b.nextDoseAt!),
                              ))
                            .take(12))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(vaccine.patientName),
                        subtitle: Text(vaccine.vaccine),
                        trailing: Text(
                          DateFormat.yMMMd(locale).format(vaccine.nextDoseAt!),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ConsultationChart extends StatelessWidget {
  const ConsultationChart({super.key, required this.days});
  final List<(DateTime, int)> days;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final max = days.fold<int>(1, (m, e) => e.$2 > m ? e.$2 : m);
    return SizedBox(
      height: 174,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Expanded(
              child: Semantics(
                label: '${DateFormat.yMMMd(locale).format(day.$1)}: ${day.$2}',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: day.$2 == 0 ? .025 : day.$2 / max,
                              widthFactor: .65,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: day.$2 == 0
                                      ? AppColors.line
                                      : AppColors.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${day.$2}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          DateFormat.E(locale).format(day.$1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
