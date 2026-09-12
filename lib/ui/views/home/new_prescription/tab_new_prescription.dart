import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/datasources/clinical_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';

class TabNewPrescription extends StatefulWidget {
  const TabNewPrescription({
    super.key,
    this.initialPatient,
    this.initialPrescription,
    this.onSaved,
  });

  final PatientModel? initialPatient;
  final PrescriptionModel? initialPrescription;
  final VoidCallback? onSaved;

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
  final List<_MedicineControllers> _medicines = [_MedicineControllers()];
  String _gender = '';
  DateTime _visitDate = DateTime.now();
  DateTime? _followUpDate;
  bool _saving = false;
  String? _draftPrescriptionId;

  @override
  void initState() {
    super.initState();
    final patient = widget.initialPatient;
    final existing = widget.initialPrescription;
    final sourcePatient = existing?.patient ?? patient;
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

  Future<void> _save() async {
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
        createdAt: widget.initialPatient?.createdAt,
      );
      await service.savePrescription(
        PrescriptionModel(
          id: _draftPrescriptionId!,
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
          visitDate: _visitDate,
          followUpDate: _followUpDate,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.prescriptionSaved)));
      _clearForm();
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
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(strings.savePrescription),
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
                TextFormField(
                  controller: controllers.name,
                  decoration: InputDecoration(labelText: strings.medicine),
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
