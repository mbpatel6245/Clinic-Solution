import 'package:flutter/material.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../core/design/revamp_labels.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../data/datasources/enterprise_models.dart';
import '../../../ui/widgets/app_design.dart';
import '../../patients/presentation/patient_labels.dart';
import 'front_desk_components.dart';

class FrontDeskQueue extends StatefulWidget {
  const FrontDeskQueue({
    super.key,
    required this.items,
    required this.onAction,
    this.onReviewedArrival,
    this.onRegister,
    this.onAppointments,
    this.canPrescribe = false,
    this.loading = false,
    this.hasError = false,
    this.now,
    this.clinic = const ClinicProfile(id: '', name: ''),
  });
  final List<AppointmentModel> items;
  final Future<void> Function(AppointmentModel, String) onAction;
  final Future<void> Function(AppointmentModel)? onReviewedArrival;
  final VoidCallback? onRegister, onAppointments;
  final bool canPrescribe, loading, hasError;
  final DateTime? now;
  final ClinicProfile clinic;
  @override
  State<FrontDeskQueue> createState() => _FrontDeskQueueState();
}

class _FrontDeskQueueState extends State<FrontDeskQueue> {
  String _query = '', _stage = 'active';
  String? _selected;
  bool _name = false, _contact = false, _consent = false, _busy = false;
  String? _reviewId;
  String identity(AppointmentModel a) =>
      '${a.id}:${a.patientId}:${a.patientName}:${a.phone}';
  void check(AppointmentModel a, int field, bool value) => setState(() {
    if (_reviewId != identity(a)) {
      _name = false;
      _contact = false;
      _consent = false;
    }
    _reviewId = identity(a);
    if (field == 0) _name = value;
    if (field == 1) _contact = value;
    if (field == 2) _consent = value;
  });
  void select(AppointmentModel a) => setState(() {
    _selected = a.id;
    _name = false;
    _contact = false;
    _consent = false;
  });
  Future<void> action(
    AppointmentModel a,
    String value, {
    bool reviewed = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (reviewed && widget.onReviewedArrival != null) {
        await widget.onReviewedArrival!(a);
      } else {
        await widget.onAction(a, value);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(RevampLabels.of(context).text('saveError'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DeskLabels.of(context),
        l = RevampLabels.of(context),
        p = PatientLabels.of(context);
    final day = deskDay(
      widget.items,
      widget.clinic,
      widget.now ?? DateTime.now(),
    );
    final live = day.where((a) => a.status == 'confirmed').toList();
    final scheduled = day
        .where((a) => ['booked', 'pending'].contains(a.status))
        .toList();
    final done = day.where((a) => a.status == 'completed').length;
    final rows = day.where((a) {
      final matches = switch (_stage) {
        'active' => ['booked', 'pending', 'confirmed'].contains(a.status),
        'completed' => a.status == 'completed',
        _ => a.status == _stage,
      };
      return matches &&
          '${a.patientName} ${a.patientId} ${a.phone}'.toLowerCase().contains(
            _query.toLowerCase().trim(),
          );
    }).toList();
    final selected =
        rows.where((a) => a.id == _selected).firstOrNull ?? rows.firstOrNull;
    Widget link(String label, VoidCallback? onPressed, {Widget? icon}) =>
        OutlinedButton.icon(
          onPressed: onPressed,
          icon:
              icon ?? const DeskIcon('imgCalendarDays', queue: true, size: 16),
          label: Text(label),
        );
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeskPanel(
          title: d('todayArrivals'),
          trailing: widget.onAppointments == null
              ? null
              : TextButton(
                  onPressed: widget.onAppointments,
                  child: Text(d('calendar')),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in [
                    ('active', '${l.text('live')} / ${l.text('scheduled')}'),
                    ('completed', d('completed')),
                    ('cancelled', l.text('cancelled')),
                    ('no_show', l.text('noShow')),
                  ])
                    ChoiceChip(
                      label: Text(entry.$2),
                      selected: _stage == entry.$1,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _stage = entry.$1),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.loading)
                const LinearProgressIndicator()
              else if (widget.hasError)
                Text(l.text('loadError'))
              else if (rows.isEmpty)
                Text(l.text('noQueue'))
              else
                DeskAppointmentTable(
                  items: rows,
                  clinic: widget.clinic,
                  selectedId: selected?.id,
                  onSelect: _busy ? null : select,
                  actions: (a) => TextButton(
                    onPressed: _busy ? null : () => select(a),
                    child: Text(d('viewArrival')),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        DeskPanel(
          title: d('arrival'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(d('handoffHint')),
              if (selected != null) ...[
                const SizedBox(height: 16),
                Text(
                  '${selected.patientName} · ${selected.patientId}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    const DeskIcon('imgCircleCheck', queue: true),
                    Text(
                      '${l.text('checkIn')}: ${selected.arrivalAt == null ? d('notRecorded') : deskTime(context, widget.clinic, selected.arrivalAt!)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  selected.practitionerName.isEmpty
                      ? p('unassigned')
                      : selected.practitionerName,
                ),
                if (_busy)
                  const LinearProgressIndicator()
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (selected.status == 'confirmed' && widget.canPrescribe)
                        FilledButton(
                          onPressed: () => action(selected, 'prescribe'),
                          child: Text(l.text('startVisit')),
                        ),
                      if (selected.status == 'confirmed')
                        OutlinedButton(
                          onPressed: () => action(selected, 'completed'),
                          child: Text(l.text('done')),
                        ),
                      if ([
                        'booked',
                        'pending',
                        'confirmed',
                      ].contains(selected.status))
                        TextButton(
                          onPressed: () => action(selected, 'cancelled'),
                          child: Text(l.text('cancelled')),
                        ),
                    ],
                  ),
              ] else
                Text(d('select')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        DeskPanel(
          title: d('noShow'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(d('noShowHint')),
              if (selected != null &&
                  selected.arrivalAt == null &&
                  ['booked', 'pending'].contains(selected.status))
                TextButton(
                  onPressed: _busy ? null : () => action(selected, 'no_show'),
                  child: Text(l.text('noShow')),
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
          title: d('find'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: InputDecoration(hintText: d('search')),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _query = v;
                        _reviewId = null;
                      }),
              ),
              const SizedBox(height: 16),
              if (selected == null)
                Text(d('select'))
              else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: UviloTheme.canvas,
                    border: Border.all(color: UviloTheme.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.patientName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(selected.patientId),
                      Text(selected.phone),
                      Text(
                        deskTime(context, widget.clinic, selected.scheduledAt),
                      ),
                    ],
                  ),
                ),
                if (['booked', 'pending'].contains(selected.status)) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _reviewId == identity(selected) && _name,
                    onChanged: _busy
                        ? null
                        : (v) => check(selected, 0, v ?? false),
                    title: Text(p('nameChecked')),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _reviewId == identity(selected) && _contact,
                    onChanged: _busy
                        ? null
                        : (v) => check(selected, 1, v ?? false),
                    title: Text(p('contactChecked')),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _reviewId == identity(selected) && _consent,
                    onChanged: _busy
                        ? null
                        : (v) => check(selected, 2, v ?? false),
                    title: Text(p('arrivalConsent')),
                  ),
                  Text(p('arrivalHint')),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('desk-confirm-arrival'),
                    onPressed:
                        _busy ||
                            _reviewId != identity(selected) ||
                            !_name ||
                            !_contact ||
                            !_consent
                        ? null
                        : () => action(selected, 'confirmed', reviewed: true),
                    icon: const DeskIcon('imgCheck', queue: true, size: 16),
                    label: Text(p('checkIn')),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: UviloTheme.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DeskIcon('imgShieldCheck', queue: true, size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Text(d('scope'), style: const TextStyle(fontSize: 12)),
              ),
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
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(
                  d('arrivalHeading'),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.onAppointments != null)
                  link(p('appointments'), widget.onAppointments),
                if (widget.onRegister != null)
                  link(
                    l.text('walkIn'),
                    widget.onRegister,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.clinic.name} · ${widget.clinic.timezone}',
              style: const TextStyle(color: UviloTheme.muted),
            ),
            const SizedBox(height: 24),
            DeskMetrics(
              values: [
                (
                  d('today'),
                  widget.hasError || widget.loading ? '—' : '${day.length}',
                ),
                (
                  d('waiting'),
                  widget.hasError || widget.loading ? '—' : '${live.length}',
                ),
                (
                  d('upcoming'),
                  widget.hasError || widget.loading
                      ? '—'
                      : '${scheduled.length}',
                ),
                (
                  d('completed'),
                  widget.hasError || widget.loading ? '—' : '$done',
                ),
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
