import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/datasources/clinical_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';

class TabPrescriptionList extends StatefulWidget {
  const TabPrescriptionList({
    super.key,
    required this.onNewVisit,
    required this.onEditPrescription,
  });

  final ValueChanged<PatientModel> onNewVisit;
  final ValueChanged<PrescriptionModel> onEditPrescription;

  @override
  State<TabPrescriptionList> createState() => _TabPrescriptionListState();
}

class _TabPrescriptionListState extends State<TabPrescriptionList> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
            Text(
              strings.prescriptionList,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: strings.searchPatient,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: strings.clearFilters,
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<PrescriptionModel>>(
                stream: context.read<FirebaseFireStore>().streamPrescriptions(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _MessageState(
                      icon: Icons.cloud_off_outlined,
                      message: '${strings.errorMessage}\n${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final query = _search.text.toLowerCase().trim();
                  final records = snapshot.data!.where((record) {
                    final searchable = [
                      record.patient.fullName,
                      record.patient.phone,
                      record.patient.address,
                      record.diagnoses.join(' '),
                      record.medicines.map((item) => item.name).join(' '),
                    ].join(' ').toLowerCase();
                    return query.isEmpty || searchable.contains(query);
                  }).toList();
                  if (records.isEmpty) {
                    return _MessageState(
                      icon: Icons.person_search_outlined,
                      message: query.isEmpty
                          ? strings.noPrescriptions
                          : strings.noResults,
                    );
                  }
                  return ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final date =
                          record.visitDate ??
                          record.createdAt ??
                          DateTime.now();
                      final previousDate = index == 0
                          ? null
                          : records[index - 1].visitDate ??
                                records[index - 1].createdAt;
                      final showHeader =
                          previousDate == null ||
                          previousDate.year != date.year ||
                          previousDate.month != date.month ||
                          previousDate.day != date.day;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showHeader) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                DateFormat.yMMMMd(
                                  Localizations.localeOf(context).toString(),
                                ).format(date),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                          _PrescriptionCard(
                            record: record,
                            onNewVisit: widget.onNewVisit,
                            onEditPrescription: widget.onEditPrescription,
                          ),
                        ],
                      );
                    },
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

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.record,
    required this.onNewVisit,
    required this.onEditPrescription,
  });

  final PrescriptionModel record;
  final ValueChanged<PatientModel> onNewVisit;
  final ValueChanged<PrescriptionModel> onEditPrescription;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(record.visitDate ?? record.createdAt ?? DateTime.now());
    final canStartNewVisit = record.canStartNewVisitAt(DateTime.now());
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Text(_initials(record.patient.fullName)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.patient.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        [
                          if (record.patient.phone.isNotEmpty)
                            record.patient.phone,
                          if (record.patient.age != null)
                            '${record.patient.age} ${strings.age}',
                          date,
                        ].join(' • '),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) => _handleAction(context, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'details',
                      child: Text(strings.viewDetails),
                    ),
                    PopupMenuItem(
                      value: canStartNewVisit ? 'visit' : 'edit',
                      child: Text(
                        canStartNewVisit
                            ? strings.newVisit
                            : 'Edit prescription',
                      ),
                    ),
                    PopupMenuItem(value: 'delete', child: Text(strings.delete)),
                  ],
                ),
              ],
            ),
            if (record.diagnoses.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Diagnosis: ${record.diagnoses.join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (record.complaints.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                '${strings.chiefComplaints}: ${record.complaints}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (record.medicines.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'Medicines: ${record.medicines.take(3).map((item) => item.name).where((name) => name.isNotEmpty).join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final service = context.read<FirebaseFireStore>();
    if (action == 'details') {
      await showDialog<void>(
        context: context,
        builder: (_) => _PrescriptionDetails(record: record),
      );
      return;
    }
    if (action == 'visit') {
      onNewVisit(record.patient);
      return;
    }
    if (action == 'edit') {
      onEditPrescription(record);
      return;
    }
    if (action == 'delete') {
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
      if (confirmed == true) await service.removePrescription(record.id);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _PrescriptionDetails extends StatelessWidget {
  const _PrescriptionDetails({required this.record});

  final PrescriptionModel record;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(record.patient.fullName),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail(strings.phone, record.patient.phone),
              _detail(strings.address, record.patient.address),
              _detail(strings.diagnosis, record.diagnoses.join(', ')),
              _detail(strings.chiefComplaints, record.complaints),
              _detail(strings.vitals, record.vitals),
              _detail(strings.investigation, record.investigation),
              _detail(strings.advice, record.advice),
              const Divider(height: 28),
              Text(
                strings.medicines,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (record.medicines.isEmpty)
                Text('—')
              else
                for (final medicine in record.medicines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.medication_outlined),
                    title: Text(medicine.name),
                    subtitle: Text(
                      [
                        medicine.dosage,
                        medicine.frequency,
                        medicine.duration,
                        medicine.instructions,
                      ].where((value) => value.isNotEmpty).join(' • '),
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
