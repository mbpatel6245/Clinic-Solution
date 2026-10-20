import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/auth/app_role.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../data/datasources/enterprise_models.dart';
import '../../../../data/datasources/patient_intake.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import '../../../widgets/app_design.dart';
import 'patient_entry_dialog.dart';

String appointmentSlotLabel(
  ClinicProfile clinic,
  DateTime slot,
  String locale,
) =>
    '${DateFormat.yMMMEd(locale).add_jm().format(ClinicSchedule.local(clinic, slot))} · ${clinic.name}';

class AppointmentBooking extends StatefulWidget {
  const AppointmentBooking({
    super.key,
    this.onOpenPatient,
    this.onManageSchedule,
    this.onViewAppointments,
    this.initialPatient,
  });
  final PatientModel? initialPatient;
  final ValueChanged<PatientModel>? onOpenPatient;
  final VoidCallback? onManageSchedule, onViewAppointments;
  @override
  State<AppointmentBooking> createState() => _AppointmentBookingState();
}

class _AppointmentBookingState extends State<AppointmentBooking> {
  String? _clinicId;
  late Stream<ClinicProfile> _clinic;
  late Stream<List<AppointmentModel>> _appointments;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.watch<SessionController>().activeClinicId;
    if (_clinicId == scope) return;
    _clinicId = scope;
    final service = context.read<FirebaseFireStore>();
    _clinic = service.streamActiveClinic();
    _appointments = service.streamAppointments();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ClinicProfile>(
    stream: _clinic,
    builder: (context, clinic) => StreamBuilder<List<AppointmentModel>>(
      stream: _appointments,
      builder: (context, appointments) {
        final l = RevampLabels.of(context);
        if (clinic.hasError || appointments.hasError) {
          return AppPage(child: AppSection(child: Text(l.text('loadError'))));
        }
        if (!clinic.hasData || !appointments.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final session = context.watch<SessionController>();
        if (!session.can(AppFeature.appointments)) {
          return const SizedBox.shrink();
        }
        return AppointmentBookingView(
          key: ValueKey(_clinicId),
          clinic: clinic.data!,
          appointments: appointments.data!,
          onManageSchedule: widget.onManageSchedule,
          onViewAppointments: widget.onViewAppointments,
          onOpenPatient: session.can(AppFeature.patients)
              ? widget.onOpenPatient
              : null,
          onChooseSlot: (slot) {
            final locale = Localizations.localeOf(context).toString();
            return showPatientEntry(
              context,
              mode: PatientEntryMode.booking,
              slot: slot,
              initialPatient: widget.initialPatient,
              slotLabel: appointmentSlotLabel(clinic.data!, slot, locale),
            );
          },
        );
      },
    ),
  );
}

class AppointmentBookingView extends StatefulWidget {
  const AppointmentBookingView({
    super.key,
    required this.clinic,
    required this.appointments,
    required this.onChooseSlot,
    this.onOpenPatient,
    this.onManageSchedule,
    this.onViewAppointments,
    this.now,
  });
  final ClinicProfile clinic;
  final List<AppointmentModel> appointments;
  final Future<PatientEntryResult?> Function(DateTime) onChooseSlot;
  final ValueChanged<PatientModel>? onOpenPatient;
  final VoidCallback? onManageSchedule, onViewAppointments;
  final DateTime? now;
  @override
  State<AppointmentBookingView> createState() => _AppointmentBookingViewState();
}

class _AppointmentBookingViewState extends State<AppointmentBookingView> {
  final _scroll = ScrollController();
  DateTime? _date, _selected;
  PatientEntryResult? _saved;
  bool _busy = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || _selected == null) return;
    final slot = _selected!;
    final clinic = widget.clinic.id;
    setState(() => _busy = true);
    try {
      final result = await widget.onChooseSlot(slot);
      if (!mounted || widget.clinic.id != clinic) return;
      if (result != null) {
        setState(() {
          _saved = result;
          _selected = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final locale = Localizations.localeOf(context).toString();
    final clinic = widget.clinic;
    final now = widget.now ?? DateTime.now();
    final today = ClinicSchedule.day(clinic, now);
    final date = _date ?? today;
    final slots = ClinicSchedule.slots(
      clinic,
      date,
      now: now,
      appointments: widget.appointments,
    );
    final selected =
        _selected != null && slots.any((s) => s.isAtSameMomentAs(_selected!))
        ? _selected
        : null;
    final booked =
        widget.appointments
            .where(
              (a) =>
                  ClinicSchedule.sameDay(clinic, a.scheduledAt, date) &&
                  ClinicSchedule.occupiesSlot(a),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    String time(DateTime instant) =>
        DateFormat.jm(locale).format(ClinicSchedule.local(clinic, instant));
    return Column(
      children: [
        Expanded(
          child: AppPage(
            controller: _scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.text('bookAnAppointment'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          DateFormat.yMMMMEEEEd(locale).format(date),
                          style: const TextStyle(color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: l.text('selectDate'),
                          icon: const Icon(Icons.date_range_outlined),
                          onPressed: _busy
                              ? null
                              : () async {
                                  final day = await showDatePicker(
                                    context: context,
                                    initialDate: date,
                                    firstDate: today,
                                    lastDate: DateTime(
                                      today.year + 2,
                                      today.month,
                                      today.day,
                                    ),
                                  );
                                  if (day != null && mounted) {
                                    setState(() {
                                      _date = day;
                                      _selected = null;
                                      _saved = null;
                                    });
                                  }
                                },
                        ),
                        if (widget.onManageSchedule != null)
                          IconButton(
                            tooltip: l.text('manageSchedule'),
                            onPressed: widget.onManageSchedule,
                            icon: const Icon(Icons.edit_calendar_outlined),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < 14; i++)
                        Builder(
                          builder: (_) {
                            final day = DateTime(
                              today.year,
                              today.month,
                              today.day + i,
                            );
                            final active = DateUtils.isSameDay(day, date);
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Semantics(
                                selected: active,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: active
                                        ? AppColors.primary
                                        : AppColors.surface,
                                    foregroundColor: active
                                        ? Colors.white
                                        : AppColors.ink,
                                    minimumSize: const Size(84, 64),
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _date = day;
                                          _selected = null;
                                          _saved = null;
                                        }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          i == 0
                                              ? l.text('todayNav')
                                              : DateFormat.E(
                                                  locale,
                                                ).format(day),
                                        ),
                                        Text(
                                          DateFormat.MMMd(locale).format(day),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_saved != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AppSection(
                      title: l.text('bookingComplete'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _saved!.patient.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            DateFormat.yMMMEd(locale).add_jm().format(
                              ClinicSchedule.local(
                                clinic,
                                _saved!.appointment!.scheduledAt,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (widget.onOpenPatient != null)
                                FilledButton(
                                  onPressed: () =>
                                      widget.onOpenPatient!(_saved!.patient),
                                  child: Text(l.text('viewPatient')),
                                ),
                              OutlinedButton(
                                onPressed: () => setState(() => _saved = null),
                                child: Text(l.text('bookAnother')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                AppSection(
                  title: '${l.text('bookedAppointments')} (${booked.length})',
                  trailing: widget.onViewAppointments == null
                      ? null
                      : IconButton(
                          tooltip: l.text('allTime'),
                          onPressed: widget.onViewAppointments,
                          icon: const Icon(Icons.list_alt_outlined),
                        ),
                  child: booked.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            l.text('noBookedAppointments'),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          children: [
                            for (final appointment in booked)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.person_outline),
                                title: Text(appointment.patientName),
                                subtitle: Text(time(appointment.scheduledAt)),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${l.text('slotDurationHint')} ${clinic.timezone}',
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
                const SizedBox(height: 16),
                if (slots.isEmpty)
                  AppSection(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.event_busy_outlined,
                            size: 36,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l.text('noSlots'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            l.text('noSlotsHint'),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (final group in [
                    'morningSlots',
                    'afternoonSlots',
                    'eveningSlots',
                  ])
                    Builder(
                      builder: (_) {
                        final items = slots.where((slot) {
                          final hour = ClinicSchedule.local(clinic, slot).hour;
                          return group == 'morningSlots'
                              ? hour < 12
                              : group == 'afternoonSlots'
                              ? hour >= 12 && hour < 17
                              : hour >= 17;
                        }).toList();
                        if (items.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${l.text(group)} (${items.length})',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              ResponsiveGrid(
                                minimumItemWidth: 160,
                                spacing: 12,
                                children: [
                                  for (final slot in items)
                                    OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => setState(() {
                                              _selected = slot;
                                              _saved = null;
                                            }),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: selected == slot
                                            ? AppColors.primary
                                            : AppColors.surface,
                                        foregroundColor: selected == slot
                                            ? Colors.white
                                            : AppColors.ink,
                                        minimumSize: const Size(0, 88),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              time(slot),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 17,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              clinic.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
        ),
        if (selected != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.sizeOf(context).width < AppBreakpoints.medium
                    ? 92
                    : 12,
              ),
              child: Material(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.text('selectedSlot'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${time(selected)} · ${DateFormat.MMMEd(locale).format(date)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _confirm,
                        child: Text(l.text('confirmSlot')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
