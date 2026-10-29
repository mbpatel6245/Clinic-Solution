import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:provider/provider.dart';
import '../../../core/auth/app_role.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../data/datasources/enterprise_models.dart';
import '../../../data/datasources/patient_intake.dart';
import '../../../services/firestore_services.dart';
import '../../../services/session_controller.dart';
import '../../../ui/widgets/app_design.dart';
import '../../patients/presentation/patient_labels.dart';
import '../data/operational_repository.dart';
import 'operational_week.dart';
import 'durable_booking_workspace.dart';
import '../application/booking_sync.dart';
import '../../patients/data/registration_draft_store.dart';

DateTime clinicInstant(String zone, DateTime day, int minute) => tz.TZDateTime(
  tz.getLocation(zone),
  day.year,
  day.month,
  day.day,
  minute ~/ 60,
  minute % 60,
).toUtc();

class OperationalSchedule extends StatefulWidget {
  const OperationalSchedule({super.key, required this.clinic});
  final ClinicProfile clinic;
  @override
  State<OperationalSchedule> createState() => _OperationalScheduleState();
}

class _OperationalScheduleState extends State<OperationalSchedule> {
  late final repository = FirebaseOperationalRepository(widget.clinic.id);
  late final patients = context.read<FirebaseFireStore>().streamPatients();
  late final userId = FirebaseAuth.instance.currentUser?.uid;
  @override
  void dispose() {
    repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.activeClinicId != widget.clinic.id ||
        userId == null ||
        FirebaseAuth.instance.currentUser?.uid != userId ||
        !session.can(AppFeature.appointments)) {
      return const SizedBox.shrink();
    }
    final own =
        session.roles.contains(AppRole.doctor) &&
        !session.roles.any(
          (r) => [
            AppRole.clinicAdmin,
            AppRole.platformOwner,
            AppRole.branchManager,
            AppRole.receptionist,
          ].contains(r),
        );
    return DurableBookingWorkspace(
      key: ValueKey('${widget.clinic.id}:$own'),
      clinic: widget.clinic,
      scope: RegistrationDraftStore.scope(
        Firebase.app().options.projectId,
        userId!,
        widget.clinic.id,
      ),
      authorized: () =>
          FirebaseAuth.instance.currentUser?.uid == userId &&
          session.activeClinicId == widget.clinic.id &&
          session.can(AppFeature.appointments),
      authorizationChanges: session,
      repository: repository,
      patients: patients,
      ownDoctorId: own ? FirebaseAuth.instance.currentUser?.uid : null,
    );
  }
}

class OperationalScheduleView extends StatefulWidget {
  const OperationalScheduleView({
    super.key,
    required this.clinic,
    required this.repository,
    required this.patients,
    this.ownDoctorId,
    this.sync,
  });
  final ClinicProfile clinic;
  final OperationalRepository repository;
  final Stream<List<PatientModel>> patients;
  final String? ownDoctorId;
  final BookingSync? sync;
  @override
  State<OperationalScheduleView> createState() =>
      _OperationalScheduleViewState();
}

class _OperationalScheduleViewState extends State<OperationalScheduleView> {
  late Future<List<Practitioner>> _roster = widget.repository.practitioners();
  late final Stream<List<AppointmentModel>> _appointments = widget.repository
      .appointments(doctorId: widget.ownDoctorId);
  late DateTime _day = ClinicSchedule.day(widget.clinic, DateTime.now());
  String? _doctor, _patient, _error;
  int _duration = 20;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final _reason = TextEditingController();
  Map<String, Object?>? _pending;
  bool _busy = false, _unknown = false;
  bool _week = true;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime _instant() {
    // ClinicSchedule constructs timezone-aware instants. Find the selected
    // five-minute boundary without depending on the device timezone.
    final midnight = ClinicSchedule.location(widget.clinic);
    return clinicInstant(midnight.name, _day, _time.hour * 60 + _time.minute);
  }

