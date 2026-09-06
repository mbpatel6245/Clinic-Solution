import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/app_role.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../data/datasources/enterprise_models.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import '../../../widgets/app_design.dart';

String _money(BuildContext context, double value) =>
    NumberFormat.simpleCurrency(name: 'INR').format(value);

void _notice(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

class ClinicSetupScreen extends StatelessWidget {
  const ClinicSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseFireStore>();
    final session = context.watch<SessionController>();
    return StreamBuilder<ClinicProfile>(
      stream: service.streamActiveClinic(),
      builder: (context, snapshot) {
        final clinic =
            snapshot.data ??
            ClinicProfile(
              id: service.activeClinicId,
              name: context.read<SessionController>().clinicName,
              enabledModules: ClinicProfile.defaultModules,
            );
        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _heading(
                      context,
                      'Clinic setup',
                      'Configure this clinic and enable only the modules it needs.',
                    ),
                  ),
                  if (session.role == AppRole.platformOwner)
                    FilledButton.icon(
                      onPressed: () => _createClinic(context),
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('New clinic'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSection(
                title: clinic.name,
                trailing: FilledButton.icon(
                  onPressed: () => _editClinic(context, clinic),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profile'),
                ),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text('Code: ${clinic.code.isEmpty ? '—' : clinic.code}'),
                    Text('Phone: ${clinic.phone.isEmpty ? '—' : clinic.phone}'),
                    Text('Currency: ${clinic.currency}'),
                    Text('Timezone: ${clinic.timezone}'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSection(
                title: 'Modules',
                child: Column(
                  children: ClinicModule.values.map((module) {
                    final core =
                        module == ClinicModule.patients ||
                        module == ClinicModule.clinical;
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(module.displayName),
                      subtitle: Text(
                        core
                            ? 'Core clinical module'
                            : 'Optional — enable when this clinic uses it',
                      ),
                      value: core || clinic.enabledModules.contains(module),
                      onChanged: core
                          ? null
                          : (enabled) async {
                              final modules = {...clinic.enabledModules};
                              enabled
                                  ? modules.add(module)
                                  : modules.remove(module);
                              await service.saveClinic(
                                clinic.copyWith(enabledModules: modules),
                              );
                            },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createClinic(BuildContext context) async {
    final name = TextEditingController();
    final saved = await _formDialog(context, 'Create clinic', [
      _field(name, 'Clinic name'),
    ]);
    if (!saved || name.text.trim().isEmpty || !context.mounted) return;
    final id = await context.read<FirebaseFireStore>().createClinic(name.text);
    if (context.mounted) {
      await context.read<SessionController>().selectClinic(id);
    }
  }

  Future<void> _editClinic(BuildContext context, ClinicProfile clinic) async {
    final name = TextEditingController(text: clinic.name);
    final code = TextEditingController(text: clinic.code);
    final phone = TextEditingController(text: clinic.phone);
    final address = TextEditingController(text: clinic.address);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clinic profile'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Clinic name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Clinic code'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      await context.read<FirebaseFireStore>().saveClinic(
        clinic.copyWith(
          name: name.text,
          code: code.text,
          phone: phone.text,
          address: address.text,
        ),
      );
    }
  }
}

class ReceptionScreen extends StatelessWidget {
  const ReceptionScreen({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppointmentModel>>(
    stream: context.read<FirebaseFireStore>().streamAppointments(),
    builder: (context, snapshot) {
      final today = DateTime.now();
      final items = (snapshot.data ?? const <AppointmentModel>[])
          .where(
            (item) =>
                item.scheduledAt.year == today.year &&
                item.scheduledAt.month == today.month &&
                item.scheduledAt.day == today.day,
          )
          .toList();
      return AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(
              context,
              'Reception & queue',
              'Manage today’s check-ins and visit status.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (items.isEmpty)
              const AppSection(child: Text('No patients are scheduled today.'))
            else
              ...items.indexed.map((entry) {
                final (index, item) = entry;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(item.patientName),
                      subtitle: Text(
                        '${DateFormat.jm().format(item.scheduledAt)} • ${item.phone} • ${item.status}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (status) => context
                            .read<FirebaseFireStore>()
                            .updateAppointmentStatus(item.id, status),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'confirmed',
                            child: Text('Check in'),
                          ),
                          PopupMenuItem(
                            value: 'completed',
                            child: Text('Complete'),
                          ),
                          PopupMenuItem(
                            value: 'cancelled',
                            child: Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    },
  );
}

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClinicInvoice>>(
    stream: context.read<FirebaseFireStore>().streamInvoices(),
    builder: (context, snapshot) {
      final invoices = snapshot.data ?? const <ClinicInvoice>[];
      final billed = invoices.fold<double>(0, (sum, item) => sum + item.total);
      final collected = invoices.fold<double>(
        0,
        (sum, item) => sum + item.amountPaid,
      );
      return AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _heading(
                    context,
                    'Billing & payments',
                    'Split doctor, clinic, pharmacy and service fees.',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _invoiceDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New invoice'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ResponsiveGrid(
              children: [
                AppMetricCard(
                  label: 'Billed',
                  value: _money(context, billed),
                  icon: Icons.receipt_long_outlined,
                ),
                AppMetricCard(
                  label: 'Collected',
                  value: _money(context, collected),
                  icon: Icons.payments_outlined,
                ),
                AppMetricCard(
                  label: 'Outstanding',
                  value: _money(context, billed - collected),
                  icon: Icons.pending_actions_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (invoices.isEmpty)
              const AppSection(child: Text('No invoices found.'))
            else
              ...invoices.map(
                (invoice) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.receipt_outlined),
                      ),
                      title: Text(invoice.patientName),
                      subtitle: Text(
                        '${DateFormat.yMMMd().format(invoice.issuedAt)} • ${invoice.status.name} • Paid ${_money(context, invoice.amountPaid)}',
                      ),
                      trailing: Text(
                        _money(context, invoice.total),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _invoiceDialog(BuildContext context) async {
    final patient = TextEditingController();
    final doctor = TextEditingController();
    final clinic = TextEditingController();
    final pharmacy = TextEditingController();
    final paid = TextEditingController();
    final saved = await _formDialog(context, 'New invoice', [
      _field(patient, 'Patient name'),
      _field(doctor, 'Doctor consultation fee', number: true),
      _field(clinic, 'Clinic / case fee', number: true),
      _field(pharmacy, 'Pharmacy amount', number: true),
      _field(paid, 'Amount paid', number: true),
    ]);
    if (saved && context.mounted && patient.text.trim().isNotEmpty) {
      final lines = <InvoiceLine>[
        InvoiceLine(
          type: 'doctor',
          description: 'Doctor consultation',
          amount: double.tryParse(doctor.text) ?? 0,
        ),
        InvoiceLine(
          type: 'clinic',
          description: 'Clinic / case fee',
          amount: double.tryParse(clinic.text) ?? 0,
        ),
        InvoiceLine(
          type: 'pharmacy',
          description: 'Pharmacy sale',
          amount: double.tryParse(pharmacy.text) ?? 0,
        ),
      ].where((line) => line.amount > 0).toList();
      final amountPaid = double.tryParse(paid.text) ?? 0;
      final total = lines.fold<double>(0, (sum, line) => sum + line.amount);
      await context.read<FirebaseFireStore>().saveInvoice(
        ClinicInvoice(
          patientName: patient.text,
          lines: lines,
          issuedAt: DateTime.now(),
          amountPaid: amountPaid,
          status: amountPaid <= 0
              ? InvoiceStatus.unpaid
              : amountPaid >= total
              ? InvoiceStatus.paid
              : InvoiceStatus.partiallyPaid,
        ),
      );
    }
  }
}

class VaccinationScreen extends StatelessWidget {
  const VaccinationScreen({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<VaccinationRecord>>(
    stream: context.read<FirebaseFireStore>().streamVaccinations(),
    builder: (context, snapshot) {
      final records = snapshot.data ?? const <VaccinationRecord>[];
      return AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _heading(
                    context,
                    'Vaccination',
                    'Record doses, batches, vaccinators and upcoming doses.',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _dialog(context),
                  icon: const Icon(Icons.vaccines_outlined),
                  label: const Text('Record dose'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (records.isEmpty)
              const AppSection(child: Text('No vaccination records found.'))
            else
              ...records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.vaccines_outlined),
                      ),
                      title: Text('${record.patientName} — ${record.vaccine}'),
                      subtitle: Text(
                        'Dose ${record.doseNumber} • Batch ${record.batchNumber.isEmpty ? '—' : record.batchNumber} • ${DateFormat.yMMMd().format(record.administeredAt)}',
                      ),
                      trailing: record.nextDoseAt == null
                          ? null
                          : Text(
                              'Next\n${DateFormat.yMMMd().format(record.nextDoseAt!)}',
                              textAlign: TextAlign.end,
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _dialog(BuildContext context) async {
    final patient = TextEditingController();
    final vaccine = TextEditingController();
    final dose = TextEditingController(text: '1');
    final batch = TextEditingController();
    final manufacturer = TextEditingController();
    final vaccinator = TextEditingController();
    final saved = await _formDialog(context, 'Record vaccination', [
      _field(patient, 'Patient name'),
      _field(vaccine, 'Vaccine'),
      _field(dose, 'Dose number', number: true),
      _field(batch, 'Batch number'),
      _field(manufacturer, 'Manufacturer'),
      _field(vaccinator, 'Vaccinator'),
    ]);
    if (saved &&
        context.mounted &&
        patient.text.trim().isNotEmpty &&
        vaccine.text.trim().isNotEmpty) {
      await context.read<FirebaseFireStore>().saveVaccination(
        VaccinationRecord(
          patientName: patient.text,
          vaccine: vaccine.text,
          doseNumber: int.tryParse(dose.text) ?? 1,
          batchNumber: batch.text,
          manufacturer: manufacturer.text,
          vaccinator: vaccinator.text,
          administeredAt: DateTime.now(),
        ),
      );
    }
  }
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClinicReminder>>(
    stream: context.read<FirebaseFireStore>().streamReminders(),
    builder: (context, snapshot) {
      final reminders = snapshot.data ?? const <ClinicReminder>[];
      return AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _heading(
                    context,
                    'Reminders',
                    'Schedule consent-aware appointment, follow-up and vaccination reminders.',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _dialog(context),
                  icon: const Icon(Icons.add_alert_outlined),
                  label: const Text('Schedule'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (reminders.isEmpty)
              const AppSection(child: Text('No reminders scheduled.'))
            else
              ...reminders.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.notifications_outlined),
                      ),
                      title: Text('${item.patientName} — ${item.type}'),
                      subtitle: Text(
                        '${DateFormat.yMMMd().add_jm().format(item.scheduledAt)} • ${item.channel} • ${item.status}\n${item.message}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _dialog(BuildContext context) async {
    final patient = TextEditingController();
    final type = TextEditingController(text: 'appointment');
    final message = TextEditingController();
    final days = TextEditingController(text: '1');
    final saved = await _formDialog(context, 'Schedule reminder', [
      _field(patient, 'Patient name'),
      _field(type, 'Type'),
      _field(message, 'Message'),
      _field(days, 'Send after number of days', number: true),
    ]);
    if (saved && context.mounted && patient.text.trim().isNotEmpty) {
      await context.read<FirebaseFireStore>().saveReminder(
        ClinicReminder(
          patientName: patient.text,
          type: type.text,
          message: message.text,
          scheduledAt: DateTime.now().add(
            Duration(days: int.tryParse(days.text) ?? 1),
          ),
        ),
      );
    }
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClinicInvoice>>(
    stream: context.read<FirebaseFireStore>().streamInvoices(),
    builder: (context, invoiceSnapshot) => StreamBuilder<List<FinanceEntry>>(
      stream: context.read<FirebaseFireStore>().streamFinanceEntries(),
      builder: (context, financeSnapshot) {
        bool inside(DateTime date) =>
            !date.isBefore(_range.start) &&
            date.isBefore(_range.end.add(const Duration(days: 1)));
        final invoices = (invoiceSnapshot.data ?? const <ClinicInvoice>[])
            .where((e) => inside(e.issuedAt));
        final expenses = (financeSnapshot.data ?? const <FinanceEntry>[]).where(
          (e) => e.type == FinanceEntryType.expense && inside(e.occurredAt),
        );
        final sales = invoices.fold<double>(0, (sum, e) => sum + e.total);
        final collected = invoices.fold<double>(
          0,
          (sum, e) => sum + e.amountPaid,
        );
        final expense = expenses.fold<double>(0, (sum, e) => sum + e.amount);
        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _heading(
                      context,
                      'Reports & analytics',
                      'Monthly, yearly or custom date performance.',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final value = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDateRange: _range,
                      );
                      if (value != null) setState(() => _range = value);
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      '${DateFormat.yMMMd().format(_range.start)} – ${DateFormat.yMMMd().format(_range.end)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ResponsiveGrid(
                children: [
                  AppMetricCard(
                    label: 'Sales billed',
                    value: _money(context, sales),
                    icon: Icons.trending_up,
                  ),
                  AppMetricCard(
                    label: 'Payments collected',
                    value: _money(context, collected),
                    icon: Icons.payments_outlined,
                  ),
                  AppMetricCard(
                    label: 'Expenses',
                    value: _money(context, expense),
                    icon: Icons.trending_down,
                  ),
                  AppMetricCard(
                    label: 'Net cash',
                    value: _money(context, collected - expense),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  StreamBuilder<List<PatientModel>>(
                    stream: context.read<FirebaseFireStore>().streamPatients(),
                    builder: (context, snapshot) {
                      final newPatients =
                          (snapshot.data ?? const <PatientModel>[])
                              .where(
                                (patient) =>
                                    patient.createdAt != null &&
                                    inside(patient.createdAt!),
                              )
                              .length;
                      return AppMetricCard(
                        label: 'New patients',
                        value: '$newPatients',
                        icon: Icons.person_add_alt_outlined,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSection(
                title: 'Collection performance',
                child: LinearProgressIndicator(
                  value: sales == 0 ? 0 : (collected / sales).clamp(0, 1),
                  minHeight: 16,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class DataExchangeScreen extends StatefulWidget {
  const DataExchangeScreen({super.key});
  @override
  State<DataExchangeScreen> createState() => _DataExchangeScreenState();
}

class _DataExchangeScreenState extends State<DataExchangeScreen> {
  final _csv = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          context,
          'Import & export',
          'Use clinic-scoped CSV with validation before records are saved.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSection(
          title: 'Patients CSV',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Columns: first_name,middle_name,last_name,gender,phone,address,age',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _csv,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(hintText: 'Paste CSV here…'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _copyTemplate,
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy template'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export to clipboard'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _import,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Validate & import'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _copyTemplate() async {
    const value = 'first_name,middle_name,last_name,gender,phone,address,age\n';
    await Clipboard.setData(const ClipboardData(text: value));
    _csv.text = value;
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    final service = context.read<FirebaseFireStore>();
    final patients = await service.streamPatients().first;
    final buffer = StringBuffer(
      'first_name,middle_name,last_name,gender,phone,address,age\n',
    );
    String escape(String value) => '"${value.replaceAll('"', '""')}"';
    for (final p in patients) {
      buffer.writeln(
        [
          p.firstName,
          p.middleName,
          p.lastName,
          p.gender,
          p.phone,
          p.address,
          p.age ?? '',
        ].map((e) => escape('$e')).join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      setState(() => _busy = false);
      _notice(this.context, '${patients.length} patients copied as CSV.');
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    final service = context.read<FirebaseFireStore>();
    final lines = _csv.text.trim().split(RegExp(r'\r?\n'));
    var imported = 0;
    var errors = 0;
    for (var i = 1; i < lines.length; i++) {
      final cells = lines[i]
          .split(',')
          .map((e) => e.trim().replaceAll(RegExp(r'^"|"$'), ''))
          .toList();
      if (cells.length < 7 || cells[0].isEmpty) {
        errors++;
        continue;
      }
      await service.addDocument(
        path: FirebaseFireStore.pathPatients,
        data: PatientModel(
          firstName: cells[0],
          middleName: cells[1],
          lastName: cells[2],
          gender: cells[3],
          phone: cells[4],
          address: cells[5],
          age: int.tryParse(cells[6]),
        ).toMap(),
      );
      imported++;
    }
    await service.logAudit('patients.imported', '$imported');
    if (mounted) {
      setState(() => _busy = false);
      _notice(
        this.context,
        'Imported $imported patients; $errors rows rejected.',
      );
    }
  }
}

Widget _heading(BuildContext context, String title, String subtitle) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(title, style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 4),
    Text(
      subtitle,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
    ),
  ],
);

Widget _field(
  TextEditingController controller,
  String label, {
  bool number = false,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextField(
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    decoration: InputDecoration(labelText: label),
  ),
);

Future<bool> _formDialog(
  BuildContext context,
  String title,
  List<Widget> fields,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: fields),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ) ??
    false;
