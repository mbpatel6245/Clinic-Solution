import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/workflow_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../widgets/app_design.dart';

class TreatmentPlanCard extends StatefulWidget {
  const TreatmentPlanCard({super.key, required this.plan});
  final TreatmentPlan plan;
  @override
  State<TreatmentPlanCard> createState() => _TreatmentPlanCardState();
}

class _TreatmentPlanCardState extends State<TreatmentPlanCard> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan, l = RevampLabels.of(context);
    return AppSection(
      title: plan.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(plan.patientName),
              Chip(label: Text(l.text(plan.status.name))),
              if (_busy)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(),
                )
              else
                PopupMenuButton<TreatmentPlanStatus>(
                  onSelected: _changeStatus,
                  itemBuilder: (_) => [
                    if (plan.status == TreatmentPlanStatus.active) ...[
                      PopupMenuItem(
                        value: TreatmentPlanStatus.completed,
                        child: Text(l.text('closePlan')),
                      ),
                      PopupMenuItem(
                        value: TreatmentPlanStatus.cancelled,
                        child: Text(l.text('cancelPlan')),
                      ),
                    ] else
                      PopupMenuItem(
                        value: TreatmentPlanStatus.active,
                        child: Text(l.text('reopenPlan')),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: plan.progress),
          const SizedBox(height: 12),
          for (final (index, sitting) in plan.sittings.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                sitting.completed
                    ? Icons.check_circle_outline
                    : Icons.event_outlined,
              ),
              title: Text(sitting.name),
              subtitle: Text(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(sitting.scheduledAt),
              ),
              trailing: sitting.completed
                  ? Text(l.text('done'))
                  : TextButton(
                      onPressed:
                          _busy || plan.status != TreatmentPlanStatus.active
                          ? null
                          : () => _log(index),
                      child: Text(l.text('logSitting')),
                    ),
            ),
          if (plan.notes.isNotEmpty) Text(plan.notes),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _showHistory,
              icon: const Icon(Icons.history),
              label: Text(l.text('sittingHistory')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
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

  Future<void> _log(int index) async {
    final service = context.read<FirebaseFireStore>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TreatmentSittingLogForm(
        sitting: widget.plan.sittings[index],
        onSave: (work, notes, date) => service.logTreatmentSitting(
          planId: widget.plan.id,
          sittingIndex: index,
          workDone: work,
          notes: notes,
          performedAt: date,
        ),
      ),
    );
  }

  Future<void> _changeStatus(TreatmentPlanStatus status) async {
    final l = RevampLabels.of(context), s = AppLocalizations.of(context)!;
    final title = l.text(switch (status) {
      TreatmentPlanStatus.active => 'reopenPlan',
      TreatmentPlanStatus.completed => 'closePlan',
      TreatmentPlanStatus.cancelled => 'cancelPlan',
    });
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(l.text('planStatusHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(title),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => context.read<FirebaseFireStore>().changeTreatmentPlanStatus(
        widget.plan.id,
        status,
      ),
    );
  }

  Future<void> _showHistory() async {
    final l = RevampLabels.of(context);
    final stream = context.read<FirebaseFireStore>().streamTreatmentSittingLogs(
      widget.plan.id,
    );
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.text('sittingHistory')),
        content: SizedBox(
          width: 560,
          child: StreamBuilder<List<TreatmentSittingLog>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text(l.text('loadError'));
              if (!snapshot.hasData) return const LinearProgressIndicator();
              if (snapshot.data!.isEmpty) return Text(l.text('noSittingLogs'));
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final log in snapshot.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(log.workDone),
                        subtitle: Text(
                          [
                            DateFormat.yMMMd(
                              Localizations.localeOf(context).toString(),
                            ).format(log.performedAt),
                            if (log.notes.isNotEmpty)
                              '${l.text('privateNotes')}: ${log.notes}',
                          ].join('\n'),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }
}

class TreatmentSittingLogForm extends StatefulWidget {
  const TreatmentSittingLogForm({
    super.key,
    required this.sitting,
    required this.onSave,
  });
  final TreatmentSitting sitting;
  final Future<void> Function(String, String, DateTime) onSave;
  @override
  State<TreatmentSittingLogForm> createState() =>
      _TreatmentSittingLogFormState();
}

class _TreatmentSittingLogFormState extends State<TreatmentSittingLogForm> {
  final _form = GlobalKey<FormState>(),
      _work = TextEditingController(),
      _notes = TextEditingController();
  DateTime _performed = DateTime.now();
  bool _saving = false, _failed = false;
  @override
  void dispose() {
    _work.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context), s = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text('${l.text('logSitting')} · ${widget.sitting.name}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _work,
                    decoration: InputDecoration(labelText: l.text('workDone')),
                    maxLines: 4,
                    maxLength: 4000,
                    validator: (v) =>
                        v?.trim().isNotEmpty == true ? null : s.requiredField,
                  ),
                  TextFormField(
                    controller: _notes,
                    decoration: InputDecoration(
                      labelText: l.text('privateNotes'),
                    ),
                    maxLines: 3,
                    maxLength: 10000,
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _performed,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (date != null && mounted) {
                        setState(() => _performed = date);
                      }
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).format(_performed),
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
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onSave(_work.text.trim(), _notes.text.trim(), _performed);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
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
