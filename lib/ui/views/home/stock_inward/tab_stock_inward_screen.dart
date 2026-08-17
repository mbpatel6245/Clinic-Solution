import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/datasources/clinical_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../core/design/app_theme.dart';
import '../../../widgets/app_design.dart';

class TabStockInward extends StatefulWidget {
  const TabStockInward({super.key});

  @override
  State<TabStockInward> createState() => _TabStockInwardState();
}

class _TabStockInwardState extends State<TabStockInward> {
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm([InventoryItem? item]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _InventoryForm(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<List<InventoryItem>>(
          stream: context.read<FirebaseFireStore>().streamInventory(),
          builder: (context, snapshot) {
            final allItems = snapshot.data ?? const <InventoryItem>[];
            final query = _search.text.toLowerCase().trim();
            final items = allItems.where((item) {
              final matchesSearch =
                  query.isEmpty ||
                  [
                    item.name,
                    item.invoiceNumber,
                    item.batchNumber,
                    item.supplier,
                  ].join(' ').toLowerCase().contains(query);
              final matchesFilter = switch (_filter) {
                'low' => item.isLowStock,
                'expiring' => item.expiresSoon || item.isExpired,
                'out' => item.remainingQuantity <= 0,
                _ => true,
              };
              return matchesSearch && matchesFilter;
            }).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      strings.stockInward,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    FilledButton.icon(
                      onPressed: _openForm,
                      icon: const Icon(Icons.add),
                      label: Text(strings.createStockEntry),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InventorySummary(items: allItems),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final search = TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: strings.searchStock,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    );
                    final filters = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _choice(strings.allStock, 'all'),
                          _choice(strings.lowStock, 'low'),
                          _choice(strings.expiringSoon, 'expiring'),
                          _choice(strings.outOfStock, 'out'),
                        ],
                      ),
                    );
                    if (constraints.maxWidth < 720) {
                      return Column(
                        children: [search, const SizedBox(height: 8), filters],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 12),
                        filters,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: snapshot.hasError
                      ? _InventoryEmpty(
                          message: '${strings.errorMessage}\n${snapshot.error}',
                        )
                      : !snapshot.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                      ? _InventoryEmpty(
                          message: allItems.isEmpty
                              ? strings.noStock
                              : strings.noResults,
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _InventoryCard(
                            item: items[index],
                            onEdit: () => _openForm(items[index]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _choice(String label, String value) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

class _InventorySummary extends StatelessWidget {
  const _InventorySummary({required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final cards = [
      (strings.allStock, items.length, Icons.inventory_2_outlined),
      (
        strings.lowStock,
        items.where((item) => item.isLowStock).length,
        Icons.warning_amber_outlined,
      ),
      (
        strings.expiringSoon,
        items.where((item) => item.expiresSoon || item.isExpired).length,
        Icons.event_busy_outlined,
      ),
      (
        strings.outOfStock,
        items.where((item) => item.remainingQuantity <= 0).length,
        Icons.remove_shopping_cart_outlined,
      ),
    ];
    return ResponsiveGrid(
      minimumItemWidth: 175,
      spacing: 10,
      children: cards
          .map(
            (data) => AppMetricCard(
              label: data.$1,
              value: '${data.$2}',
              icon: data.$3,
            ),
          )
          .toList(),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.onEdit});

  final InventoryItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    const color = AppColors.ink;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .15),
              foregroundColor: color,
              child: const Icon(Icons.medication_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (item.batchNumber.isNotEmpty)
                        Chip(
                          label: Text(
                            '${strings.batchNumber}: ${item.batchNumber}',
                          ),
                        ),
                      if (item.isExpired)
                        Chip(
                          avatar: const Icon(Icons.error_outline, size: 18),
                          label: Text(strings.outOfStock),
                        )
                      else if (item.expiresSoon)
                        Chip(
                          avatar: const Icon(Icons.schedule, size: 18),
                          label: Text(strings.expiringSoon),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 7,
                    children: [
                      _Info(
                        label: strings.remaining,
                        value:
                            '${_number(item.remainingQuantity)} / ${_number(item.quantityIn)} ${item.unit}',
                        color: color,
                      ),
                      if (item.invoiceNumber.isNotEmpty)
                        _Info(
                          label: strings.invoiceNumber,
                          value: item.invoiceNumber,
                        ),
                      if (item.supplier.isNotEmpty)
                        _Info(label: strings.supplier, value: item.supplier),
                      if (item.expiryDate != null)
                        _Info(
                          label: strings.expiryDate,
                          value: DateFormat.yMMMd(
                            locale,
                          ).format(item.expiryDate!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, action),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'add', child: Text(strings.addStock)),
                PopupMenuItem(value: 'use', child: Text(strings.useStock)),
                PopupMenuItem(value: 'edit', child: Text(strings.update)),
                PopupMenuItem(value: 'delete', child: Text(strings.delete)),
              ],
            ),
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
    if (action == 'add' || action == 'use') {
      await showDialog<void>(
        context: context,
        builder: (_) => _AdjustmentDialog(item: item, add: action == 'add'),
      );
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
    if (confirmed == true && context.mounted) {
      await context.read<FirebaseFireStore>().removeInventoryItem(item.id);
    }
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog({required this.item, required this.add});

  final InventoryItem item;
  final bool add;

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_amount.text);
    final strings = AppLocalizations.of(context)!;
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.invalidNumber)));
      return;
    }
    if (!widget.add && value > widget.item.remainingQuantity) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.invalidNumber)));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<FirebaseFireStore>().adjustInventory(
        widget.item.id,
        widget.add ? value : -value,
      );
      if (mounted) Navigator.pop(context);
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
      title: Text(widget.add ? strings.addStock : strings.useStock),
      content: TextField(
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '${strings.amount} (${widget.item.unit})',
        ),
        onSubmitted: (_) => _save(),
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

class _InventoryForm extends StatefulWidget {
  const _InventoryForm({this.item});

