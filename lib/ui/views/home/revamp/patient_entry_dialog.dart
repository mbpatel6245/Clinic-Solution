import '../../../../features/patients/data/registration_draft_store.dart';
import '../../../../features/patients/presentation/registration_review.dart';
import '../../../../features/patients/presentation/patient_labels.dart';
import '../../../../shared/presentation/guarded_dialog_content.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/auth/app_role.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../data/datasources/patient_intake.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import '../../../widgets/app_design.dart';

Future<PatientEntryResult?> showPatientEntry(
  BuildContext context, {
  PatientEntryMode mode = PatientEntryMode.registration,
  DateTime? slot,
  String? slotLabel,
  PatientModel? initialPatient,
}) {
  final service = context.read<FirebaseFireStore>();
  final session = context.read<SessionController>();
  final clinic = session.activeClinicId;
  final userId = FirebaseAuth.instance.currentUser?.uid;
  return showDialog<PatientEntryResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => GuardedDialogContent(
      changes: session,
      isAuthorized: () =>
          session.activeClinicId == clinic &&
          FirebaseAuth.instance.currentUser?.uid == userId &&
          session.can(AppFeature.patients),
      message: RevampLabels.of(context).text('clinicChanged'),
      child: PatientEntryDialog(
        mode: mode,
        reviewNewPatients: true,
        authorizationChanges: session,
        isAuthorized: () =>
            session.activeClinicId == clinic &&
            FirebaseAuth.instance.currentUser?.uid == userId &&
            session.can(AppFeature.patients),
        draftScope: mode == PatientEntryMode.registration && userId != null
            ? RegistrationDraftStore.scope(
                Firebase.app().options.projectId,
                userId,
                clinic,
              )
            : null,
        slot: slot,
        slotLabel: slotLabel,
        initialPatient: initialPatient,
        canQueue: session.can(AppFeature.reception),
        canOpen: session.can(AppFeature.patients),
        patients: service.streamPatients,
        newPatientId: service.createPatientId,
        newAppointmentId: service.createAppointmentId,
        onSubmit: (entry) async {
          if (FirebaseAuth.instance.currentUser?.uid != userId ||
              session.activeClinicId != clinic ||
              !session.can(AppFeature.patients) ||
              (entry.action == PatientEntryAction.queue &&
                  !session.can(AppFeature.reception)) ||
              (entry.action == PatientEntryAction.booked &&
                  !session.can(AppFeature.appointments))) {
            throw const PatientEntryException('clinicChanged');
          }
          final result = await service.submitPatientEntry(
            entry,
            clinicId: clinic,
          );
          if (FirebaseAuth.instance.currentUser?.uid != userId ||
              session.activeClinicId != clinic) {
            throw const PatientEntryException('clinicChanged');
          }
          return PatientEntryResult(
            result.patient,
            result.action,
            appointment: result.appointment,
            clinicId: clinic,
          );
        },
      ),
    ),
  );
}

class PatientEntryDialog extends StatefulWidget {
  const PatientEntryDialog({
    super.key,
    required this.patients,
    required this.newPatientId,
    required this.newAppointmentId,
    required this.onSubmit,
    this.mode = PatientEntryMode.registration,
    this.slot,
    this.slotLabel,
    this.initialPatient,
    this.reviewNewPatients = false,
    this.authorizationChanges,
    this.isAuthorized,
    this.draftScope,
    this.canQueue = true,
    this.canOpen = true,
  });
  final Stream<List<PatientModel>> Function() patients;
  final String Function() newPatientId, newAppointmentId;
  final Future<PatientEntryResult> Function(PatientEntrySubmission) onSubmit;
  final PatientEntryMode mode;
  final DateTime? slot;
  final String? slotLabel;
  final PatientModel? initialPatient;
  final bool canQueue, canOpen;
  final bool reviewNewPatients;
  final Listenable? authorizationChanges;
  final bool Function()? isAuthorized;
  final String? draftScope;
  @override
  State<PatientEntryDialog> createState() => _PatientEntryDialogState();
}

