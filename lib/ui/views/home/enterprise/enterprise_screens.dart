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
    return StreamBuilder<List<ClinicProfile>>(
      stream: service.streamAllClinics(),
      builder: (context, snapshot) {
        final clinics = snapshot.data ?? const <ClinicProfile>[];
        ClinicProfile? selectedClinic;
        for (final clinic in clinics) {
          if (clinic.id == session.activeClinicId) selectedClinic = clinic;
        }
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
                  FilledButton.icon(
                    onPressed: () => _createClinic(context),
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('New clinic'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              StreamBuilder<PlatformNotificationSettings>(
                stream: service.streamPlatformNotificationSettings(),
                builder: (context, notificationSnapshot) =>
                    _GlobalNotificationSettingsCard(
                      settings:
                          notificationSnapshot.data ??
                          const PlatformNotificationSettings(),
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSection(
                title: 'Clinics (${clinics.length})',
                trailing: session.isAllClinics
                    ? null
                    : TextButton.icon(
                        onPressed: session.showAllClinics,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to all clinics'),
                      ),
                child: _ClinicDirectory(
                  clinics: clinics,
                  activeClinicId: session.activeClinicId,
                  onSelected: session.selectClinic,
                ),
              ),
              if (selectedClinic == null) ...[
                const SizedBox(height: AppSpacing.lg),
                const AppSection(
                  child: Text(
                    'Select a clinic to edit its profile and modules.',
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                AppSection(
                  title: selectedClinic.name,
                  trailing: FilledButton.icon(
                    onPressed: () => _editClinic(context, selectedClinic!),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Code: ${selectedClinic.code.isEmpty ? '—' : selectedClinic.code}',
                      ),
                      Text(
                        'Phone: ${selectedClinic.phone.isEmpty ? '—' : selectedClinic.phone}',
                      ),
                      Text('Currency: ${selectedClinic.currency}'),
                      Text('Timezone: ${selectedClinic.timezone}'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSection(
                  title: 'Modules',
                  child: SizedBox(
                    height: 470,
                    child: ListView.separated(
                      itemCount: ClinicModule.values.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final module = ClinicModule.values[index];
                        final core =
                            module == ClinicModule.patients ||
                            module == ClinicModule.clinical;
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: CircleAvatar(
                            backgroundColor: AppColors.soft,
                            child: Icon(
                              _moduleIcon(module),
                              color: AppColors.ink,
                            ),
                          ),
                          title: Text(module.displayName),
                          subtitle: Text(
                            core
                                ? 'Core clinical module'
                                : 'Optional — enable when this clinic uses it',
                          ),
                          value:
                              core ||
                              selectedClinic!.enabledModules.contains(module),
                          onChanged: core
                              ? null
                              : (enabled) async {
                                  final modules = {
                                    ...selectedClinic!.enabledModules,
                                  };
                                  enabled
                                      ? modules.add(module)
                                      : modules.remove(module);
                                  await service.saveClinic(
                                    selectedClinic.copyWith(
                                      enabledModules: modules,
                                    ),
                                  );
                                },
                        );
                      },
                    ),
                  ),
                ),
              ],
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

class _GlobalNotificationSettingsCard extends StatelessWidget {
  const _GlobalNotificationSettingsCard({required this.settings});

  final PlatformNotificationSettings settings;

  @override
  Widget build(BuildContext context) => AppSection(
    title: 'Global notifications',
    trailing: FilledButton.icon(
      onPressed: () => _configure(context),
      icon: const Icon(Icons.notifications_active_outlined),
      label: const Text('Configure providers'),
    ),
    child: Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          avatar: const Icon(Icons.send_outlined, size: 18),
          label: Text('Primary: ${_providerLabel(settings.primaryProvider)}'),
        ),
        Chip(
          avatar: Icon(
            settings.fallbackEnabled
                ? Icons.alt_route_outlined
                : Icons.block_outlined,
            size: 18,
          ),
          label: Text(
            settings.fallbackEnabled
                ? 'Fallback: ${_providerLabel(settings.fallbackProvider)}'
                : 'Fallback disabled',
          ),
        ),
        const Text(
          'Applies to every clinic. Credentials stay in Secret Manager.',
        ),
      ],
    ),
  );

  String _providerLabel(String value) => value == 'twilio' ? 'Twilio' : 'MSG91';

  Future<void> _configure(BuildContext context) async {
    var primary = settings.primaryProvider;
    var fallback = settings.fallbackProvider;
    var fallbackEnabled = settings.fallbackEnabled;
    final country = TextEditingController(text: settings.defaultCountryCode);
    final msg91Sms = TextEditingController(text: settings.msg91SmsTemplateId);
    final msg91WaTemplate = TextEditingController(
      text: settings.msg91WhatsappTemplateName,
    );
    final msg91WaNamespace = TextEditingController(
      text: settings.msg91WhatsappNamespace,
    );
    final msg91WaNumber = TextEditingController(
      text: settings.msg91WhatsappIntegratedNumber,
    );
    final msg91EmailTemplate = TextEditingController(
      text: settings.msg91EmailTemplateId,
    );
    final msg91EmailDomain = TextEditingController(
      text: settings.msg91EmailDomain,
    );
    final msg91EmailFrom = TextEditingController(text: settings.msg91EmailFrom);
    final msg91EmailName = TextEditingController(
      text: settings.msg91EmailFromName,
    );
    final twilioService = TextEditingController(
      text: settings.twilioMessagingServiceSid,
    );
    final twilioSmsFrom = TextEditingController(text: settings.twilioSmsFrom);
    final twilioSmsContent = TextEditingController(
      text: settings.twilioSmsContentSid,
    );
    final twilioWaFrom = TextEditingController(
      text: settings.twilioWhatsappFrom,
    );
    final twilioWaContent = TextEditingController(
      text: settings.twilioWhatsappContentSid,
    );
    final sendGridFrom = TextEditingController(
      text: settings.sendGridFromEmail,
    );
    final sendGridName = TextEditingController(text: settings.sendGridFromName);
    final sendGridTemplate = TextEditingController(
      text: settings.sendGridTemplateId,
    );
    final callbackUrl = TextEditingController(
      text: settings.twilioStatusCallbackUrl,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Global notification providers'),
          content: SizedBox(
            width: 720,
            height: MediaQuery.sizeOf(context).height * .72,
            child: ListView(
              children: [
                const Text(
                  'Choose the platform-wide routing policy. API keys are intentionally configured through Firebase Secret Manager, not this screen.',
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: primary,
                  decoration: const InputDecoration(
                    labelText: 'Primary provider',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'msg91', child: Text('MSG91')),
                    DropdownMenuItem(value: 'twilio', child: Text('Twilio')),
                  ],
                  onChanged: (value) =>
                      setState(() => primary = value ?? primary),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use automatic fallback'),
                  subtitle: const Text(
                    'If the primary provider rejects or cannot deliver the API request, try the other provider once.',
                  ),
                  value: fallbackEnabled,
                  onChanged: (value) => setState(() => fallbackEnabled = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: fallback,
                  decoration: const InputDecoration(
                    labelText: 'Fallback provider',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'msg91', child: Text('MSG91')),
                    DropdownMenuItem(value: 'twilio', child: Text('Twilio')),
                  ],
                  onChanged: fallbackEnabled
                      ? (value) => setState(() => fallback = value ?? fallback)
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                _field(country, 'Default phone country code'),
                const SizedBox(height: AppSpacing.md),
                _providerFields(
                  context,
                  title: 'MSG91 identifiers',
                  children: [
                    _field(msg91Sms, 'SMS Flow/template ID'),
                    _field(msg91WaTemplate, 'WhatsApp template name'),
                    _field(msg91WaNamespace, 'WhatsApp namespace'),
                    _field(msg91WaNumber, 'WhatsApp integrated number'),
                    _field(msg91EmailTemplate, 'Email template ID'),
                    _field(msg91EmailDomain, 'Verified email domain'),
                    _field(msg91EmailFrom, 'Email sender address'),
                    _field(msg91EmailName, 'Email sender name'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _providerFields(
                  context,
                  title: 'Twilio and SendGrid identifiers',
                  children: [
                    _field(
                      twilioService,
                      'Messaging Service SID (recommended)',
                    ),
                    _field(
                      twilioSmsFrom,
                      'SMS From number/sender (if no service)',
                    ),
                    _field(twilioSmsContent, 'SMS Content SID (optional)'),
                    _field(twilioWaFrom, 'WhatsApp sender number'),
                    _field(twilioWaContent, 'WhatsApp Content SID'),
                    _field(sendGridFrom, 'SendGrid verified sender email'),
                    _field(sendGridName, 'SendGrid sender name'),
                    _field(sendGridTemplate, 'SendGrid dynamic template ID'),
                    _field(callbackUrl, 'Twilio status callback URL'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: primary == fallback && fallbackEnabled
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Apply to all clinics'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      await context.read<FirebaseFireStore>().savePlatformNotificationSettings(
        PlatformNotificationSettings(
          primaryProvider: primary,
          fallbackProvider: fallback,
          fallbackEnabled: fallbackEnabled,
          defaultCountryCode: country.text,
          msg91SmsTemplateId: msg91Sms.text,
          msg91WhatsappTemplateName: msg91WaTemplate.text,
          msg91WhatsappNamespace: msg91WaNamespace.text,
          msg91WhatsappIntegratedNumber: msg91WaNumber.text,
          msg91EmailTemplateId: msg91EmailTemplate.text,
          msg91EmailDomain: msg91EmailDomain.text,
          msg91EmailFrom: msg91EmailFrom.text,
          msg91EmailFromName: msg91EmailName.text,
          twilioMessagingServiceSid: twilioService.text,
          twilioSmsFrom: twilioSmsFrom.text,
          twilioSmsContentSid: twilioSmsContent.text,
          twilioWhatsappFrom: twilioWaFrom.text,
          twilioWhatsappContentSid: twilioWaContent.text,
          sendGridFromEmail: sendGridFrom.text,
          sendGridFromName: sendGridName.text,
          sendGridTemplateId: sendGridTemplate.text,
          twilioStatusCallbackUrl: callbackUrl.text,
        ),
      );
      if (context.mounted) {
        _notice(context, 'Global notification settings updated.');
      }
    }
    for (final controller in [
      country,
      msg91Sms,
      msg91WaTemplate,
      msg91WaNamespace,
      msg91WaNumber,
      msg91EmailTemplate,
      msg91EmailDomain,
      msg91EmailFrom,
      msg91EmailName,
      twilioService,
      twilioSmsFrom,
      twilioSmsContent,
      twilioWaFrom,
      twilioWaContent,
      sendGridFrom,
      sendGridName,
      sendGridTemplate,
      callbackUrl,
    ]) {
      controller.dispose();
    }
  }

  Widget _providerFields(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    initiallyExpanded: true,
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    children: children
        .map(
          (child) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: child,
          ),
        )
        .toList(),
  );
}

class PlatformOverviewScreen extends StatelessWidget {
  const PlatformOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClinicProfile>>(
    stream: context.read<FirebaseFireStore>().streamAllClinics(),
    builder: (context, snapshot) {
      final clinics = snapshot.data ?? const <ClinicProfile>[];
      final active = clinics.where((clinic) => clinic.active).length;
      return AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(
              context,
              'All clinics',
              'Platform-wide workspace. Select a clinic to manage its data and modules.',
            ),
            const SizedBox(height: AppSpacing.lg),
            ResponsiveGrid(
              children: [
                AppMetricCard(
                  label: 'Total clinics',
                  value: '${clinics.length}',
                  icon: Icons.apartment_outlined,
                ),
                AppMetricCard(
                  label: 'Active clinics',
                  value: '$active',
                  icon: Icons.verified_outlined,
                ),
                AppMetricCard(
                  label: 'Inactive clinics',
                  value: '${clinics.length - active}',
                  icon: Icons.pause_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSection(
              title: 'Clinic directory',
              child: _ClinicDirectory(
                clinics: clinics,
                activeClinicId: SessionController.allClinicsId,
                onSelected: context.read<SessionController>().selectClinic,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ClinicDirectory extends StatefulWidget {
  const _ClinicDirectory({
    required this.clinics,
    required this.activeClinicId,
    required this.onSelected,
  });

  final List<ClinicProfile> clinics;
  final String activeClinicId;
  final ValueChanged<String> onSelected;

  @override
  State<_ClinicDirectory> createState() => _ClinicDirectoryState();
}

class _ClinicDirectoryState extends State<_ClinicDirectory> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.clinics.where((clinic) {
      if (query.isEmpty) return true;
      return clinic.name.toLowerCase().contains(query) ||
          clinic.code.toLowerCase().contains(query) ||
          clinic.id.toLowerCase().contains(query) ||
          clinic.phone.toLowerCase().contains(query);
    }).toList();
    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            labelText: 'Search clinics',
            hintText: 'Name, code, phone or clinic ID',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: widget.clinics.isEmpty ? 70 : 280,
          child: widget.clinics.isEmpty
              ? const Center(child: Text('No clinics created yet.'))
              : filtered.isEmpty
              ? const Center(child: Text('No clinic matches your search.'))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final clinic = filtered[index];
                    final selected = clinic.id == widget.activeClinicId;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: selected
                            ? AppColors.ink
                            : AppColors.soft,
                        foregroundColor: selected
                            ? AppColors.inverse
                            : AppColors.ink,
                        child: const Icon(Icons.local_hospital_outlined),
                      ),
                      title: Text(clinic.name),
                      subtitle: Text(
                        '${clinic.code.isEmpty ? clinic.id : clinic.code} • ${clinic.enabledModules.length} modules'
                        '${clinic.phone.isEmpty ? '' : ' • ${clinic.phone}'}',
                      ),
                      trailing: selected
                          ? const Chip(label: Text('Selected'))
                          : OutlinedButton.icon(
                              onPressed: () => widget.onSelected(clinic.id),
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Manage'),
                            ),
                      onTap: () => widget.onSelected(clinic.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

IconData _moduleIcon(ClinicModule module) => switch (module) {
  ClinicModule.patients => Icons.people_alt_outlined,
  ClinicModule.reception => Icons.how_to_reg_outlined,
  ClinicModule.appointments => Icons.calendar_month_outlined,
  ClinicModule.clinical => Icons.medical_information_outlined,
  ClinicModule.pharmacy => Icons.local_pharmacy_outlined,
  ClinicModule.vaccination => Icons.vaccines_outlined,
  ClinicModule.reminders => Icons.notifications_active_outlined,
  ClinicModule.billing => Icons.receipt_long_outlined,
  ClinicModule.expenses => Icons.account_balance_wallet_outlined,
  ClinicModule.reports => Icons.query_stats_outlined,
  ClinicModule.dataExchange => Icons.import_export_outlined,
  ClinicModule.laboratory => Icons.science_outlined,
};

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
                        '${DateFormat.yMMMd().add_jm().format(item.scheduledAt)} • ${item.channel} • ${item.status}\n${item.message}'
                        '${item.failureReason.isEmpty ? '' : '\n${item.failureReason}'}',
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
    final channel = TextEditingController(text: 'sms');
    final recipient = TextEditingController();
    final days = TextEditingController(text: '1');
    final saved = await _formDialog(context, 'Schedule reminder', [
      _field(patient, 'Patient name'),
      _field(type, 'Type'),
      _field(message, 'Message'),
      _field(channel, 'Channel (sms, whatsapp or email)'),
      _field(recipient, 'Recipient email or phone with country code'),
      _field(days, 'Send after number of days', number: true),
    ]);
    final selectedChannel = channel.text.trim().toLowerCase();
    if (saved &&
        context.mounted &&
        patient.text.trim().isNotEmpty &&
        recipient.text.trim().isNotEmpty &&
        const {'sms', 'whatsapp', 'email'}.contains(selectedChannel)) {
      await context.read<FirebaseFireStore>().saveReminder(
        ClinicReminder(
          patientName: patient.text,
          recipient: recipient.text,
          type: type.text,
          message: message.text,
          channel: selectedChannel,
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
      _notice(context, '${patients.length} patients copied as CSV.');
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
      _notice(context, 'Imported $imported patients; $errors rows rejected.');
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
