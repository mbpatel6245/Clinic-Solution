import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../data/datasources/workflow_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import '../../../widgets/app_design.dart';
import 'lab_trend_chart.dart';
import 'treatment_plan_card.dart';

class TemplateLibraryScreen extends StatelessWidget {
  const TemplateLibraryScreen({super.key, required this.onUse});
  final ValueChanged<PrescriptionTemplate> onUse;
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    return WorkflowList<PrescriptionTemplate>(
      title: l.text('templates'),
      hint: l.text('templateHint'),
      empty: l.text('noTemplates'),
      stream: context.read<FirebaseFireStore>().streamPrescriptionTemplates(),
      itemBuilder: (item) => Card(
        child: ListTile(
          title: Text(item.name),
          subtitle: Text(item.diagnoses.join(', ')),
          trailing: IconButton(
            tooltip: l.text('useTemplate'),
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => onUse(item),
          ),
          onTap: () => onUse(item),
        ),
      ),
    );
  }
}

class TreatmentPlansScreen extends StatelessWidget {
  const TreatmentPlansScreen({super.key, this.patient});
  final PatientModel? patient;
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final service = context.read<FirebaseFireStore>();
    return WorkflowList<TreatmentPlan>(
      title: l.text('plans'),
      hint: l.text('planHint'),
      empty: l.text('noPlans'),
      stream: service.streamTreatmentPlans().map(
        (plans) => patient == null
            ? plans
            : plans.where((p) => p.patientId == patient!.id).toList(),
      ),
      action: () => showDialog<void>(
        context: context,
        builder: (_) => TreatmentPlanForm(patient: patient),
      ),
      actionLabel: l.text('newPlan'),
      itemBuilder: (plan) =>
          TreatmentPlanCard(key: ValueKey(plan.id), plan: plan),
    );
  }
}

class TreatmentPlanForm extends StatefulWidget {
  const TreatmentPlanForm({super.key, this.patient});
  final PatientModel? patient;
  @override
  State<TreatmentPlanForm> createState() => _TreatmentPlanFormState();
}

