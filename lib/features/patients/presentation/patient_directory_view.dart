import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../ui/widgets/app_design.dart';
import '../domain/patient_directory.dart';
import 'patient_labels.dart';

class PatientDirectoryView extends StatefulWidget {
  const PatientDirectoryView({
    super.key,
    required this.patients,
    required this.onOpen,
    required this.onRegister,
    this.appointments = const [],
    this.loading = false,
    this.hasError = false,
    this.onRetry,
  });
  final List<PatientModel> patients;
  final List<AppointmentModel> appointments;
  final ValueChanged<PatientModel> onOpen;
  final VoidCallback onRegister;
  final bool loading, hasError;
  final VoidCallback? onRetry;
  @override
  State<PatientDirectoryView> createState() => _PatientDirectoryViewState();
}

class _PatientDirectoryViewState extends State<PatientDirectoryView> {
  String _search = '';
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final l = PatientLabels.of(context);
    final page = patientDirectoryPage(
      widget.patients,
      search: _search,
      page: _page,
    );
    final now = DateTime.now();
    AppointmentModel? next(PatientModel p) {
      final items =
          widget.appointments
              .where(
                (a) =>
                    a.patientId == p.id &&
                    a.scheduledAt.isAfter(now) &&
                    !{'cancelled', 'no_show', 'completed'}.contains(a.status),
              )
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return items.firstOrNull;
    }

    Widget svg(String name, double size) => SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset('assets/figma/phase2/n4_18003_$name.svg'),
    );
    Widget summary(String title, String value, {Widget? icon}) => Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: UviloTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            ?icon,
          ],
        ),
      ),
    );
    final futurePatientIds = widget.appointments
        .where(
          (a) =>
              a.scheduledAt.isAfter(now) &&
              !{'cancelled', 'no_show', 'completed'}.contains(a.status),
        )
        .map((a) => a.patientId)
        .toSet();
    final metrics = [
      summary(
        l('registered'),
        '${widget.patients.length}',
        icon: svg('imgUsers1', 24),
      ),
      summary(
        l('newMonth'),
        '${widget.patients.where((p) => p.createdAt != null && p.createdAt!.year == now.year && p.createdAt!.month == now.month).length}',
      ),
      summary(
        l('withBooking'),
        '${widget.patients.where((p) => futurePatientIds.contains(p.id)).length}',
      ),
    ];
    return Theme(
      data: UviloTheme.light,
      child: AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Text(
                  l('patients'),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                FilledButton.icon(
                  onPressed: widget.onRegister,
                  icon: svg('imgUserPlus', 16),
                  label: Text(l('add')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l('directoryHint'),
              style: const TextStyle(color: UviloTheme.muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (_, box) =>
                  box.maxWidth >= 760 &&
                      MediaQuery.textScalerOf(context).scale(14) < 22
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < metrics.length; i++) ...[
                          if (i > 0) const SizedBox(width: 20),
                          Expanded(child: metrics[i]),
                        ],
                      ],
                    )
                  : Column(
                      children: [
                        for (final metric in metrics)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: metric,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            AppSection(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        l('directory'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onRegister,
                        child: Text(l('register')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(14),
                        child: svg('imgSearch1', 16),
                      ),
                      hintText: l('search'),
                    ),
                    onChanged: (v) => setState(() {
                      _search = v;
                      _page = 0;
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (widget.hasError) ...[
                    Text(l('loadError')),
                    if (widget.onRetry != null)
                      TextButton(
                        onPressed: widget.onRetry,
                        child: Text(l('retry')),
                      ),
                  ] else if (widget.loading)
                    const LinearProgressIndicator()
                  else if (page.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l(_search.isEmpty ? 'empty' : 'noMatch')),
                    )
                  else
                    LayoutBuilder(
                      builder: (_, box) {
                        if (box.maxWidth < 760 ||
                            MediaQuery.textScalerOf(context).scale(14) > 22) {
                          return Column(
                            children: [
                              for (final p in page.items)
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  title: Text(p.fullName),
                                  subtitle: Text('${p.id}\n${p.phone}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => widget.onOpen(p),
                                ),
                            ],
                          );
                        }
                        return Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.4),
                            1: FlexColumnWidth(1.1),
                            2: FlexColumnWidth(1.2),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          border: const TableBorder(
                            horizontalInside: BorderSide(
                              color: UviloTheme.border,
                            ),
                          ),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: UviloTheme.canvas,
                              ),
                              children: [
                                for (final title in [
                                  'identity',
                                  'ageSex',
                                  'contact',
                                  'registeredOn',
                                  'nextAppointment',
                                  'registration',
                                ])
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      l(title).toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: UviloTheme.muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            for (final p in page.items)
                              TableRow(
                                children: [
                                  TextButton(
                                    onPressed: () => widget.onOpen(p),
                                    style: TextButton.styleFrom(
                                      alignment: Alignment.centerLeft,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p.fullName),
                                        Text(
                                          p.id,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: UviloTheme.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      [
                                        if (p.ageInYearsAt(now) != null)
                                          '${p.ageInYearsAt(now)!.floor()} ${l('years')}',
                                        p.gender,
                                      ].where((v) => v.isNotEmpty).join(' · '),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      p.phone.isEmpty ? '—' : p.phone,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      p.createdAt == null
                                          ? '—'
                                          : DateFormat.yMMMd(
                                              Localizations.localeOf(
                                                context,
                                              ).toString(),
                                            ).format(p.createdAt!),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      next(p) == null
                                          ? l('notBooked')
                                          : DateFormat.MMMd().add_jm().format(
                                              next(p)!.scheduledAt,
                                            ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: TextButton(
                                      onPressed: () => widget.onOpen(p),
                                      child: Text(l('manage')),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${l('showing')} ${page.total == 0 ? 0 : page.page * 8 + 1}–${page.page * 8 + page.items.length} / ${page.total}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: UviloTheme.muted,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l('previous'),
                            onPressed: page.page > 0
                                ? () => setState(() => _page = page.page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('${page.page + 1} / ${page.pages}'),
                          IconButton(
                            tooltip: l('next'),
                            onPressed: page.page + 1 < page.pages
                                ? () => setState(() => _page = page.page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: UviloTheme.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  svg('imgInfo', 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l('privacy'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: UviloTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
