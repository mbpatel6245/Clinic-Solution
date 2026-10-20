import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../core/auth/app_role.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import '../../../widgets/app_design.dart';
import 'patient_workspace.dart';

Future<void> showPatientRegistration(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _PatientForm());

class PatientRegistry extends StatefulWidget {
  const PatientRegistry({super.key, this.onNewVisit, this.onOpenPatient});
  final ValueChanged<PatientModel>? onNewVisit;
  final ValueChanged<PatientModel>? onOpenPatient;
  @override
  State<PatientRegistry> createState() => _PatientRegistryState();
}

class _PatientRegistryState extends State<PatientRegistry> {
  late Stream<List<PatientModel>> _patients;
  Stream<List<PrescriptionModel>>? _visits;
  String? _clinic;
  String _query = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final clinic =
        '${session.activeClinicId}:${session.can(AppFeature.prescriptionList)}';
    if (_clinic == clinic) return;
    _clinic = clinic;
    _patients = context.read<FirebaseFireStore>().streamPatients();
    _visits = session.can(AppFeature.prescriptionList)
        ? context.read<FirebaseFireStore>().streamPrescriptions()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                l.text('patients'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              FilledButton.icon(
                onPressed: () => _addPatient(context),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(l.text('addPatient')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.text('patientHint'),
            style: const TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.text('search'),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<PatientModel>>(
            stream: _patients,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppSection(child: Text(l.text('loadError')));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final patients = snapshot.data!
                  .where(
                    (patient) => '${patient.fullName} ${patient.phone}'
                        .toLowerCase()
                        .contains(_query),
                  )
                  .toList();
              if (patients.isEmpty) {
                return AppSection(
                  child: Text(
                    l.text(_query.isEmpty ? 'noPatients' : 'noQueue'),
                  ),
                );
              }
              return StreamBuilder<List<PrescriptionModel>>(
                stream: _visits,
                builder: (context, history) => PatientDirectoryList(
                  patients: patients,
                  visits: history.hasError ? null : history.data,
                  onOpen: (patient) => _showPatient(context, patient),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addPatient(BuildContext context) async {
    await showPatientRegistration(context);
  }

  Future<void> _showPatient(BuildContext context, PatientModel patient) async {
    if (widget.onOpenPatient != null) {
      widget.onOpenPatient!(patient);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PatientWorkspace(patient: patient)),
    );
  }
}

/// Compact rows on mobile and a scannable directory table on desktop.
class PatientDirectoryList extends StatelessWidget {
  const PatientDirectoryList({
    super.key,
    required this.patients,
    required this.onOpen,
    this.visits,
  });
  final List<PatientModel> patients;
  final List<PrescriptionModel>? visits;
  final ValueChanged<PatientModel> onOpen;
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final s = AppLocalizations.of(context)!;
    String age(PatientModel p) => [
      if (p.age != null) '${p.age} ${l.text(p.ageUnit)}',
      if (p.gender.isNotEmpty) l.text(p.gender),
    ].join(' · ');
    List<PrescriptionModel> history(PatientModel p) =>
        (visits ?? [])
            .where((v) => p.id.isNotEmpty && v.patient.id == p.id)
            .toList()
          ..sort(
            (a, b) => (b.visitDate ?? b.createdAt ?? DateTime(1970)).compareTo(
              a.visitDate ?? a.createdAt ?? DateTime(1970),
            ),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              for (final patient in patients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.soft,
                        foregroundColor: AppColors.primary,
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(patient.fullName),
                      subtitle: Text(
                        [
                          age(patient),
                          if (patient.phone.isNotEmpty) patient.phone,
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => onOpen(patient),
                    ),
                  ),
                ),
            ],
          );
        }
        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                horizontalMargin: 16,
                columnSpacing: 24,
                headingTextStyle: const TextStyle(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
                columns: [
                  DataColumn(label: Text(l.text('patients'))),
                  DataColumn(label: Text(s.age)),
                  DataColumn(label: Text(s.phone)),
                  if (visits != null) ...[
                    DataColumn(label: Text(l.text('lastVisit'))),
                    DataColumn(
                      label: Text(l.text('consultations')),
                      numeric: true,
                    ),
                  ],
                ],
                rows: [
                  for (final patient in patients)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            patient.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => onOpen(patient),
                        ),
                        DataCell(
                          Text(age(patient)),
                          onTap: () => onOpen(patient),
                        ),
                        DataCell(
                          Text(patient.phone.isEmpty ? '—' : patient.phone),
                        ),
                        if (visits != null) ...[
                          DataCell(
                            Text(
                              history(patient).isEmpty
                                  ? '—'
                                  : DateFormat.yMMMd(
                                      Localizations.localeOf(
                                        context,
                                      ).toString(),
                                    ).format(
                                      history(patient).first.visitDate ??
                                          history(patient).first.createdAt ??
                                          DateTime(1970),
                                    ),
                            ),
                          ),
                          DataCell(Text(history(patient).length.toString())),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PatientForm extends StatefulWidget {
  const _PatientForm();
  @override
  State<_PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<_PatientForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _last = TextEditingController(),
      _phone = TextEditingController(),
      _age = TextEditingController(),
      _address = TextEditingController(),
      _email = TextEditingController(),
      _abha = TextEditingController(),
      _allergies = TextEditingController();
  String _ageUnit = 'years', _gender = '';
  DateTime? _birth;
  bool _consent = false;
  bool _saving = false, _failed = false;
  @override
  void dispose() {
    for (final c in [
      _name,
      _last,
      _phone,
      _age,
      _address,
      _email,
      _abha,
      _allergies,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final l = RevampLabels.of(context);
    return AlertDialog(
      title: Text(l.text('addPatient')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: s.firstName),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? s.requiredField : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _last,
                  decoration: InputDecoration(labelText: s.lastName),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: s.phone),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _age,
                  enabled: _birth == null,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.age),
                  validator: (v) =>
                      v == null ||
                          v.trim().isEmpty ||
                          ((int.tryParse(v) ?? -1) >= 0 &&
                              (int.tryParse(v) ?? 60001) <=
                                  switch (_ageUnit) {
                                    'years' => 150,
                                    'months' => 1800,
                                    'weeks' => 8000,
                                    _ => 60000,
                                  })
                      ? null
                      : s.invalidNumber,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final unit in ['years', 'months', 'weeks', 'days'])
                      ChoiceChip(
                        label: Text(l.text(unit)),
                        selected: _ageUnit == unit,
                        onSelected: (_) => setState(() => _ageUnit = unit),
                      ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cake_outlined),
                  label: Text(
                    '${l.text('dob')}${_birth == null ? '' : ': ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(_birth!)}'}',
                  ),
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: _birth ?? DateTime.now(),
                      firstDate: DateTime(1870),
                      lastDate: DateTime.now(),
                    );
                    if (value != null) setState(() => _birth = value);
                  },
                ),
                if (_birth != null)
                  TextButton(
                    onPressed: () => setState(() => _birth = null),
                    child: Text(s.clearFilters),
                  ),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: s.gender),
                  items: [
                    DropdownMenuItem(value: 'male', child: Text(s.male)),
                    DropdownMenuItem(value: 'female', child: Text(s.female)),
                    DropdownMenuItem(value: 'other', child: Text(s.other)),
                  ],
                  onChanged: (v) => _gender = v ?? '',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: s.email),
                  validator: (v) =>
                      v == null ||
                          v.trim().isEmpty ||
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(v.trim())
                      ? null
                      : s.validEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _abha,
                  decoration: const InputDecoration(labelText: 'ABHA ID'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _allergies,
                  decoration: InputDecoration(labelText: l.text('allergies')),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.text('consent')),
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _address,
                  decoration: InputDecoration(labelText: s.address),
                  maxLines: 2,
                ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      l.text('saveError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(),
                )
              : Text(s.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await context.read<FirebaseFireStore>().savePatientProfile(
        PatientModel(
          firstName: _name.text,
          lastName: _last.text,
          phone: _phone.text,
          age: int.tryParse(_age.text.trim()),
          ageUnit: _ageUnit,
          dateOfBirth: _birth,
          gender: _gender,
          email: _email.text.trim(),
          abhaId: _abha.text,
          allergies: _allergies.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          notificationConsent: _consent,
          address: _address.text,
          locale: Localizations.localeOf(context).languageCode,
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
