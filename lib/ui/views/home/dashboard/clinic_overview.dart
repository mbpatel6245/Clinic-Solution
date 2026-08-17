import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/design/app_theme.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../widgets/app_design.dart';

class ClinicOverview extends StatefulWidget {
  const ClinicOverview({super.key, required this.showFinance});

  final bool showFinance;

  @override
  State<ClinicOverview> createState() => _ClinicOverviewState();
}

class _ClinicOverviewState extends State<ClinicOverview> {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<AppointmentModel> _appointments = const [];
  List<PrescriptionModel> _prescriptions = const [];
  List<InventoryItem> _inventory = const [];
  List<FinanceEntry> _finance = const [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final service = context.read<FirebaseFireStore>();
    _subscriptions.addAll([
      service.streamAppointments().listen(
        (value) => _set(() => _appointments = value),
      ),
      service.streamPrescriptions().listen(
        (value) => _set(() => _prescriptions = value),
      ),
      service.streamInventory().listen(
        (value) => _set(() => _inventory = value),
      ),
      if (widget.showFinance)
        service.streamFinanceEntries().listen(
          (value) => _set(() => _finance = value),
        ),
    ]);
  }

  void _set(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthEntries = _finance.where(
      (entry) =>
          entry.occurredAt.year == now.year &&
          entry.occurredAt.month == now.month,
    );
    final income = monthEntries
        .where((entry) => entry.type == FinanceEntryType.income)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final expense = monthEntries
        .where((entry) => entry.type == FinanceEntryType.expense)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final todaysAppointments = _appointments.where((appointment) {
      final date = appointment.scheduledAt;
      return DateTime(date.year, date.month, date.day) == today;
    }).length;
    final monthVisits = _prescriptions.where((prescription) {
      final date = prescription.visitDate ?? prescription.createdAt;
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
    final uniquePatients = _prescriptions
        .map(
          (item) =>
              item.patient.id.isEmpty ? item.patient.phone : item.patient.id,
        )
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    final lowStock = _inventory.where((item) => item.isLowStock).length;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.clinicOverview,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormat.yMMMM(
              Localizations.localeOf(context).toString(),
            ).format(now),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ResponsiveGrid(
            children: [
              AppMetricCard(
                label: strings.todaysAppointments,
                value: '$todaysAppointments',
                icon: Icons.today_outlined,
              ),
              AppMetricCard(
                label: strings.monthlyVisits,
                value: '$monthVisits',
                icon: Icons.medical_services_outlined,
              ),
              AppMetricCard(
                label: strings.totalPatients,
                value: '$uniquePatients',
                icon: Icons.groups_outlined,
              ),
              AppMetricCard(
                label: strings.lowStock,
                value: '$lowStock',
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
          if (widget.showFinance) ...[
            const SizedBox(height: AppSpacing.lg),
            AppSection(
              title: strings.financialPerformance,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResponsiveGrid(
                    minimumItemWidth: 200,
                    children: [
                      AppMetricCard(
                        label: strings.income,
                        value: _money(context, income),
                        icon: Icons.south_west,
                      ),
                      AppMetricCard(
                        label: strings.expense,
                        value: _money(context, expense),
                        icon: Icons.north_east,
                      ),
                      AppMetricCard(
                        label: strings.netBalance,
                        value: _money(context, income - expense),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FinanceBars(income: income, expense: expense),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FinanceLedgerScreen extends StatelessWidget {
  const FinanceLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return StreamBuilder<List<FinanceEntry>>(
      stream: context.read<FirebaseFireStore>().streamFinanceEntries(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <FinanceEntry>[];
        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    strings.incomeAndExpense,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  FilledButton.icon(
                    onPressed: () => _showFinanceDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(strings.addTransaction),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (entries.isEmpty)
                AppSection(child: Center(child: Text(strings.noTransactions)))
              else
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.ink,
                          foregroundColor: AppColors.inverse,
                          child: Icon(
                            entry.type == FinanceEntryType.income
                                ? Icons.south_west
                                : Icons.north_east,
                          ),
                        ),
                        title: Text(entry.category),
                        subtitle: Text(
                          '${entry.type == FinanceEntryType.income ? '+' : '-'}${_money(context, entry.amount)}\n'
                          '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(entry.occurredAt)}'
                          '${entry.description.isEmpty ? '' : ' • ${entry.description}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              context
                                  .read<FirebaseFireStore>()
                                  .removeFinanceEntry(entry.id);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(strings.delete),
                            ),
                          ],
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
  }

  Future<void> _showFinanceDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _FinanceEntryDialog(),
    );
  }
}

class _FinanceBars extends StatelessWidget {
  const _FinanceBars({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final maximum = [income, expense, 1.0].reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        _bar(context, strings.income, income / maximum),
        const SizedBox(height: AppSpacing.md),
        _bar(context, strings.expense, expense / maximum),
      ],
    );
  }

  Widget _bar(BuildContext context, String label, double fraction) => Row(
    children: [
      SizedBox(width: 90, child: Text(label, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            minHeight: 18,
            value: fraction,
            backgroundColor: AppColors.soft,
            color: AppColors.ink,
          ),
        ),
      ),
    ],
  );
}

class _FinanceEntryDialog extends StatefulWidget {
  const _FinanceEntryDialog();

  @override
  State<_FinanceEntryDialog> createState() => _FinanceEntryDialogState();
}

class _FinanceEntryDialogState extends State<_FinanceEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  FinanceEntryType _type = FinanceEntryType.income;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.addTransaction),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<FinanceEntryType>(
                  segments: [
                    ButtonSegment(
                      value: FinanceEntryType.income,
                      label: Text(strings.income),
                    ),
                    ButtonSegment(
                      value: FinanceEntryType.expense,
                      label: Text(strings.expense),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) =>
                      setState(() => _type = value.first),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _amount,
                  decoration: InputDecoration(labelText: strings.amount),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                      ? strings.invalidNumber
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _category,
                  decoration: InputDecoration(labelText: strings.category),
                  validator: (value) => value?.trim().isEmpty == true
                      ? strings.requiredField
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  decoration: InputDecoration(labelText: strings.description),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.date),
                  subtitle: Text(DateFormat.yMMMd().format(_date)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (value != null) setState(() => _date = value);
                  },
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
          child: Text(strings.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await context.read<FirebaseFireStore>().saveFinanceEntry(
      FinanceEntry(
        type: _type,
        amount: double.parse(_amount.text),
        category: _category.text,
        description: _description.text,
        occurredAt: _date,
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}

String _money(BuildContext context, double value) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toString(),
  symbol: '₹',
  decimalDigits: 0,
).format(value);