class _TreatmentPlanFormState extends State<TreatmentPlanForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _notes = TextEditingController();
  final _sittings = <(TextEditingController, DateTime)>[
    (TextEditingController(), DateTime.now()),
  ];
  PatientModel? _patient;
  bool _saving = false, _failed = false;
  late final String _clinic;
  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _clinic = context.read<SessionController>().activeClinicId;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    for (final s in _sittings) {
      s.$1.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final s = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.text('newPlan')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.patient == null)
                  WorkflowPatientPicker(onSelected: (v) => _patient = v)
                else
                  Text(widget.patient!.fullName),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l.text('templateName'),
                  ),
                  maxLength: 120,
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : s.requiredField,
                ),
                for (final (i, entry) in _sittings.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: entry.$1,
                          decoration: InputDecoration(
                            labelText: '${l.text('sessions')} ${i + 1}',
                          ),
                          validator: (v) => v?.trim().isNotEmpty == true
                              ? null
                              : s.requiredField,
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            DateFormat.yMMMd(
                              Localizations.localeOf(context).toString(),
                            ).format(entry.$2),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: entry.$2,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() => _sittings[i] = (entry.$1, date));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                if (_sittings.length < 100)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l.text('addSitting')),
                    onPressed: () => setState(
                      () => _sittings.add((
                        TextEditingController(),
                        DateTime.now(),
                      )),
                    ),
                  ),
                TextFormField(
                  controller: _notes,
                  decoration: InputDecoration(labelText: s.description),
                  maxLines: 3,
                ),
                if (_failed)
                  Text(
                    l.text('saveError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(s.save)),
      ],
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _patient == null) return;
    setState(() => _saving = true);
    try {
      if (context.read<SessionController>().activeClinicId != _clinic ||
          context.read<FirebaseFireStore>().activeClinicId != _clinic) {
        throw StateError('Clinic changed.');
      }
      await context.read<FirebaseFireStore>().saveTreatmentPlan(
        TreatmentPlan(
          patientId: _patient!.id,
          patientName: _patient!.fullName,
          name: _name.text,
          notes: _notes.text,
          sittings: _sittings
              .map((s) => TreatmentSitting(name: s.$1.text, scheduledAt: s.$2))
              .toList(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }
}

class LaboratoryScreen extends StatelessWidget {
  const LaboratoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    return WorkflowList<LabObservation>(
      title: l.text('laboratory'),
      hint: l.text('labHint'),
      empty: l.text('noLabs'),
      stream: context.read<FirebaseFireStore>().streamLabObservations(),
      action: () => showDialog<void>(
        context: context,
        builder: (_) => const LabValueForm(),
      ),
      actionLabel: l.text('addLab'),
      itemBuilder: (item) => Card(
        child: ListTile(
          leading: Icon(
            item.outsideReportedRange
                ? Icons.flag_outlined
                : Icons.science_outlined,
            color: item.outsideReportedRange
                ? Theme.of(context).colorScheme.error
                : AppColors.primary,
          ),
          title: Text('${item.patientName} · ${item.analyte}'),
          subtitle: Text(
            '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(item.reportedAt)}\n${item.value} ${item.unit}${item.outsideReportedRange ? ' · ${l.text('outsideRange')}' : ''}',
          ),
          onTap: () => _showSeries(context, item),
        ),
      ),
    );
  }

  Future<void> _showSeries(BuildContext context, LabObservation item) async {
    final l = RevampLabels.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${item.analyte} (${item.unit})'),
        content: SizedBox(
          width: 500,
          child: StreamBuilder<List<LabObservation>>(
            stream: context.read<FirebaseFireStore>().streamLabObservations(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text(l.text('loadError'));
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final values = snapshot.data!
                  .where((v) => v.seriesKey == item.seriesKey)
                  .toList();
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LabTrendChart(observations: values),
                    const SizedBox(height: 16),
                    for (final v in values)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${v.value} ${v.unit}'),
                        subtitle: Text(
                          DateFormat.yMMMd(
                            Localizations.localeOf(context).toString(),
                          ).format(v.reportedAt),
                        ),
                        trailing: v.outsideReportedRange
                            ? const Icon(Icons.flag_outlined)
                            : null,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }
}

class LabValueForm extends StatefulWidget {
  const LabValueForm({super.key});
  @override
  State<LabValueForm> createState() => _LabValueFormState();
}

class _LabValueFormState extends State<LabValueForm> {
  final _form = GlobalKey<FormState>();
  final _test = TextEditingController(),
      _value = TextEditingController(),
      _unit = TextEditingController(),
      _lower = TextEditingController(),
      _upper = TextEditingController();
  PatientModel? _patient;
  DateTime _date = DateTime.now();
  bool _saving = false, _failed = false;
  @override
  void dispose() {
    for (final c in [_test, _value, _unit, _lower, _upper]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final s = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.text('addLab')),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WorkflowPatientPicker(onSelected: (v) => _patient = v),
                const SizedBox(height: 16),
                for (final (controller, key, number, requiredValue) in [
                  (_test, 'analyte', false, true),
                  (_value, 'value', true, true),
                  (_unit, 'unit', false, true),
                  (_lower, 'lower', true, false),
                  (_upper, 'upper', true, false),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(labelText: l.text(key)),
                      keyboardType: number
                          ? const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            )
                          : TextInputType.text,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return requiredValue ? s.requiredField : null;
                        }
                        if (number && (double.tryParse(v)?.isFinite != true)) {
                          return s.invalidNumber;
                        }
                        if (key == 'upper' &&
                            _lower.text.trim().isNotEmpty &&
                            (double.tryParse(v) ?? double.negativeInfinity) <
                                (double.tryParse(_lower.text) ??
                                    double.infinity)) {
                          return s.invalidNumber;
                        }
                        return null;
                      },
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(_date),
                  ),
                ),
                if (_failed) Text(l.text('saveError')),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(s.save)),
      ],
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _patient == null) return;
    setState(() => _saving = true);
    try {
      await context.read<FirebaseFireStore>().saveLabObservation(
        LabObservation(
          patientId: _patient!.id,
          patientName: _patient!.fullName,
          analyte: _test.text,
          value: double.parse(_value.text),
          unit: _unit.text,
          reportedAt: _date,
          lower: double.tryParse(_lower.text),
          upper: double.tryParse(_upper.text),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }
}

class StaffMessagesScreen extends StatefulWidget {
  const StaffMessagesScreen({super.key});
  @override
  State<StaffMessagesScreen> createState() => _StaffMessagesScreenState();
}

class _StaffMessagesScreenState extends State<StaffMessagesScreen> {
  final _text = TextEditingController();
  bool _sending = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await context.read<FirebaseFireStore>().sendStaffMessage(
        _text.text,
        context.read<SessionController>().displayName,
      );
      _text.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(RevampLabels.of(context).text('saveError'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    return WorkflowList<StaffMessage>(
      title: l.text('messages'),
      hint: l.text('messageHint'),
      empty: l.text('noMessages'),
      stream: context.read<FirebaseFireStore>().streamStaffMessages(),
      header: Column(
        children: [
          TextField(
            controller: _text,
            maxLength: 1000,
            maxLines: 2,
            decoration: InputDecoration(labelText: l.text('messages')),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_outlined),
              label: Text(l.text('send')),
            ),
          ),
        ],
      ),
      itemBuilder: (m) => Card(
        child: ListTile(
          title: Text(m.text),
          subtitle: Text(
            '${m.senderName}${m.sentAt == null ? '' : ' · ${DateFormat.MMMd(Localizations.localeOf(context).toString()).add_jm().format(m.sentAt!)}'}',
          ),
        ),
      ),
    );
  }
}

