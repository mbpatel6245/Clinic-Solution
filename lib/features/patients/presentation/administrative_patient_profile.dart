import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/app_role.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../services/firestore_services.dart';
import '../../../services/session_controller.dart';
import '../../../ui/widgets/app_design.dart';
import '../../../shared/presentation/guarded_dialog_content.dart';
import 'patient_labels.dart';

class AdministrativePatientProfile extends StatefulWidget {
  const AdministrativePatientProfile({
    super.key,
    required this.patient,
    this.onBack,
    this.onBook,
  });
  final PatientModel patient;
  final VoidCallback? onBack, onBook;
  @override
  State<AdministrativePatientProfile> createState() =>
      _AdministrativePatientProfileState();
}

class _AdministrativePatientProfileState
    extends State<AdministrativePatientProfile> {
  late final String _clinic = context.read<SessionController>().activeClinicId;
  late final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  late final _profile = context.read<FirebaseFireStore>().streamPatientProfile(
    widget.patient.id,
  );
  late final _appointments = context
      .read<FirebaseFireStore>()
      .streamAppointments();
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.activeClinicId != _clinic ||
        FirebaseAuth.instance.currentUser?.uid != _userId ||
        !session.can(AppFeature.patients)) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<PatientModel?>(
      stream: _profile,
      builder: (context, profile) {
        if (profile.hasError) {
          return AppPage(child: Text(PatientLabels.of(context)('loadError')));
        }
        if (profile.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (profile.data == null) {
          return AppPage(child: Text(PatientLabels.of(context)('noMatch')));
        }
        return StreamBuilder<List<AppointmentModel>>(
          stream: _appointments,
          builder: (context, visits) => AdministrativePatientProfileView(
            patient: profile.data ?? widget.patient,
            appointments: visits.data ?? [],
            onBack: widget.onBack,
            onBook: widget.onBook,
            authorizationChanges: session,
            isAuthorized: () =>
                session.activeClinicId == _clinic &&
                FirebaseAuth.instance.currentUser?.uid == _userId &&
                session.can(AppFeature.patients),
            hasError: profile.hasError || visits.hasError,
            onEdit: (phone, address, reason) =>
                context.read<FirebaseFireStore>().reviewPatientContactEdit(
                  clinicId: _clinic,
                  patient: profile.data ?? widget.patient,
                  phone: phone,
                  address: address,
                  reason: reason,
                ),
          ),
        );
      },
    );
  }
}

class AdministrativePatientProfileView extends StatefulWidget {
  const AdministrativePatientProfileView({
    super.key,
    required this.patient,
    this.appointments = const [],
    this.onBack,
    this.onBook,
    this.onEdit,
    this.hasError = false,
    this.authorizationChanges,
    this.isAuthorized,
  });
  final PatientModel patient;
  final List<AppointmentModel> appointments;
  final VoidCallback? onBack, onBook;
  final Future<void> Function(String phone, String address, String reason)?
  onEdit;
  final bool hasError;
  final Listenable? authorizationChanges;
  final bool Function()? isAuthorized;
  @override
  State<AdministrativePatientProfileView> createState() =>
      _AdministrativePatientProfileViewState();
}

class _AdministrativePatientProfileViewState
    extends State<AdministrativePatientProfileView> {
  Future<void> _edit() async {
    final l = PatientLabels.of(context), p = widget.patient;
    final phone = TextEditingController(text: p.phone),
        address = TextEditingController(text: p.address),
        reason = TextEditingController();
    final form = GlobalKey<FormState>();
    bool checked = false, busy = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => GuardedDialogContent(
          changes: widget.authorizationChanges,
          isAuthorized: widget.isAuthorized,
          message: l('scopeChanged'),
          child: AlertDialog(
            title: Text(l('edit')),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l('editHint')),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phone,
                        enabled: !busy,
                        decoration: InputDecoration(labelText: l('contact')),
                        validator: (v) =>
                            v!.isEmpty ||
                                RegExp(r'^\+[1-9]\d{5,14}$').hasMatch(v.trim())
                            ? null
                            : l('phoneError'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: address,
                        enabled: !busy,
                        maxLines: 3,
                        decoration: InputDecoration(labelText: l('address')),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reason,
                        enabled: !busy,
                        maxLength: 500,
                        decoration: InputDecoration(labelText: l('reason')),
                        validator: (v) =>
                            v!.trim().length >= 5 ? null : l('required'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l('checked')),
                        value: checked,
                        onChanged: busy
                            ? null
                            : (v) => setLocal(() => checked = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: Text(l('cancel')),
              ),
              FilledButton(
                onPressed: busy || !checked
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setLocal(() => busy = true);
                        try {
                          await widget.onEdit!(
                            phone.text.trim(),
                            address.text.trim(),
                            reason.text.trim(),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setLocal(() => busy = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(l('editError'))),
                            );
                          }
                        }
                      },
                child: Text(l('save')),
              ),
            ],
          ),
        ),
      ),
    );
    phone.dispose();
    address.dispose();
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = PatientLabels.of(context), p = widget.patient;
    final visits =
        widget.appointments.where((a) => a.patientId == p.id).toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    Widget detail(String title, String value) => SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: UviloTheme.muted),
          ),
          const SizedBox(height: 7),
          Text(value.isEmpty ? '—' : value),
        ],
      ),
    );
    return Theme(
      data: UviloTheme.light,
      child: AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 12,
              spacing: 12,
              children: [
                Text(
                  l('profile'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.onBack != null)
                  OutlinedButton(
                    onPressed: widget.onBack,
                    child: Text(l('back')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l('privacy'), style: const TextStyle(color: UviloTheme.muted)),
            const SizedBox(height: 24),
            if (widget.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(l('loadError')),
              ),
            AppSection(
              title: p.fullName,
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  detail(l('identity'), p.id),
                  detail(l('contact'), p.phone),
                  detail(
                    l('dob'),
                    p.dateOfBirth == null
                        ? '—'
                        : DateFormat.yMMMd(
                            Localizations.localeOf(context).toString(),
                          ).format(p.dateOfBirth!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppSection(
              title: l('details'),
              trailing: widget.onEdit == null
                  ? null
                  : TextButton(onPressed: _edit, child: Text(l('edit'))),
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  detail(l('name'), p.fullName),
                  detail(l('contact'), p.phone),
                  detail(l('email'), p.email ?? ''),
                  detail(l('address'), p.address),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppSection(
              title: l('appointments'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (visits.isEmpty && !widget.hasError)
                    Text(l('noAppointments'))
                  else
                    for (final a in visits)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          DateFormat.yMMMd(
                            Localizations.localeOf(context).toString(),
                          ).add_jm().format(a.scheduledAt),
                        ),
                        subtitle: Text(a.status),
                      ),
                  if (widget.onBook != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: widget.onBook,
                        child: Text(l('book')),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppSection(
              title: l('consent'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${l('reminder')}: ${l(p.notificationConsent == true ? 'yes' : 'unknown')}',
                  ),
                  const SizedBox(height: 12),
                  Text(l('consentHint')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