  Future<void> _book() async {
    if (_busy || _doctor == null || _patient == null) return;
    _pending ??= {
      'kind': 'book',
      'operationId': widget.repository.newOperationId(),
      'doctorId': _doctor,
      'patientId': _patient,
      'start': _instant().toUtc().toIso8601String(),
      'duration': _duration,
      'reason': _reason.text.trim(),
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.sync != null) {
        await widget.sync!.queue(_pending!);
        if (!mounted) return;
        setState(() {
          _pending = null;
          _unknown = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(PatientLabels.of(context)('bookingQueued'))),
        );
        return;
      }
      await widget.repository.command(_pending!);
      if (!mounted) return;
      setState(() {
        _pending = null;
        _unknown = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PatientLabels.of(context)('bookingConfirmed'))),
      );
    } on OperationalFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.unknown ? 'statusUnknown' : 'bookingRejected';
          _unknown = e.unknown;
          if (!e.unknown) _pending = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unknown = true;
          _error = 'statusUnknown';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _availability() async {
    if (widget.ownDoctorId == null || _busy) return;
    final l = PatientLabels.of(context);
    TimeOfDay start = const TimeOfDay(hour: 13, minute: 0),
        end = const TimeOfDay(hour: 16, minute: 0);
    bool checked = false, saving = false;
    String? error;
    final operation = widget.repository.newOperationId();
    Map<String, Object?>? pending;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l('availability')),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l('availabilityHint')),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(l('breakStart')),
                  trailing: Text(start.format(context)),
                  onTap: saving || pending != null
                      ? null
                      : () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: start,
                          );
                          if (t != null) setLocal(() => start = t);
                        },
                ),
                ListTile(
                  title: Text(l('breakEnd')),
                  trailing: Text(end.format(context)),
                  onTap: saving || pending != null
                      ? null
                      : () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: end,
                          );
                          if (t != null) setLocal(() => end = t);
                        },
                ),
                CheckboxListTile(
                  title: Text(l('availabilityReviewed')),
                  value: checked,
                  onChanged: saving
                      ? null
                      : (v) => setLocal(() => checked = v ?? false),
                ),
                if (error != null) Text(l(error!)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(l('cancel')),
            ),
            FilledButton(
              onPressed: !checked || saving
                  ? null
                  : () async {
                      if (widget.sync != null && !widget.sync!.authorized()) {
                        return;
                      }
                      int clock(String s) {
                        final p = s.split(':').map(int.parse).toList();
                        return p[0] * 60 + p[1];
                      }

                      final a = start.hour * 60 + start.minute,
                          b = end.hour * 60 + end.minute;
                      if (a >= b) {
                        setLocal(() => error = 'bookingRejected');
                        return;
                      }
                      pending ??= {
                        'kind': 'availability',
                        'operationId': operation,
                        'doctorId': widget.ownDoctorId,
                        'start': _instant().toUtc().toIso8601String(),
                        'sessions': [
                          [clock(widget.clinic.openingTime), a],
                          [b, clock(widget.clinic.closingTime)],
                        ],
                      };
                      setLocal(() => saving = true);
                      try {
                        await widget.repository.command(pending!);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } on OperationalFailure catch (e) {
                        if (dialogContext.mounted) {
                          setLocal(() {
                            saving = false;
                            error = e.unknown
                                ? 'statusUnknown'
                                : 'availabilityConflict';
                            if (!e.unknown) pending = null;
                          });
                        }
                      } catch (_) {
                        if (dialogContext.mounted) {
                          setLocal(() {
                            saving = false;
                            error = 'statusUnknown';
                          });
                        }
                      }
                    },
              child: Text(l('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = PatientLabels.of(context),
        own = widget.ownDoctorId != null,
        locked = _busy || _unknown;
    return Theme(
      data: UviloTheme.light,
      child: FutureBuilder<List<Practitioner>>(
        future: _roster,
        builder: (context, roster) {
          if (roster.hasError) {
            return AppPage(
              child: AppSection(
                child: Column(
                  children: [
                    Text(l('scheduleUnavailable')),
                    TextButton(
                      onPressed: () => setState(
                        () => _roster = widget.repository.practitioners(),
                      ),
                      child: Text(l('retry')),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!roster.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doctors = roster.data!;
          _doctor ??= own ? widget.ownDoctorId : doctors.firstOrNull?.id;
          if (doctors.isEmpty) {
            return AppPage(
              child: AppSection(child: Text(l('noPractitioners'))),
            );
          }
          return StreamBuilder<List<AppointmentModel>>(
            stream: _appointments,
            builder: (context, snapshot) {
              final all = snapshot.data ?? [],
                  items =
                      all
                          .where(
                            (a) =>
                                (a.practitionerId == _doctor ||
                                    (!own && a.practitionerId.isEmpty)) &&
                                ClinicSchedule.sameDay(
                                  widget.clinic,
                                  a.scheduledAt,
                                  _day,
                                ),
                          )
                          .toList()
                        ..sort(
                          (a, b) => a.scheduledAt.compareTo(b.scheduledAt),
                        );
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        l(own ? 'myCalendar' : 'schedule'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (own)
                        OutlinedButton(
                          onPressed: locked ? null : _availability,
                          child: Text(l('availability')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.clinic.name} · ${widget.clinic.timezone}',
                    style: const TextStyle(color: UviloTheme.muted),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _doctor,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l('practitioner')),
                    items: [
                      if (_doctor != null &&
                          !doctors.any((d) => d.id == _doctor))
                        DropdownMenuItem(
                          value: _doctor,
                          enabled: false,
                          child: Text(l('noPractitioners')),
                        ),
                      for (final d in doctors)
                        DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: locked || own
                        ? null
                        : (v) => setState(() => _doctor = v),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: l('previous'),
                        onPressed: locked
                            ? null
                            : () => setState(
                                () => _day = DateTime(
                                  _day.year,
                                  _day.month,
                                  _day.day - 1,
                                ),
                              ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      OutlinedButton(
                        onPressed: locked
                            ? null
                            : () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _day,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 366),
                                  ),
                                );
                                if (d != null && mounted) {
                                  setState(() => _day = d);
                                }
                              },
                        child: Text(
                          DateFormat.yMMMEd(
                            Localizations.localeOf(context).toString(),
                          ).format(_day),
                        ),
                      ),
                      IconButton(
                        tooltip: l('next'),
                        onPressed: locked
                            ? null
                            : () => setState(
                                () => _day = DateTime(
                                  _day.year,
                                  _day.month,
                                  _day.day + 1,
                                ),
                              ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.hasError)
                    Text(l('loadError'))
                  else if (!snapshot.hasData)
                    const LinearProgressIndicator()
                  else
                    AppSection(
                      title: l(own ? 'myAppointments' : 'appointments'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (items.isEmpty) Text(l('noAppointments')),
                          for (final a in items)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(a.patientName),
                              subtitle: Text(
                                '${DateFormat.jm(Localizations.localeOf(context).toString()).format(ClinicSchedule.local(widget.clinic, a.scheduledAt))} · ${a.durationMinutes} ${l('minutes')}\n${a.status}',
                              ),
                              trailing: a.practitionerId.isEmpty
                                  ? Text(l('unassigned'))
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(l('dayView'))),
                      ButtonSegment(value: true, label: Text(l('weekView'))),
                    ],
                    selected: {_week},
                    onSelectionChanged: (v) => setState(() => _week = v.single),
                  ),
                  const SizedBox(height: 16),
                  if (_week && !snapshot.hasError)
                    OperationalWeek(
                      clinic: widget.clinic,
                      day: _day,
                      items: all
                          .where(
                            (a) =>
                                a.practitionerId == _doctor ||
                                (!own && a.practitionerId.isEmpty),
                          )
                          .toList(),
                      onDay: locked
                          ? null
                          : (day) => setState(() => _day = day),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    l('scheduleHint'),
                    style: const TextStyle(color: UviloTheme.muted),
                  ),
                ],
              );
              final booking = StreamBuilder<List<PatientModel>>(
                stream: widget.patients,
                builder: (context, patients) => AppSection(
                  title: l('newAppointment'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (patients.hasError) Text(l('loadError')),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('operational-patient'),
                        initialValue: _patient,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l('patients')),
                        items: [
                          if (_patient != null &&
                              !(patients.data ?? <PatientModel>[]).any(
                                (p) => p.id == _patient,
                              ))
                            DropdownMenuItem(
                              value: _patient,
                              enabled: false,
                              child: Text(l('noMatch')),
                            ),
                          for (final p in patients.data ?? <PatientModel>[])
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.fullName} · ${p.id}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: locked
                            ? null
                            : (v) => setState(() => _patient = v),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: locked
                            ? null
                            : () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: _time,
                                );
                                if (t != null && mounted) {
                                  setState(() => _time = t);
                                }
                              },
                        child: Text(_time.format(context)),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _duration,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l('duration')),
                        items: [
                          for (final n in [15, 20, 30, 45, 60])
                            DropdownMenuItem(
                              value: n,
                              child: Text('$n ${l('minutes')}'),
                            ),
                        ],
                        onChanged: locked
                            ? null
                            : (v) => setState(() => _duration = v!),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _reason,
                        enabled: !locked,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: l('visitReason'),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(l(_error!)),
                        ),
                      FilledButton(
                        key: const ValueKey('operational-confirm'),
                        onPressed:
                            _busy ||
                                _patient == null ||
                                (!doctors.any((d) => d.id == _doctor) &&
                                    !_unknown) ||
                                (!(patients.data ?? <PatientModel>[]).any(
                                      (p) => p.id == _patient,
                                    ) &&
                                    !_unknown) ||
                                (snapshot.hasError && widget.sync == null) ||
                                (patients.hasError && !patients.hasData)
                            ? null
                            : _book,
                        child: Text(
                          l(
                            _unknown
                                ? 'retrySame'
                                : _busy
                                ? 'saving'
                                : widget.sync != null
                                ? 'queueBooking'
                                : 'confirmBooking',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l('bookingHint'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: UviloTheme.muted,
                        ),
                      ),
                      if (widget.sync != null) ...[
                        const SizedBox(height: 16),
                        BookingSyncStatus(sync: widget.sync!),
                      ],
                    ],
                  ),
                ),
              );
              return AppPage(
                child: LayoutBuilder(
                  builder: (context, box) =>
                      box.maxWidth >= 1000 &&
                          MediaQuery.textScalerOf(context).scale(14) < 22
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: content),
                            const SizedBox(width: 24),
                            Expanded(child: booking),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            content,
                            const SizedBox(height: 24),
                            booking,
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