class WorkflowPatientPicker extends StatefulWidget {
  const WorkflowPatientPicker({super.key, required this.onSelected});
  final ValueChanged<PatientModel?> onSelected;
  @override
  State<WorkflowPatientPicker> createState() => _WorkflowPatientPickerState();
}

class _WorkflowPatientPickerState extends State<WorkflowPatientPicker> {
  late final _patients = context.read<FirebaseFireStore>().streamPatients();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<PatientModel>>(
    stream: _patients,
    builder: (context, snapshot) {
      final l = RevampLabels.of(context);
      if (snapshot.hasError) return Text(l.text('loadError'));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      return DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: InputDecoration(labelText: l.text('patients')),
        items: [
          for (final p in snapshot.data!)
            DropdownMenuItem(
              value: p.id,
              child: Text(p.fullName, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) => widget.onSelected(
          snapshot.data!.where((p) => p.id == id).firstOrNull,
        ),
        validator: (v) =>
            v == null ? AppLocalizations.of(context)!.requiredField : null,
      );
    },
  );
}

class WorkflowList<T> extends StatefulWidget {
  const WorkflowList({
    super.key,
    required this.title,
    required this.hint,
    required this.empty,
    required this.stream,
    required this.itemBuilder,
    this.action,
    this.actionLabel,
    this.header,
  });
  final String title, hint, empty;
  final Stream<List<T>> stream;
  final Widget Function(T) itemBuilder;
  final VoidCallback? action;
  final String? actionLabel;
  final Widget? header;
  @override
  State<WorkflowList<T>> createState() => _WorkflowListState<T>();
}

class _WorkflowListState<T> extends State<WorkflowList<T>> {
  late Stream<List<T>> _stream = widget.stream;
  // Parent rebuilds do not needlessly resubscribe to Firestore.
  @override
  Widget build(BuildContext context) => AppPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (widget.action != null)
              FilledButton.icon(
                onPressed: widget.action,
                icon: const Icon(Icons.add),
                label: Text(widget.actionLabel!),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(widget.hint, style: const TextStyle(color: AppColors.inkMuted)),
        const SizedBox(height: 24),
        if (widget.header != null) widget.header!,
        StreamBuilder<List<T>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppSection(
                child: Column(
                  children: [
                    Text(RevampLabels.of(context).text('loadError')),
                    TextButton(
                      onPressed: () => setState(() => _stream = widget.stream),
                      child: Text(RevampLabels.of(context).text('retry')),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.isEmpty) {
              return AppSection(child: Text(widget.empty));
            }
            return Column(
              children: [
                for (final item in snapshot.data!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: widget.itemBuilder(item),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
