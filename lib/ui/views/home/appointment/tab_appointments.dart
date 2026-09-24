import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/datasources/clinical_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../core/constants/locale_key.dart';

class PatientAppointmentScreen extends StatefulWidget {
  const PatientAppointmentScreen({super.key});

  @override
  State<PatientAppointmentScreen> createState() =>
      _PatientAppointmentScreenState();
}

class _PatientAppointmentScreenState extends State<PatientAppointmentScreen> {
  bool _booked = false;

  Future<void> _book() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _AppointmentForm(),
    );
    if (saved == true && mounted) setState(() => _booked = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        leading: IconButton(
          onPressed: () => context.go('/${Constants.navLogin}'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _booked
                          ? Icons.event_available_outlined
                          : Icons.calendar_month_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _booked
                          ? strings.appointmentBooked
                          : strings.bookAppointment,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _book,
                      icon: Icon(_booked ? Icons.add : Icons.arrow_forward),
                      label: Text(strings.bookAppointment),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TabAppointments extends StatefulWidget {
  const TabAppointments({super.key, this.patientOnly = false});

  final bool patientOnly;

  @override
  State<TabAppointments> createState() => _TabAppointmentsState();
}

class _TabAppointmentsState extends State<TabAppointments> {
  String _filter = 'upcoming';

  Future<void> _openBooking([AppointmentModel? appointment]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AppointmentForm(appointment: appointment),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.appointmentBooked),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  strings.appointments,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                FilledButton.icon(
                  onPressed: _openBooking,
                  icon: const Icon(Icons.add),
                  label: Text(strings.bookAppointment),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _FilterChip(
                  label: strings.upcoming,
                  value: 'upcoming',
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
                _FilterChip(
                  label: strings.today,
                  value: 'today',
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
                _FilterChip(
                  label: strings.allStatuses,
                  value: 'all',
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<AppointmentModel>>(
                stream: widget.patientOnly
                    ? context
                          .read<FirebaseFireStore>()
                          .streamAppointmentsForUser(
                            FirebaseAuth.instance.currentUser?.uid ?? '',
                          )
                    : context.read<FirebaseFireStore>().streamAppointments(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _EmptyAppointments(
                      message: '${strings.errorMessage}\n${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final now = DateTime.now();
                  final startToday = DateTime(now.year, now.month, now.day);
                  final endToday = startToday.add(const Duration(days: 1));
                  final appointments = snapshot.data!.where((item) {
                    if (_filter == 'today') {
                      return !item.scheduledAt.isBefore(startToday) &&
                          item.scheduledAt.isBefore(endToday);
                    }
                    if (_filter == 'upcoming') {
                      return item.scheduledAt.isAfter(now) &&
                          item.status != 'cancelled';
                    }
                    return true;
                  }).toList();
                  if (appointments.isEmpty) {
                    return _EmptyAppointments(message: strings.noAppointments);
                  }
                  return ListView.separated(
                    itemCount: appointments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _AppointmentCard(
                      appointment: appointments[index],
                      patientOnly: widget.patientOnly,
                      onEdit: () => _openBooking(appointments[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.onEdit,
    required this.patientOnly,
  });

  final AppointmentModel appointment;
  final VoidCallback onEdit;
  final bool patientOnly;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.yMMMd(locale).format(appointment.scheduledAt);
    final time = DateFormat.jm(locale).format(appointment.scheduledAt);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${appointment.scheduledAt.day}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(DateFormat.MMM(locale).format(appointment.scheduledAt)),
            ],
          ),
        ),
        title: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(appointment.patientName),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(_statusLabel(strings, appointment.status)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            [
              '$date, $time',
              appointment.phone,
              appointment.reason,
            ].where((value) => value.isNotEmpty).join(' • '),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text(strings.update)),
            if (!patientOnly) ...[
              PopupMenuItem(value: 'confirmed', child: Text(strings.confirmed)),
              PopupMenuItem(
                value: 'completed',
                child: Text(strings.markComplete),
              ),
            ],
            PopupMenuItem(value: 'cancelled', child: Text(strings.cancelled)),
            if (!patientOnly)
              PopupMenuItem(value: 'delete', child: Text(strings.delete)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    if (action == 'edit') {
      onEdit();
      return;
    }
    final service = context.read<FirebaseFireStore>();
    if (action != 'delete') {
      await service.updateAppointmentStatus(appointment.id, action);
      return;
    }
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.delete),
        content: Text(strings.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await service.removeAppointment(appointment.id);
  }

  String _statusLabel(AppLocalizations strings, String value) =>
      switch (value) {
        'confirmed' => strings.confirmed,
        'completed' => strings.completed,
        'cancelled' => strings.cancelled,
        _ => strings.booked,
      };
}

class _AppointmentForm extends StatefulWidget {
  const _AppointmentForm({this.appointment});

  final AppointmentModel? appointment;

  @override
  State<_AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<_AppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _notificationConsent = false;
  late final TextEditingController _reason;
  late final TextEditingController _notes;
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.appointment;
    _name = TextEditingController(text: item?.patientName ?? '');
    _phone = TextEditingController(text: item?.phone ?? '');
    _email = TextEditingController(text: item?.email ?? '');
    _notificationConsent = item?.notificationConsent ?? false;
    _reason = TextEditingController(text: item?.reason ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    final scheduled =
        item?.scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(scheduled.year, scheduled.month, scheduled.day);
    _time = TimeOfDay.fromDateTime(scheduled);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final scheduled = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    try {
      await context.read<FirebaseFireStore>().saveAppointment(
        AppointmentModel(
          id: widget.appointment?.id ?? '',
          patientId: widget.appointment?.patientId ?? '',
          patientName: _name.text,
          phone: _phone.text,
          email: _email.text,
          notificationConsent: _notificationConsent,
          locale: Localizations.localeOf(context).languageCode,
          scheduledAt: scheduled,
          reason: _reason.text,
          notes: _notes.text,
          status: widget.appointment?.status ?? 'booked',
          createdBy:
              widget.appointment?.createdBy ??
              FirebaseAuth.instance.currentUser?.uid ??
              '',
          createdAt: widget.appointment?.createdAt,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.bookAppointment),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: strings.patientName),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? strings.requiredField
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: strings.phone),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? strings.requiredField
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email for appointment updates (optional)',
                  ),
                  validator: (value) =>
                      value != null &&
                          value.trim().isNotEmpty &&
                          !RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(value.trim())
                      ? 'Enter a valid email.'
                      : null,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Send appointment updates by SMS and email',
                  ),
                  subtitle: const Text(
                    'The patient agrees to receive updates at these contact details.',
                  ),
                  value: _notificationConsent,
                  onChanged: (value) =>
                      setState(() => _notificationConsent = value ?? false),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PickerField(
                        label: strings.appointmentDate,
                        value: DateFormat.yMMMd(
                          Localizations.localeOf(context).toString(),
                        ).format(_date),
                        onTap: () async {
                          final value = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                          );
                          if (value != null && mounted) {
                            setState(() => _date = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerField(
                        label: strings.time,
                        value: _time.format(context),
                        onTap: () async {
                          final value = await showTimePicker(
                            context: context,
                            initialTime: _time,
                          );
                          if (value != null && mounted) {
                            setState(() => _time = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  decoration: InputDecoration(labelText: strings.reason),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: strings.notes),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.save),
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