class _PatientEntryDialogState extends State<PatientEntryDialog> {
  int _draftRevision = 0;
  final _form = GlobalKey<FormState>();
  final _existingPanel = GlobalKey();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _country = TextEditingController(text: '+91'),
      _abha = TextEditingController(),
      _age = TextEditingController(),
      _otherAllergy = TextEditingController(),
      _search = TextEditingController();
  String _unit = 'years', _gender = '', _query = '';
  DateTime? _birth, _queueTime;
  String? _patientId, _visitId, _error;
  final _allergies = <String>{};
  bool _existing = false,
      _consent = false,
      _send = false,
      _busy = false,
      _dob = false;
  Stream<List<PatientModel>>? _patients;
  @override
  void initState() {
    super.initState();
    _existing = widget.mode == PatientEntryMode.booking;
    if (widget.initialPatient != null) {
      _existing = true;
      _search.text = _query = widget.initialPatient!.fullName;
    }
    if (_existing) _patients = widget.patients();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _country,
      _abha,
      _age,
      _otherAllergy,
      _search,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _draft(bool restore) async {
    final scope = widget.draftScope;
    if (scope == null || _busy) return;
    final l = PatientLabels.of(context), password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l(restore ? 'draftRestore' : 'draftSave')),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l('draftHint')),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(labelText: l('passphrase')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l('continue')),
          ),
        ],
      ),
    );
    final secret = password.text;
    password.dispose();
    if (accepted != true || !mounted) return;
    if (secret.length < 16) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l('passphrase'))));
      return;
    }
    setState(() => _busy = true);
    final store = RegistrationDraftStore.open();
    try {
      if (restore) {
        final saved = await store.restore(scope, secret);
        if (!mounted) return;
        if (saved == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l('draftMissing'))));
          return;
        }
        final p = saved.payload;
        setState(() {
          _draftRevision = saved.revision;
          _name.text = p['name'] as String? ?? '';
          _email.text = p['email'] as String? ?? '';
          _phone.text = p['phone'] as String? ?? '';
          _country.text = p['country'] as String? ?? '+91';
          _age.text = p['age'] as String? ?? '';
          _abha.text = p['abha'] as String? ?? '';
          _otherAllergy.text = p['otherAllergy'] as String? ?? '';
          _unit = p['unit'] as String? ?? 'years';
          _gender = p['gender'] as String? ?? '';
          _birth = DateTime.tryParse(p['birth'] as String? ?? '');
          _dob = p['dob'] == true;
          _consent = p['consent'] == true;
          _patientId = p['patientId'] as String?;
          _visitId = p['visitId'] as String?;
          _allergies
            ..clear()
            ..addAll((p['allergies'] as List? ?? []).cast<String>());
        });
      } else {
        _patientId ??= widget.newPatientId();
        _visitId ??= widget.newAppointmentId();
        _draftRevision = await store.save(
          scope,
          {
            'name': _name.text,
            'email': _email.text,
            'phone': _phone.text,
            'country': _country.text,
            'age': _age.text,
            'abha': _abha.text,
            'otherAllergy': _otherAllergy.text,
            'unit': _unit,
            'gender': _gender,
            'birth': _birth?.toIso8601String(),
            'dob': _dob,
            'consent': _consent,
            'patientId': _patientId,
            'visitId': _visitId,
            'allergies': _allergies.toList(),
          },
          secret,
          expectedRevision: _draftRevision,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l('draftSaved'))));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l('draftError'))));
      }
    } finally {
      await store.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _booking => widget.mode == PatientEntryMode.booking;
  void _switch(int index) => setState(() {
    _existing = index == 1;
    if (_existing) _patients ??= widget.patients();
    _error = null;
  });
  String _phoneValue() {
    final phone = _phone.text.trim();
    if (phone.isEmpty) return '';
    if (phone.startsWith('+')) return '+${phone.replaceAll(RegExp(r'\D'), '')}';
    return '+${_country.text.replaceAll(RegExp(r'\D'), '')}${phone.replaceAll(RegExp(r'\D'), '')}';
  }

  Future<void> _submit(
    PatientEntryAction action, [
    PatientModel? existing,
  ]) async {
    if (_busy || (existing == null && !_form.currentState!.validate())) return;
    if (_booking && widget.slot == null) return;
    final locale = Localizations.localeOf(context).languageCode;
    _patientId ??= widget.newPatientId();
    _visitId ??= widget.newAppointmentId();
    _queueTime ??= DateTime.now();
    final patient =
        existing ??
        PatientModel(
          id: _patientId!,
          firstName: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phoneValue(),
          gender: _gender,
          age: _dob ? null : int.tryParse(_age.text),
          ageUnit: _unit,
          dateOfBirth: _dob ? _birth : null,
          abhaId: _abha.text.trim(),
          allergies: [
            ..._allergies,
            ..._otherAllergy.text
                .split(',')
                .map((a) => a.trim())
                .where((a) => a.isNotEmpty),
          ],
          notificationConsent: _consent,
          locale: locale,
        );
    if (_booking && _send && patient.notificationConsent != true) {
      setState(() => _error = 'consentRequired');
      return;
    }
    if (existing == null && widget.reviewNewPatients) {
      setState(() => _busy = true);
      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RegistrationReview(
          patient: patient,
          patients: widget.patients(),
          authorizationChanges: widget.authorizationChanges,
          isAuthorized: widget.isAuthorized,
        ),
      );
      if (!mounted) return;
      if (approved != true) {
        setState(() => _busy = false);
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(
        PatientEntrySubmission(
          patient: patient,
          isNew: existing == null,
          careConsentRecorded: existing == null && widget.reviewNewPatients,
          action: action,
          appointmentId: _visitId!,
          scheduledAt: action == PatientEntryAction.booked
              ? widget.slot
              : _queueTime,
          sendConfirmation:
              _booking && _send && patient.notificationConsent == true,
        ),
      );
      if (_draftRevision > 0 && widget.draftScope != null) {
        final drafts = RegistrationDraftStore.open();
        try {
          await drafts.remove(widget.draftScope!, _draftRevision);
        } catch (_) {
          /* A newer draft must be retained; registration already committed. */
        } finally {
          await drafts.close();
        }
      }
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is PatientEntryException ? error.label : 'saveError';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context), s = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final size = MediaQuery.sizeOf(context);
    Widget field(
      TextEditingController controller,
      String label, {
      TextInputType? type,
      String? hint,
      String? Function(String?)? validate,
    }) => TextFormField(
      controller: controller,
      enabled: !_busy,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: validate,
    );
    String? required(String? value) =>
        value?.trim().isNotEmpty == true ? null : s.requiredField;
    final details = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
            [
                  field(_name, '${s.patientName} *', validate: required),
                  field(
                    _email,
                    s.email,
                    type: TextInputType.emailAddress,
                    validate: (v) =>
                        v == null ||
                            v.trim().isEmpty ||
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim())
                        ? null
                        : s.validEmail,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 84,
                        child: field(
                          _country,
                          l.text('countryCode'),
                          type: TextInputType.phone,
                          validate: (v) =>
                              _phone.text.trim().isEmpty ||
                                  RegExp(
                                    r'^\+?\d{1,4}$',
                                  ).hasMatch(v?.trim() ?? '')
                              ? null
                              : l.text('invalidPhone'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: field(
                          _phone,
                          s.phone,
                          type: TextInputType.phone,
                          validate: (v) =>
                              v == null ||
                                  v.trim().isEmpty ||
                                  RegExp(
                                    r'^\+?\d{6,15}$',
                                  ).hasMatch(_phoneValue())
                              ? null
                              : l.text('invalidPhone'),
                        ),
                      ),
                    ],
                  ),
                  field(
                    _abha,
                    'ABHA ID',
                    hint: l.text('abhaHint'),
                    validate: (v) =>
                        v == null ||
                            v.trim().isEmpty ||
                            RegExp(r'^\d{14}$').hasMatch(v.trim())
                        ? null
                        : l.text('invalidAbha'),
                  ),
                  Text(s.age),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final unit in [
                        'years',
                        'months',
                        'weeks',
                        'days',
                        'dob',
                      ])
                        ChoiceChip(
                          label: Text(l.text(unit)),
                          selected: unit == 'dob'
                              ? _dob
                              : !_dob && unit == _unit,
                          onSelected: _busy
                              ? null
                              : (_) => setState(() {
                                  _dob = unit == 'dob';
                                  if (!_dob) _unit = unit;
                                }),
                        ),
                    ],
                  ),
                  if (_dob)
                    FormField<DateTime>(
                      validator: (_) => _birth == null ? s.requiredField : null,
                      builder: (state) => InkWell(
                        onTap: _busy
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _birth ?? DateTime.now(),
                                  firstDate: DateTime(1870),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null && mounted) {
                                  setState(() {
                                    _birth = date;
                                    state.didChange(date);
                                  });
                                }
                              },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l.text('dob'),
                            errorText: state.errorText,
                            suffixIcon: const Icon(
                              Icons.calendar_today_outlined,
                            ),
                          ),
                          child: Text(
                            _birth == null
                                ? l.text('selectDate')
                                : DateFormat.yMMMd(locale).format(_birth!),
                          ),
                        ),
                      ),
                    )
                  else
                    field(
                      _age,
                      s.age,
                      type: TextInputType.number,
                      validate: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final age = int.tryParse(v);
                        final maximum = switch (_unit) {
                          'years' => 150,
                          'months' => 1800,
                          'weeks' => 8000,
                          _ => 60000,
                        };
                        return age != null && age >= 0 && age <= maximum
                            ? null
                            : s.invalidNumber;
                      },
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: _gender.isEmpty ? null : _gender,
                    decoration: InputDecoration(labelText: '${s.gender} *'),
                    validator: required,
                    items: [
                      for (final gender in ['male', 'female', 'other'])
                        DropdownMenuItem(
                          value: gender,
                          child: Text(l.text(gender)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _gender = value ?? ''),
                  ),
                  Text(l.text('allergies')),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final allergy in [
                        'Penicillin',
                        'Sulfa',
                        'NSAIDs',
                        'None known',
                      ])
                        FilterChip(
                          label: Text(
                            allergy == 'None known'
                                ? l.text('noneKnown')
                                : allergy,
                          ),
                          selected: _allergies.contains(allergy),
                          onSelected: _busy
                              ? null
                              : (selected) => setState(() {
                                  if (allergy == 'None known' && selected) {
                                    _allergies.clear();
                                    _otherAllergy.clear();
                                  } else if (selected) {
                                    _allergies.remove('None known');
                                  }
                                  selected
                                      ? _allergies.add(allergy)
                                      : _allergies.remove(allergy);
                                }),
                        ),
                    ],
                  ),
                  TextFormField(
                    controller: _otherAllergy,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l.text('otherAllergy'),
                    ),
                    onChanged: (value) {
                      if (value.trim().isNotEmpty &&
                          _allergies.contains('None known')) {
                        setState(() => _allergies.remove('None known'));
                      }
                    },
                  ),
                  if (widget.draftScope != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _busy ? null : () => _draft(false),
                          child: Text(PatientLabels.of(context)('draftSave')),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _draft(true),
                          child: Text(
                            PatientLabels.of(context)('draftRestore'),
                          ),
                        ),
                      ],
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.text('consent')),
                    value: _consent,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            _consent = v;
                            if (!v) _send = false;
                          }),
                  ),
                ]
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: child,
                  ),
                )
                .toList(),
      ),
    );
    Widget existingPatients() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: l.text('searchPatients'),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
        const SizedBox(height: 16),
        if (_query.length < 2)
          Text(l.text('typeToSearch'))
        else
          StreamBuilder<List<PatientModel>>(
            stream: _patients,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text(l.text('loadError')),
                    TextButton(
                      onPressed: () =>
                          setState(() => _patients = widget.patients()),
                      child: Text(l.text('retry')),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final query = _query.toLowerCase();
              final digits = query.replaceAll(RegExp(r'\D'), '');
              final matches = snapshot.data!
                  .where(
                    (p) =>
                        p.fullName.toLowerCase().contains(query) ||
                        (digits.length >= 2 &&
                            p.phone
                                .replaceAll(RegExp(r'\D'), '')
                                .contains(digits)),
                  )
                  .take(20)
                  .toList();
              if (matches.isEmpty) return Text(l.text('noPatientMatches'));
              return Column(
                children: [
                  for (final patient in matches)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(patient.fullName),
                              subtitle: Text(
                                [
                                  if (patient.phone.isNotEmpty) patient.phone,
                                  if (patient.age != null)
                                    '${patient.age} ${l.text(patient.ageUnit)}',
                                ].join(' · '),
                              ),
                              onTap: !_booking && widget.canOpen && !_busy
                                  ? () => _submit(
                                      PatientEntryAction.openRecord,
                                      patient,
                                    )
                                  : null,
                            ),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (!_booking && widget.canOpen)
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _submit(
                                            PatientEntryAction.openRecord,
                                            patient,
                                          ),
                                    child: Text(l.text('openRecord')),
                                  ),
                                if (_booking || widget.canQueue)
                                  FilledButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _submit(
                                            _booking
                                                ? PatientEntryAction.booked
                                                : PatientEntryAction.queue,
                                            patient,
                                          ),
                                    child: Text(
                                      l.text(
                                        _booking ? 'bookNav' : 'addToQueue',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.slotLabel ?? l.text('entryHint'),
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 12),
        WorkspaceTabs(
          labels: [l.text('newPatient'), l.text('existingPatient')],
          selected: _existing ? 1 : 0,
          onSelected: (i) {
            if (!_busy) _switch(i);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
    final body = _existing
        ? KeyedSubtree(key: _existingPanel, child: existingPatients())
        : details;
    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_booking)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.text('sendBookingConfirmation')),
            value: _send,
            subtitle: Text(l.text('confirmationConsentHint')),
            onChanged: _busy
                ? null
                : (value) => setState(() => _send = value ?? false),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l.text(_error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
        if (!_existing)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 390 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                return Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (!_booking && widget.canQueue)
                      SizedBox(
                        width: stacked
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _submit(PatientEntryAction.queue),
                          child: Text(l.text('saveAndQueue')),
                        ),
                      ),
                    SizedBox(
                      width: stacked
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _submit(
                                _booking
                                    ? PatientEntryAction.booked
                                    : PatientEntryAction.openRecord,
                              ),
                        child: Text(
                          l.text(
                            _booking ? 'addPatientAndBook' : 'savePatient',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, viewport) {
        final compactHeight =
            viewport.maxHeight - MediaQuery.viewInsetsOf(context).bottom < 600;
        return PopScope(
          canPop: !_busy,
          child: Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: size.width < 600 ? 8 : 32,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: size.height * .92,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _booking ? s.bookAppointment : l.text('addPatient'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (compactHeight)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [intro, body, footer],
                          ),
                        ),
                      )
                    else ...[
                      intro,
                      Expanded(child: SingleChildScrollView(child: body)),
                      footer,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
