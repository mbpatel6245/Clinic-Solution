import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../data/datasources/workflow_models.dart';
import '../../../data/datasources/enterprise_models.dart';
import '../../../data/datasources/patient_intake.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/clinical_artifact.dart';
import '../domain/clinical_draft_repository.dart';
import 'clinical_artifact_labels.dart';
import 'clinical_components.dart';
import 'clinical_draft_actions.dart';
import 'clinical_artifact_review.dart';

class ClinicalArtifactEditor extends StatefulWidget {
  const ClinicalArtifactEditor({
    super.key,
    required this.patient,
    required this.kind,
    required this.repository,
    required this.scope,
    required this.authorized,
    required this.changes,
    required this.sharingEnabled,
    this.initial,
    this.draftRepositoryFactory,
    this.timezone = 'Asia/Kolkata',
  });
  final PatientModel patient;
  final ClinicalArtifactKind kind;
  final ClinicalArtifactRepository repository;
  final String scope;
  final String timezone;
  final bool Function() authorized, sharingEnabled;
  final Listenable changes;
  final ClinicalArtifact? initial;
  final ClinicalDraftRepository Function()? draftRepositoryFactory;
  @override
  State<ClinicalArtifactEditor> createState() => _ClinicalArtifactEditorState();
}

class _ClinicalArtifactEditorState extends State<ClinicalArtifactEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _tests = TextEditingController(),
      _indication = TextEditingController(),
      _planned = TextEditingController(),
      _reported = TextEditingController(),
      _source = TextEditingController(),
      _review = TextEditingController(),
      _verification = TextEditingController();
  final _rows = <_ResultFields>[];
  final _instructions = <int>{}, _vaccines = <String>{};
  late String _id;
  int _revision = 0, _rowSequence = 0;
  String _encounter = '', _plan = '', _order = '';
  bool _busy = false, _error = false;

  ClinicalArtifactSources? _sources;
  bool _sourcesError = false;
  final _operations = <String, Map<String, Object?>>{};
  bool get _allowed => mounted && widget.authorized();
  Map<String, TextEditingController> get _fields => {
    'title': _title,
    'tests': _tests,
    'indication': _indication,
    'planned': _planned,
    'reported': _reported,
    'source': _source,
    'review': _review,
    'verification': _verification,
  };
  @override
  void initState() {
    super.initState();
    _id = widget.initial?.id ?? widget.repository.newId();
    if (widget.initial != null) _apply(widget.initial!);
    if (_rows.isEmpty) _rows.add(_ResultFields('row-${_rowSequence++}'));
    _loadSources();
  }

  void _apply(ClinicalArtifact artifact) {
    if (artifact.patient.id != widget.patient.id ||
        artifact.kind != widget.kind) {
      throw const ClinicalArtifactFailure('permission-denied');
    }
    final r = artifact.input;
    _revision = artifact.revision;
    _id = artifact.id;
    _title.text = r['title']?.toString() ?? '';
    _tests.text = (r['tests'] as List? ?? []).join('\n');
    _indication.text = r['indication']?.toString() ?? '';
    _planned.text = r['planned_date']?.toString() ?? '';
    _reported.text = r['reported_date']?.toString() ?? '';
    _source.text = r['source_reference']?.toString() ?? '';
    _review.text = r['review']?.toString() ?? '';
    _verification.text = r['verification_note']?.toString() ?? '';
    _encounter = artifact.encounterId;
    _plan = r['source_plan_id']?.toString() ?? '';
    _order = r['order_id']?.toString() ?? '';
    _instructions
      ..clear()
      ..addAll((r['instruction_indices'] as List? ?? []).cast<int>());
    _vaccines
      ..clear()
      ..addAll((r['vaccination_ids'] as List? ?? []).cast<String>());
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
    for (final raw in r['observations'] as List? ?? const []) {
      _rows.add(_ResultFields.fromInput(Map<String, dynamic>.from(raw as Map)));
    }
  }

  Future<void> _loadSources() async {
    if (!mounted || !_allowed) return;
    try {
      final data = await widget.repository
          .sources(widget.patient.id)
          .timeout(const Duration(seconds: 20));
      if (_allowed) {
        setState(() {
          _sources = data;
          _sourcesError = false;
        });
      }
    } catch (_) {
      if (_allowed) setState(() => _sourcesError = true);
    }
  }

  Map<String, Object?> _capture() => {
    'v': 1,
    'patient': widget.patient.id,
    'kind': widget.kind.name,
    'id': _id,
    'revision': _revision,
    'fields': _fields.map((k, v) => MapEntry(k, v.text)),
    'encounter': _encounter,
    'plan': _plan,
    'order': _order,
    'instructions': _instructions.toList(),
    'vaccines': _vaccines.toList(),
    'rows': _rows.map((r) => r.capture()).toList(),
  };
  void _restore(Map<String, Object?> value) {
    if (!_allowed ||
        value['v'] != 1 ||
        value['patient'] != widget.patient.id ||
        value['kind'] != widget.kind.name ||
        (widget.initial != null && value['id'] != widget.initial!.id)) {
      throw StateError('Recovery identity mismatch');
    }
    final fields = Map<String, String>.from(value['fields'] as Map),
        rows = (value['rows'] as List)
            .map(
              (v) => _ResultFields.fromRecovery(
                Map<String, dynamic>.from(v as Map),
              ),
            )
            .toList();
    final revision = (value['revision'] as num).toInt();
    if (revision < 0 || rows.length > 50) {
      throw StateError('Unsupported recovery');
    }
    setState(() {
      _id = value['id'] as String;
      _revision = revision;
      for (final entry in _fields.entries) {
        entry.value.text = fields[entry.key] ?? '';
      }
      _encounter = value['encounter'] as String;
      _plan = value['plan'] as String;
      _order = value['order'] as String;
      _instructions
        ..clear()
        ..addAll((value['instructions'] as List).cast<int>());
      _vaccines
        ..clear()
        ..addAll((value['vaccines'] as List).cast<String>());
      for (final row in _rows) {
        row.dispose();
      }
      _rows
        ..clear()
        ..addAll(rows);
      _error = false;
    });
  }

  Map<String, Object?> _record() => switch (widget.kind) {
    ClinicalArtifactKind.labOrder => {
      'title': _title.text,
      'tests': _tests.text
          .split(RegExp(r'\r?\n'))
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList(),
      'planned_date': _planned.text,
      'indication': _indication.text,
    },
    ClinicalArtifactKind.labResult => {
      'title': _title.text,
      'order_id': _order,
      'reported_date': _reported.text,
      'source_reference': _source.text,
      'review': _review.text,
      'observations': _rows.map((r) => r.input()).toList(),
    },
    ClinicalArtifactKind.carePlan => {
      'title': _title.text,
      'instruction_indices': _instructions.toList()..sort(),
      'source_plan_id': _plan,
      'vaccination_ids': _vaccines.toList()..sort(),
      'verification_note': _verification.text,
    },
  };
  Future<void> _save() async {
    if (_busy || !_allowed || !_form.currentState!.validate()) return;
    final request = <String, Object?>{
      'artifactId': _id,
      'artifactKind': widget.kind.name,
      'patientId': widget.patient.id,
      'action': 'saveDraft',
      'expectedRevision': _revision,
      'encounterId': _encounter,
      'record': _record(),
    };
    final command = _operations.putIfAbsent(
      jsonEncode(request),
      () => {...request, 'operationId': widget.repository.newId()},
    );
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      await widget.repository.command(command);
      final saved = await widget.repository.load(_id);
      if (!mounted || !_allowed) return;
      setState(() => _apply(saved));
      final next = await Navigator.of(context).push<ClinicalArtifact>(
        MaterialPageRoute(
          builder: (_) => ClinicalArtifactReviewScreen(
            initial: saved,
            repository: widget.repository,
            authorized: () => _allowed,
            changes: widget.changes,
            sharingEnabled: widget.sharingEnabled,
          ),
        ),
      );
      if (!mounted || !_allowed) return;
      if (next != null) {
        setState(() => _apply(next));
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (_allowed) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseDate(
    TextEditingController field, {
    required bool future,
  }) async {
    final today = DateUtils.dateOnly(
          ClinicSchedule.local(
            ClinicProfile(id: 'scope', name: '', timezone: widget.timezone),
            DateTime.now(),
          ),
        ),
        minimum = future ? today : DateTime(1900),
        maximum = future ? DateTime(2100) : today;
    var initial = DateTime.tryParse(field.text) ?? today;
    if (initial.isBefore(minimum)) initial = minimum;
    if (initial.isAfter(maximum)) initial = maximum;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minimum,
      lastDate: maximum,
    );
    if (selected != null && _allowed) {
      setState(() => field.text = DateFormat('yyyy-MM-dd').format(selected));
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int lines = 1,
    int max = 4000,
  }) => TextFormField(
    controller: controller,
    maxLines: lines,
    maxLength: max,
    decoration: InputDecoration(labelText: label),
    validator: (v) => required && v?.trim().isNotEmpty != true
        ? AppLocalizations.of(context)!.requiredField
        : null,
  );
  Widget _date(
    TextEditingController field,
    String label, {
    required bool future,
  }) => TextFormField(
    controller: field,
    readOnly: true,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: const Icon(Icons.calendar_today_outlined),
    ),
    onTap: () => _chooseDate(field, future: future),
    validator: (v) {
      final parsed = DateTime.tryParse(v ?? '');
      return parsed == null || DateFormat('yyyy-MM-dd').format(parsed) != v
          ? AppLocalizations.of(context)!.requiredField
          : null;
    },
  );
  Widget _dropdown(
    String label,
    String value,
    List<(String, String)> choices,
    ValueChanged<String> changed, {
    bool required = false,
  }) {
    final available = choices.any((v) => v.$1 == value),
        l = ArtifactLabels.of(context);
    return DropdownButtonFormField<String>(
      key: ValueKey((label, value, choices.map((v) => v.$1).join('|'))),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in choices)
          DropdownMenuItem(
            value: option.$1,
            child: Text(option.$2, softWrap: true),
          ),
        if (!available)
          DropdownMenuItem(
            value: value,
            enabled: false,
            child: Text('$value · ${l('sourcesUnavailable')}'),
          ),
      ],
      onChanged: _busy ? null : (v) => setState(() => changed(v ?? '')),
      validator: (v) => required && (v == null || v.isEmpty)
          ? AppLocalizations.of(context)!.requiredField
          : null,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.changes,
    builder: (context, _) {
      final l = ArtifactLabels.of(context),
          c = ClinicalLabels.of(context),
          s = AppLocalizations.of(context)!;
      if (!_allowed) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(c('remoteError'))),
        );
      }
      final source = _sources?.encounters
          .where((e) => e['id'] == _encounter)
          .firstOrNull;
      final advice = source?['record'] is Map
          ? source!['record']['advice']
                    ?.toString()
                    .split(RegExp(r'\r?\n'))
                    .map((v) => v.trim())
                    .where((v) => v.isNotEmpty)
                    .toList() ??
                <String>[]
          : <String>[];
      final entry = ClinicalCard(
        title: l(widget.kind.name),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(_title, l('title'), required: true, max: 200),
              const SizedBox(height: 16),
              if (widget.kind == ClinicalArtifactKind.labOrder) ...[
                _field(
                  _tests,
                  l('tests'),
                  required: true,
                  lines: 4,
                  max: 10000,
                ),
                const SizedBox(height: 16),
                _date(_planned, l('plannedDate'), future: true),
                const SizedBox(height: 16),
                _field(_indication, l('indication'), lines: 3),
              ],
              if (widget.kind == ClinicalArtifactKind.labResult) ...[
                _dropdown(l('order'), _order, [
                  ('', l('externalReport')),
                  for (final order in _sources?.orders ?? <ClinicalArtifact>[])
                    if (order.orderStatus == 'collected')
                      (order.id, '${order.title} · ${order.id}'),
                ], (v) => _order = v),
                const SizedBox(height: 16),
                _date(_reported, l('reportedDate'), future: false),
                const SizedBox(height: 16),
                _field(_source, l('source'), required: true, max: 1000),
                const SizedBox(height: 16),
                for (final row in _rows)
                  Padding(
                    key: ObjectKey(row),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_rows.length > 1)
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  tooltip: s.delete,
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _rows.remove(row);
                                          row.dispose();
                                        }),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            _field(
                              row.analyte,
                              l('analyte'),
                              required: true,
                              max: 200,
                            ),
                            const SizedBox(height: 12),
                            ArtifactFieldGrid(
                              children: [
                                TextFormField(
                                  controller: row.value,
                                  decoration: InputDecoration(
                                    labelText: l('value'),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    if (v?.trim().isNotEmpty != true) {
                                      return s.requiredField;
                                    }
                                    final number = double.tryParse(v!);
                                    return number != null && !number.isFinite
                                        ? s.invalidNumber
                                        : null;
                                  },
                                ),
                                TextFormField(
                                  controller: row.unit,
                                  decoration: InputDecoration(
                                    labelText: l('unit'),
                                  ),
                                  validator: (v) =>
                                      row.numeric &&
                                          v?.trim().isNotEmpty != true
                                      ? s.requiredField
                                      : null,
                                ),
                                for (final bound in [
                                  (row.lower, 'lower'),
                                  (row.upper, 'upper'),
                                ])
                                  TextFormField(
                                    controller: bound.$1,
                                    decoration: InputDecoration(
                                      labelText: l(bound.$2),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    validator: (v) {
                                      if (v?.trim().isEmpty != false) {
                                        return null;
                                      }
                                      if (!row.numeric ||
                                          double.tryParse(v!)?.isFinite !=
                                              true) {
                                        return s.invalidNumber;
                                      }
                                      if (bound.$2 == 'upper' &&
                                          double.tryParse(row.lower.text) !=
                                              null &&
                                          double.parse(v) <
                                              double.parse(row.lower.text)) {
                                        return s.invalidNumber;
                                      }
                                      return null;
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_rows.length < 50)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _rows.add(
                              _ResultFields(
                                'row-${_rowSequence++}-${DateTime.now().microsecondsSinceEpoch}',
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.add),
                    label: Text(l('addRow')),
                  ),
                const SizedBox(height: 16),
                _field(
                  _review,
                  l('reviewNote'),
                  required: true,
                  lines: 4,
                  max: 10000,
                ),
              ],
              if (widget.kind == ClinicalArtifactKind.carePlan) ...[
                FormField<bool>(
                  validator: (_) => _instructions.isEmpty && _plan.isEmpty
                      ? s.requiredField
                      : null,
                  builder: (state) => state.hasError
                      ? Text(
                          state.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Text(l('sourceHint')),
                const SizedBox(height: 16),
                _dropdown(
                  l('encounter'),
                  _encounter,
                  [
                    ('', l('noEncounter')),
                    for (final encounter
                        in _sources?.encounters ?? <Map<String, dynamic>>[])
                      (
                        encounter['id'].toString(),
                        '${encounter['id']} · ${encounter['state']}',
                      ),
                  ],
                  (v) {
                    _encounter = v;
                    _instructions.clear();
                  },
                  required: true,
                ),
                const SizedBox(height: 16),
                Text(
                  l('instructions'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                for (var index = 0; index < advice.length; index++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(advice[index]),
                    value: _instructions.contains(index),
                    onChanged: _busy
                        ? null
                        : (checked) => setState(() {
                            checked == true
                                ? _instructions.add(index)
                                : _instructions.remove(index);
                          }),
                  ),
                const SizedBox(height: 16),
                _dropdown(l('sourcePlan'), _plan, [
                  ('', l('noPlan')),
                  for (final plan
                      in _sources?.plans ?? <Map<String, dynamic>>[])
                    (plan['id'].toString(), plan['name']?.toString() ?? ''),
                ], (v) => _plan = v),
                const SizedBox(height: 16),
                Text(
                  l('vaccines'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(l('unknownHistory')),
                for (final vaccination
                    in _sources?.vaccinations ?? <Map<String, dynamic>>[])
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      vaccination['vaccine']?.toString() ?? c('noData'),
                    ),
                    subtitle: Text(
                      workflowDate(vaccination['administered_at']) == null
                          ? c('noData')
                          : DateFormat.yMMMd(l.language).format(
                              workflowDate(vaccination['administered_at'])!,
                            ),
                    ),
                    value: _vaccines.contains(vaccination['id']),
                    onChanged:
                        _busy ||
                            workflowDate(vaccination['administered_at']) == null
                        ? null
                        : (checked) => setState(() {
                            checked == true
                                ? _vaccines.add(vaccination['id'].toString())
                                : _vaccines.remove(vaccination['id']);
                          }),
                  ),
                if (_vaccines.isNotEmpty)
                  _field(
                    _verification,
                    l('verification'),
                    required: true,
                    lines: 3,
                  ),
              ],
              const SizedBox(height: 20),
              if (_error) Text(c('remoteError')),
              FilledButton.icon(
                key: const ValueKey('artifact-save-review'),
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(l('saveReview')),
              ),
            ],
          ),
        ),
      );
      final sidebar = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClinicalCard(
            title: c('draft'),
            child: Text(
              widget.kind == ClinicalArtifactKind.carePlan
                  ? l('sourceHint')
                  : l('separateStatus'),
            ),
          ),
          const SizedBox(height: 16),
          if (_sourcesError) Text(l('sourcesUnavailable')),
          if (_sourcesError)
            TextButton(onPressed: _loadSources, child: Text(c('reload'))),
          ClinicalDraftActions(
            key: ValueKey(widget.scope),
            scope: widget.scope,
            authorized: () => _allowed && !_busy,
            capture: _capture,
            restore: _restore,
            repositoryFactory: widget.draftRepositoryFactory,
          ),
        ],
      );
      return Theme(
        data: UviloTheme.light,
        child: PopScope(
          canPop: !_busy,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                l(
                  widget.kind == ClinicalArtifactKind.labOrder
                      ? 'newOrder'
                      : widget.kind == ClinicalArtifactKind.labResult
                      ? 'newResult'
                      : 'newCare',
                ),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1250),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClinicalPatientBanner(
                        patient: widget.patient,
                        encounter: _encounter,
                      ),
                      const SizedBox(height: 20),
                      ClinicalEditorColumns(
                        sidebar: sidebar,
                        content: AbsorbPointer(absorbing: _busy, child: entry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ResultFields {
  _ResultFields(this.key);
  final String key;
  final analyte = TextEditingController(),
      value = TextEditingController(),
      unit = TextEditingController(),
      lower = TextEditingController(),
      upper = TextEditingController();
  bool get numeric => double.tryParse(value.text)?.isFinite == true;
  Map<String, Object?> input() => {
    'key': key,
    'analyte': analyte.text,
    'value': numeric ? double.parse(value.text) : null,
    'text_result': numeric ? '' : value.text,
    'unit': unit.text,
    'lower': lower.text.isEmpty ? null : double.tryParse(lower.text),
    'upper': upper.text.isEmpty ? null : double.tryParse(upper.text),
  };
  Map<String, String> capture() => {
    'key': key,
    'analyte': analyte.text,
    'value': value.text,
    'unit': unit.text,
    'lower': lower.text,
    'upper': upper.text,
  };
  factory _ResultFields.fromRecovery(Map<String, dynamic> value) {
    final row = _ResultFields(value['key'] as String);
    row.analyte.text = value['analyte'] as String;
    row.value.text = value['value'] as String;
    row.unit.text = value['unit'] as String;
    row.lower.text = value['lower'] as String;
    row.upper.text = value['upper'] as String;
    return row;
  }
  factory _ResultFields.fromInput(Map<String, dynamic> value) =>
      _ResultFields.fromRecovery({
        'key': value['key'],
        'analyte': value['analyte'],
        'value':
            value['value']?.toString() ??
            value['text_result']?.toString() ??
            '',
        'unit': value['unit'] ?? '',
        'lower': value['lower']?.toString() ?? '',
        'upper': value['upper']?.toString() ?? '',
      });
  void dispose() {
    for (final field in [analyte, value, unit, lower, upper]) {
      field.dispose();
    }
  }
}

class ArtifactFieldGrid extends StatelessWidget {
  const ArtifactFieldGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 700 ? 2 : 1,
          width = (box.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}
