import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../revamp/prescription_preview.dart';

import '../../../../data/datasources/clinical_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import '../../../../data/datasources/workflow_models.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../core/auth/app_role.dart';

class TabNewPrescription extends StatefulWidget {
  const TabNewPrescription({
    super.key,
    this.initialPatient,
    this.initialPrescription,
    this.onSaved,
    this.initialTemplate,
    this.queueAppointmentId = '',
  });

  final PatientModel? initialPatient;
  final PrescriptionModel? initialPrescription;
  final VoidCallback? onSaved;
  final PrescriptionTemplate? initialTemplate;
  final String queueAppointmentId;

  @override
  State<TabNewPrescription> createState() => _TabNewPrescriptionState();
}

class _TabNewPrescriptionState extends State<TabNewPrescription> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _age = TextEditingController();
  final _diagnosis = TextEditingController();
  final _complaints = TextEditingController();
  final _vitals = TextEditingController();
  final _investigation = TextEditingController();
  final _advice = TextEditingController();
  final _privateNotes = TextEditingController();
  bool _notesLoaded = true;
  PrescriptionTemplate? _activeTemplate;
  final List<_MedicineControllers> _medicines = [_MedicineControllers()];
  String _gender = '';
  DateTime _visitDate = DateTime.now();
  DateTime? _followUpDate;
  bool _saving = false;
  late bool _shareWithPatient;
  String? _draftPrescriptionId;

  @override
  void initState() {
    super.initState();
    final patient = widget.initialPatient;
    final existing = widget.initialPrescription;
    final sourcePatient = existing?.patient ?? patient;
    _shareWithPatient =
        existing?.sharedWithPatient ??
        context.read<SessionController>().sharePrescriptionsWithPatients;
    if (sourcePatient != null) {
      _firstName.text = sourcePatient.firstName;
      _middleName.text = sourcePatient.middleName;
      _lastName.text = sourcePatient.lastName;
      _phone.text = sourcePatient.phone;
      _address.text = sourcePatient.address;
      _age.text = sourcePatient.age?.toString() ?? '';
      _gender = sourcePatient.gender;
    }
    if (existing != null) {
      _notesLoaded = false;
      context
          .read<FirebaseFireStore>()
          .getPrivateVisitNotes(existing.id)
          .then((notes) {
            if (mounted) {
              setState(() {
                _privateNotes.text = notes;
                _notesLoaded = true;
              });
            }
          })
          .catchError((Object _) {
            if (mounted) setState(() => _notesLoaded = false);
          });
      _draftPrescriptionId = existing.id;
      _diagnosis.text = existing.diagnoses.join(', ');
      _complaints.text = existing.complaints;
      _vitals.text = existing.vitals;
      _investigation.text = existing.investigation;
      _advice.text = existing.advice;
      _visitDate = existing.visitDate ?? DateTime.now();
      _followUpDate = existing.followUpDate;
      _medicines.first.dispose();
      _medicines
        ..clear()
        ..addAll(
          existing.medicines.isEmpty
              ? [_MedicineControllers()]
              : existing.medicines.map(_MedicineControllers.fromModel),
        );
    }
    if (widget.initialTemplate != null) _applyTemplate(widget.initialTemplate!);
  }

  void _applyTemplate(PrescriptionTemplate value) {
    _activeTemplate = value;
    _diagnosis.text = {
      ..._diagnosis.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty),
      ...value.diagnoses,
    }.join(', ');
    void append(TextEditingController c, String text) {
      if (text.trim().isEmpty) return;
      if (c.text.trim().isEmpty) {
        c.text = text;
      } else if (!c.text.contains(text)) {
        c.text = '${c.text}\n$text';
      }
    }

    append(_complaints, value.complaints);
    append(_investigation, value.investigation);
    append(_advice, value.advice);
    final keys = _medicines
        .map((e) => e.toModel().toMap().values.join('|'))
        .toSet();
    if (_medicines.length == 1 &&
        _medicines.first.toModel().isEmpty &&
        value.medicines.isNotEmpty) {
      _medicines.removeLast().dispose();
    }
    for (final medicine in value.medicines) {
      if (keys.add(medicine.toMap().values.join('|'))) {
        _medicines.add(_MedicineControllers.fromModel(medicine));
      }
    }
  }

  Future<void> _useTemplate() async {
    final l = RevampLabels.of(context);
    final selected = await showDialog<PrescriptionTemplate>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.text('useTemplate')),
        content: SizedBox(
          width: 500,
          child: StreamBuilder<List<PrescriptionTemplate>>(
            stream: context
                .read<FirebaseFireStore>()
                .streamPrescriptionTemplates(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text(l.text('loadError'));
              if (!snapshot.hasData) return const LinearProgressIndicator();
              if (snapshot.data!.isEmpty) return Text(l.text('noTemplates'));
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in snapshot.data!)
                      ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.diagnoses.join(', ')),
                        onTap: () => Navigator.pop(dialogContext, item),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
    if (selected != null && mounted) setState(() => _applyTemplate(selected));
  }

  Future<void> _saveTemplate({bool update = false}) async {
    final l = RevampLabels.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => TemplateNamePrompt(
        initialName: update ? _activeTemplate?.name ?? '' : '',
      ),
    );
    if (name == null || !mounted) return;
    try {
      await context.read<FirebaseFireStore>().savePrescriptionTemplate(
        PrescriptionTemplate(
          id: update ? _activeTemplate?.id ?? '' : '',
          name: name,
          diagnoses: _diagnosis.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          complaints: _complaints.text,
          investigation: _investigation.text,
          advice: _advice.text,
          medicines: _medicines
              .map((e) => e.toModel())
              .where((e) => !e.isEmpty)
              .toList(),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.text('saveError'))));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _middleName,
      _lastName,
      _phone,
      _address,
      _age,
      _diagnosis,
      _complaints,
      _vitals,
      _investigation,
      _advice,
      _privateNotes,
    ]) {
      controller.dispose();
    }
    for (final medicine in _medicines) {
      medicine.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool followUp}) async {
    final initial = followUp ? (_followUpDate ?? _visitDate) : _visitDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: followUp ? _visitDate : DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (followUp) {
        _followUpDate = selected;
      } else {
        _visitDate = DateTime(
          selected.year,
          selected.month,
          selected.day,
          _visitDate.hour,
          _visitDate.minute,
        );
      }
    });
  }

  Future<void> _save({bool preview = false}) async {
    if (_saving) return;
    final strings = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final service = context.read<FirebaseFireStore>();
      _draftPrescriptionId ??= service.createPrescriptionId();
      final patient = PatientModel(
        id:
            widget.initialPrescription?.patient.id ??
            widget.initialPatient?.id ??
            '',
        firstName: _firstName.text,
        middleName: _middleName.text,
        lastName: _lastName.text,
        phone: _phone.text,
        address: _address.text,
        age: int.tryParse(_age.text),
        gender: _gender,
        userId:
            widget.initialPrescription?.patient.userId ??
            widget.initialPatient?.userId ??
            '',
        createdAt:
            (widget.initialPrescription?.patient ?? widget.initialPatient)
                ?.createdAt,
        email: (widget.initialPrescription?.patient ?? widget.initialPatient)
            ?.email,
        notificationConsent:
            (widget.initialPrescription?.patient ?? widget.initialPatient)
                ?.notificationConsent,
        locale: (widget.initialPrescription?.patient ?? widget.initialPatient)
            ?.locale,
        dateOfBirth:
            (widget.initialPrescription?.patient ?? widget.initialPatient)
                ?.dateOfBirth,
        ageUnit:
            (widget.initialPrescription?.patient ?? widget.initialPatient)
                ?.ageUnit ??
            'years',
        abhaId:
            (widget.initialPrescription?.patient ?? widget.initialPatient)
                ?.abhaId ??
            '',
        allergies:
            (widget.initialPrescription?.patient ?? widget.initialPatient)
                ?.allergies ??
            const [],
      );
      final record = PrescriptionModel(
        id: _draftPrescriptionId!,
        createdAt: widget.initialPrescription?.createdAt,
        status: widget.initialPrescription?.status ?? 'pending',
        appointmentId:
            widget.initialPrescription?.appointmentId ??
            widget.queueAppointmentId,
        patient: patient,
        diagnoses: _diagnosis.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        complaints: _complaints.text,
        vitals: _vitals.text,
        investigation: _investigation.text,
        advice: _advice.text,
        medicines: _medicines.map((item) => item.toModel()).toList(),
        sharedWithPatient:
            context.read<SessionController>().sharePrescriptionsWithPatients &&
            _shareWithPatient,
        patientUserId: patient.userId,
        visitDate: _visitDate,
        followUpDate: _followUpDate,
      );
      await service.savePrescription(
        record,
        privateNotes: _notesLoaded ? _privateNotes.text : null,
        completeQueueVisit:
            widget.initialPrescription == null &&
            widget.queueAppointmentId.isNotEmpty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.prescriptionSaved)));
      _clearForm();
      if (preview) {
        await showPrescriptionPreview(context, record);
        if (!mounted) return;
      }
      widget.onSaved?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${strings.errorMessage} $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final linkedPatient =
        widget.initialPrescription?.patient ?? widget.initialPatient;
    final dateFormat = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.newPrescription,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _useTemplate,
                        icon: const Icon(Icons.snippet_folder_outlined),
                        label: Text(
                          RevampLabels.of(context).text('useTemplate'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saveTemplate,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: Text(
                          RevampLabels.of(context).text('saveTemplate'),
                        ),
                      ),
                      if (_activeTemplate?.id.isNotEmpty == true)
                        OutlinedButton.icon(
                          onPressed: () => _saveTemplate(update: true),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(
                            RevampLabels.of(context).text('updateTemplate'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: strings.patientDetails,
                    icon: Icons.person_outline,
                    child:
                        widget.initialPatient != null &&
                            widget.initialPrescription == null
                        ? ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(
                                widget.initialPatient!.firstName.isEmpty
                                    ? '?'
                                    : widget.initialPatient!.firstName[0]
                                          .toUpperCase(),
                              ),
                            ),
                            title: Text(widget.initialPatient!.fullName),
                            subtitle: Text(
                              [
                                if (widget.initialPatient!.phone.isNotEmpty)
                                  widget.initialPatient!.phone,
                                if (widget.initialPatient!.age != null)
                                  '${widget.initialPatient!.age} ${strings.age}',
                                if (widget.initialPatient!.address.isNotEmpty)
                                  widget.initialPatient!.address,
                              ].join(' • '),
                            ),
                          )
                        : _ResponsiveFields(
                            children: [
                              _field(
                                controller: _firstName,
                                label: strings.firstName,
                                requiredText: strings.requiredField,
                              ),
                              _field(
                                controller: _middleName,
                                label: strings.middleName,
                              ),
                              _field(
                                controller: _lastName,
                                label: strings.lastName,
                              ),
                              _field(
                                controller: _phone,
                                label: strings.phone,
                                keyboardType: TextInputType.phone,
                              ),
                              _field(
                                controller: _age,
                                label: strings.age,
                                keyboardType: TextInputType.number,
                                validator: (value) =>
                                    value != null &&
                                        value.isNotEmpty &&
                                        int.tryParse(value) == null
                                    ? strings.invalidNumber
                                    : null,
                              ),
                              DropdownButtonFormField<String>(
                                initialValue: _gender.isEmpty ? null : _gender,
                                decoration: InputDecoration(
                                  labelText: strings.gender,
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'male',
                                    child: Text(strings.male),
                                  ),
                                  DropdownMenuItem(
                                    value: 'female',
                                    child: Text(strings.female),
                                  ),
                                  DropdownMenuItem(
                                    value: 'other',
                                    child: Text(strings.other),
                                  ),
                                ],
                                onChanged: (value) => _gender = value ?? '',
                              ),
                              _field(
                                controller: _address,
                                label: strings.address,
                                maxLines: 2,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: strings.clinicalDetails,
                    icon: Icons.monitor_heart_outlined,
                    child: Column(
                      children: [
                        _ResponsiveFields(
                          children: [
                            _dateField(
                              label: strings.visitDate,
                              value: dateFormat.format(_visitDate),
                              onTap: () => _pickDate(followUp: false),
                            ),
                            _dateField(
                              label: strings.followUpDate,
                              value: _followUpDate == null
                                  ? ''
                                  : dateFormat.format(_followUpDate!),
                              onTap: () => _pickDate(followUp: true),
                              onClear: _followUpDate == null
                                  ? null
                                  : () => setState(() => _followUpDate = null),
                            ),
                            _field(
                              controller: _diagnosis,
                              label: strings.diagnosis,
                              helperText: 'e.g. Diabetes, Hypertension',
                            ),
                            _field(controller: _vitals, label: strings.vitals),
                            _field(
                              controller: _complaints,
                              label: strings.chiefComplaints,
                              maxLines: 3,
                            ),
                            _field(
                              controller: _investigation,
                              label: strings.investigation,
                              maxLines: 3,
                            ),
                            _field(
                              controller: _advice,
                              label: strings.advice,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: strings.medicines,
                    icon: Icons.medication_outlined,
                    child: Column(
                      children: [
                        for (var index = 0; index < _medicines.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MedicineRow(
                              controllers: _medicines[index],
                              index: index,
                              canRemove: _medicines.length > 1,
                              onRemove: () {
                                setState(() {
                                  _medicines.removeAt(index).dispose();
                                });
                              },
                            ),
                          ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _medicines.add(_MedicineControllers()),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(strings.addMedicine),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    title: RevampLabels.of(context).text('privateNotes'),
                    icon: Icons.lock_outline,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(RevampLabels.of(context).text('privateNotesHint')),
                        const SizedBox(height: 12),
                        if (!_notesLoaded)
                          Text(RevampLabels.of(context).text('loadError')),
                        TextFormField(
                          controller: _privateNotes,
                          enabled: _notesLoaded,
                          maxLines: 4,
                          maxLength: 20000,
                          decoration: InputDecoration(
                            labelText: RevampLabels.of(
                              context,
                            ).text('privateNotes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (context
                      .watch<SessionController>()
                      .sharePrescriptionsWithPatients)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Share with patient'),
                      subtitle: Text(
                        linkedPatient?.userId.isEmpty != false
                            ? 'Available after this patient books or links an account.'
                            : 'Patient can view this prescription and medicines.',
                      ),
                      value:
                          _shareWithPatient &&
                          linkedPatient?.userId.isNotEmpty == true,
                      onChanged: linkedPatient?.userId.isNotEmpty != true
                          ? null
                          : (value) =>
                                setState(() => _shareWithPatient = value),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _save(preview: true),
                          icon: const Icon(Icons.print_outlined),
                          label: Text(
                            RevampLabels.of(context).text('savePreview'),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(strings.savePrescription),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearForm() {
    for (final controller in [
      _firstName,
      _middleName,
      _lastName,
      _phone,
      _address,
      _age,
      _diagnosis,
      _complaints,
      _vitals,
      _investigation,
      _advice,
      _privateNotes,
    ]) {
      controller.clear();
    }
    for (final medicine in _medicines) {
      medicine.dispose();
    }
    _medicines
      ..clear()
      ..add(_MedicineControllers());
    _gender = '';
    _visitDate = DateTime.now();
    _followUpDate = null;
    _draftPrescriptionId = null;
    _formKey.currentState?.reset();
    // The patient workspace stays open after save. A fresh consultation must
    // keep its linked identity even though the clinical draft is cleared.
    final patient = widget.initialPatient;
    if (patient != null && widget.initialPrescription == null) {
      _firstName.text = patient.firstName;
      _middleName.text = patient.middleName;
      _lastName.text = patient.lastName;
      _phone.text = patient.phone;
      _address.text = patient.address;
      _age.text = patient.age?.toString() ?? '';
      _gender = patient.gender;
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? requiredText,
    String? helperText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, helperText: helperText),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator:
          validator ??
          (requiredText == null
              ? null
              : (value) => value == null || value.trim().isEmpty
                    ? requiredText
                    : null),
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(onPressed: onClear, icon: const Icon(Icons.clear)),
        ),
        child: Text(value.isEmpty ? '—' : value),
      ),
    );
  }
}

class TemplateNamePrompt extends StatefulWidget {
  const TemplateNamePrompt({super.key, this.initialName = ''});
  final String initialName;
  @override
  State<TemplateNamePrompt> createState() => _TemplateNamePromptState();
}

class _TemplateNamePromptState extends State<TemplateNamePrompt> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final s = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.text('saveTemplate')),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.text('templateHint')),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                maxLength: 120,
                decoration: InputDecoration(labelText: l.text('templateName')),
                validator: (v) =>
                    v?.trim().isNotEmpty == true ? null : s.requiredField,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, _name.text.trim());
            }
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}

class _MedicineControllers {
  final name = TextEditingController();
  final dosage = TextEditingController();
  final frequency = TextEditingController();
  final duration = TextEditingController();
  final instructions = TextEditingController();

  _MedicineControllers();

  factory _MedicineControllers.fromModel(MedicineLine medicine) {
    final value = _MedicineControllers();
    value.name.text = medicine.name;
    value.dosage.text = medicine.dosage;
    value.frequency.text = medicine.frequency;
    value.duration.text = medicine.duration;
    value.instructions.text = medicine.instructions;
    return value;
  }

  MedicineLine toModel() => MedicineLine(
    name: name.text,
    dosage: dosage.text,
    frequency: frequency.text,
    duration: duration.text,
    instructions: instructions.text,
  );

  void dispose() {
    name.dispose();
    dosage.dispose();
    frequency.dispose();
    duration.dispose();
    instructions.dispose();
  }
}

class _MedicineRow extends StatelessWidget {
  const _MedicineRow({
    required this.controllers,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  final _MedicineControllers controllers;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text('${index + 1}')),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    tooltip: strings.delete,
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            _ResponsiveFields(
              children: [
                StreamBuilder<List<InventoryItem>>(
                  stream:
                      context.watch<SessionController>().can(
                        AppFeature.inventory,
                      )
                      ? context.read<FirebaseFireStore>().streamInventory()
                      : Stream.value(const <InventoryItem>[]),
                  builder: (context, snapshot) => Autocomplete<InventoryItem>(
                    initialValue: TextEditingValue(text: controllers.name.text),
                    displayStringForOption: (item) => item.name,
                    optionsBuilder: (value) {
                      final query = value.text.trim().toLowerCase();
                      if (query.isEmpty) return const <InventoryItem>[];
                      return (snapshot.data ?? const <InventoryItem>[])
                          .where(
                            (item) =>
                                item.remainingQuantity > 0 &&
                                item.name.toLowerCase().contains(query),
                          )
                          .take(8);
                    },
                    onSelected: (item) => controllers.name.text = item.name,
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (value) => controllers.name.text = value,
                            decoration: InputDecoration(
                              labelText: strings.medicine,
                              helperText:
                                  'Stock suggestions; free text = outside medicine',
                            ),
                          );
                        },
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        child: SizedBox(
                          width: 340,
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: options
                                .map(
                                  (item) => ListTile(
                                    dense: true,
                                    title: Text(item.name),
                                    subtitle: Text(
                                      '${item.remainingQuantity} ${item.unit} in stock',
                                    ),
                                    onTap: () => onSelected(item),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                TextFormField(
                  controller: controllers.dosage,
                  decoration: InputDecoration(labelText: strings.dosage),
                ),
                TextFormField(
                  controller: controllers.frequency,
                  decoration: InputDecoration(labelText: strings.frequency),
                ),
                TextFormField(
                  controller: controllers.duration,
                  decoration: InputDecoration(labelText: strings.duration),
                ),
                TextFormField(
                  controller: controllers.instructions,
                  decoration: InputDecoration(labelText: strings.instructions),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 3
            : constraints.maxWidth >= 540
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
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
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