  final InventoryItem? item;

  @override
  State<_InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends State<_InventoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late String _unit;
  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _fields = {
      'name': TextEditingController(text: item?.name ?? ''),
      'invoice': TextEditingController(text: item?.invoiceNumber ?? ''),
      'batch': TextEditingController(text: item?.batchNumber ?? ''),
      'supplier': TextEditingController(text: item?.supplier ?? ''),
      'manufacturer': TextEditingController(text: item?.manufacturer ?? ''),
      'quantity': TextEditingController(
        text: item == null ? '' : '${item.quantityIn}',
      ),
      'remaining': TextEditingController(
        text: item == null ? '' : '${item.remainingQuantity}',
      ),
      'minimum': TextEditingController(
        text: item == null ? '' : '${item.minimumLevel}',
      ),
      'rate': TextEditingController(
        text: item == null ? '' : '${item.purchaseRate}',
      ),
      'mrp': TextEditingController(text: item == null ? '' : '${item.mrp}'),
      'notes': TextEditingController(text: item?.notes ?? ''),
    };
    _unit = item?.unit ?? 'units';
    _purchaseDate = item?.purchaseDate ?? DateTime.now();
    _expiryDate = item?.expiryDate;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _number(String key) => double.tryParse(_fields[key]!.text) ?? 0;

  Future<void> _pickDate(bool expiry) async {
    final value = await showDatePicker(
      context: context,
      initialDate: expiry
          ? (_expiryDate ?? DateTime.now())
          : (_purchaseDate ?? DateTime.now()),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value == null || !mounted) return;
    setState(() => expiry ? _expiryDate = value : _purchaseDate = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final quantity = _number('quantity');
    final remaining = _fields['remaining']!.text.trim().isEmpty
        ? quantity
        : _number('remaining');
    if (quantity <= 0 || remaining < 0 || remaining > quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.invalidNumber)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<FirebaseFireStore>().saveInventoryItem(
        InventoryItem(
          id: widget.item?.id ?? '',
          name: _fields['name']!.text,
          invoiceNumber: _fields['invoice']!.text,
          batchNumber: _fields['batch']!.text,
          supplier: _fields['supplier']!.text,
          manufacturer: _fields['manufacturer']!.text,
          quantityIn: quantity,
          remainingQuantity: remaining,
          minimumLevel: _number('minimum'),
          purchaseRate: _number('rate'),
          mrp: _number('mrp'),
          unit: _unit,
          purchaseDate: _purchaseDate,
          expiryDate: _expiryDate,
          notes: _fields['notes']!.text,
          createdAt: widget.item?.createdAt,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.item == null
                ? AppLocalizations.of(context)!.stockSavedSuccessfully
                : AppLocalizations.of(context)!.stockUpdatedSuccessfully,
          ),
        ),
      );
      Navigator.pop(context);
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
    final locale = Localizations.localeOf(context).toString();
    return AlertDialog(
      title: Text(
        widget.item == null ? strings.createStockEntry : strings.editStockEntry,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field('name', strings.brandName, required: true),
                _field('invoice', strings.invoiceNumber, required: true),
                _field('batch', strings.batchNumber),
                _field('supplier', strings.supplier),
                _field('manufacturer', strings.manufacturerName),
                _field(
                  'quantity',
                  strings.stockReceived,
                  number: true,
                  required: true,
                ),
                _field('remaining', strings.remaining, number: true),
                _field('minimum', strings.minimumAvailability, number: true),
                _field('rate', strings.rateOfPurchase, number: true),
                _field('mrp', strings.mrp, number: true),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: InputDecoration(labelText: strings.unit),
                    items:
                        const [
                              'units',
                              'tablets',
                              'strips',
                              'bottles',
                              'boxes',
                              'ml',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => _unit = value ?? 'units',
                  ),
                ),
                _datePicker(
                  strings.purchaseDate,
                  _purchaseDate == null
                      ? ''
                      : DateFormat.yMMMd(locale).format(_purchaseDate!),
                  () => _pickDate(false),
                ),
                _datePicker(
                  strings.expiryDate,
                  _expiryDate == null
                      ? ''
                      : DateFormat.yMMMd(locale).format(_expiryDate!),
                  () => _pickDate(true),
                  clear: _expiryDate == null
                      ? null
                      : () => setState(() => _expiryDate = null),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    controller: _fields['notes'],
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: strings.notes),
                  ),
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

  Widget _field(
    String key,
    String label, {
    bool number = false,
    bool required = false,
  }) {
    final strings = AppLocalizations.of(context)!;
    return SizedBox(
      width: 230,
      child: TextFormField(
        controller: _fields[key],
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return strings.requiredField;
          }
          if (number &&
              value != null &&
              value.isNotEmpty &&
              double.tryParse(value) == null) {
            return strings.invalidNumber;
          }
          return null;
        },
      ),
    );
  }

  Widget _datePicker(
    String label,
    String value,
    VoidCallback onTap, {
    VoidCallback? clear,
  }) {
    return SizedBox(
      width: 230,
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: clear == null
                ? const Icon(Icons.calendar_today_outlined)
                : IconButton(onPressed: clear, icon: const Icon(Icons.clear)),
          ),
          child: Text(value.isEmpty ? '—' : value),
        ),
      ),
    );
  }
}

class _InventoryEmpty extends StatelessWidget {
  const _InventoryEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
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
