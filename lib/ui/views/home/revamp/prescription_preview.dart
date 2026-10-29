import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/design/uvilo_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../../../core/auth/app_role.dart';
import '../../../../core/design/revamp_labels.dart';
import '../../../../data/datasources/clinical_models.dart';
import '../../../../data/datasources/enterprise_models.dart';
import '../../../../data/datasources/prescription_print_settings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/prescription_document.dart';
import '../../../../services/session_controller.dart';

Future<void> showPrescriptionPreview(
  BuildContext context,
  PrescriptionModel record,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => PrescriptionPreviewScreen(record: record),
  ),
);

class PrescriptionPreviewScreen extends StatefulWidget {
  const PrescriptionPreviewScreen({super.key, required this.record});
  final PrescriptionModel record;
  @override
  State<PrescriptionPreviewScreen> createState() =>
      _PrescriptionPreviewScreenState();
}

class _PrescriptionPreviewScreenState extends State<PrescriptionPreviewScreen> {
  late final String _clinicId;
  String? _userId;
  bool get _authorized =>
      mounted &&
      context.read<SessionController>().activeClinicId == _clinicId &&
      context.read<FirebaseFireStore>().activeClinicId == _clinicId &&
      (context.read<SessionController>().can(AppFeature.prescriptionList) ||
          context.read<SessionController>().can(
            AppFeature.createPrescription,
          )) &&
      (Firebase.apps.isEmpty ||
          (_userId != null &&
              FirebaseAuth.instance.currentUser?.uid == _userId));
  late Future<(ClinicProfile, PrescriptionPrintSettings)> _context;
  @override
  void initState() {
    super.initState();
    _clinicId = context.read<SessionController>().activeClinicId;
    if (Firebase.apps.isNotEmpty) {
      _userId = FirebaseAuth.instance.currentUser?.uid;
    }
    _reload();
  }

  void _reload() {
    final service = context.read<FirebaseFireStore>();
    _context = () async {
      if (!_authorized ||
          (widget.record.clinicId.isNotEmpty &&
              widget.record.clinicId != _clinicId)) {
        throw StateError('Clinic changed.');
      }
      if (widget.record.clinicalState == 'signed' &&
          widget.record.clinicalPrintContext.isNotEmpty) {
        final frozen = widget.record.clinicalPrintContext;
        return (
          ClinicProfile.fromMap(frozen, _clinicId),
          PrescriptionPrintSettings.fromMap(frozen),
        );
      }
      final clinic = await service.streamActiveClinic().first;
      if (!_authorized) {
        throw StateError('Clinic changed.');
      }
      final settings = await service.getPrescriptionPrintSettings();
      if (!_authorized) throw StateError('Clinic changed.');
      return (clinic, settings);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    context.watch<SessionController>();
    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.text('clinicChanged'))),
      );
    }
    return FutureBuilder<(ClinicProfile, PrescriptionPrintSettings)>(
      future: _context,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(l.text('printPreview'))),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.text('previewError')),
                  TextButton(
                    onPressed: () => setState(_reload),
                    child: Text(l.text('retry')),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final (clinic, settings) = snapshot.data!;
        return PrescriptionPreviewView(
          record: widget.record,
          clinic: clinic,
          settings: settings,
          onConfigure:
              widget.record.clinicalState != 'signed' &&
                  context.read<SessionController>().can(AppFeature.clinicSetup)
              ? () async {
                  final updated = await showDialog<PrescriptionPrintSettings>(
                    context: context,
                    builder: (_) =>
                        PrescriptionLetterheadForm(settings: settings),
                  );
                  if (updated == null ||
                      !context.mounted ||
                      !_authorized ||
                      !context.read<SessionController>().can(
                        AppFeature.clinicSetup,
                      )) {
                    return;
                  }
                  try {
                    await context
                        .read<FirebaseFireStore>()
                        .savePrescriptionPrintSettings(updated);
                    if (mounted) setState(_reload);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.text('saveError'))),
                      );
                    }
                  }
                }
              : null,
        );
      },
    );
  }
}

class PrescriptionPreviewView extends StatefulWidget {
  const PrescriptionPreviewView({
    super.key,
    required this.record,
    required this.clinic,
    this.settings = const PrescriptionPrintSettings(),
    this.onConfigure,
    this.documentBuilder,
    this.previewBuilder,
  });
  final PrescriptionModel record;
  final ClinicProfile clinic;
  final PrescriptionPrintSettings settings;
  final VoidCallback? onConfigure;
  // Optional adapters also allow verifying refresh behavior without a printer.
  final Future<Uint8List> Function(String language)? documentBuilder;
  final Widget Function(Key key, Uint8List bytes)? previewBuilder;
  @override
  State<PrescriptionPreviewView> createState() =>
      _PrescriptionPreviewViewState();
}

class _PrescriptionPreviewViewState extends State<PrescriptionPreviewView> {
  String? _language;
  Future<Uint8List>? _document;
  int _revision = 0;
  void _prepare() => _document =
      widget.documentBuilder?.call(_language!) ??
      PrescriptionDocument.build(
        record: widget.record,
        clinic: widget.clinic,
        settings: widget.settings,
        language: _language!,
      );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_language == null) {
      _language = Localizations.localeOf(context).languageCode;
      _prepare();
    }
  }

  @override
  void didUpdateWidget(PrescriptionPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings ||
        oldWidget.record != widget.record) {
      _prepare();
      _revision++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    return Theme(
      data: UviloTheme.light,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.text('printPreview')),
          actions: [
            if (widget.onConfigure != null)
              IconButton(
                tooltip: l.text('letterhead'),
                onPressed: widget.onConfigure,
                icon: const Icon(Icons.tune),
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l.text('reviewPrint')),
                  DropdownButton<String>(
                    value: _language,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                      DropdownMenuItem(value: 'gu', child: Text('ગુજરાતી')),
                    ],
                    onChanged: (value) => setState(() {
                      _language = value!;
                      _prepare();
                      _revision++;
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: _document,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.text('previewError')),
                          TextButton(
                            onPressed: () => setState(() {
                              _prepare();
                              _revision++;
                            }),
                            child: Text(l.text('retry')),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final documentKey = ValueKey((_revision, snapshot.data));
                  if (widget.previewBuilder != null) {
                    return widget.previewBuilder!(documentKey, snapshot.data!);
                  }
                  return PdfPreview(
                    key: documentKey,
                    build: (_) => Future.value(snapshot.data!),
                    initialPageFormat: PdfPageFormat.a4,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    pdfFileName:
                        'prescription-${DateFormat('yyyyMMdd').format(widget.record.visitDate ?? widget.record.createdAt ?? DateTime.now())}.pdf',
                    maxPageWidth: 800,
                    onError: (_, _) =>
                        Center(child: Text(l.text('previewError'))),
                    onPrintError: (_, _) =>
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.text('previewError'))),
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

class PrescriptionLetterheadForm extends StatefulWidget {
  const PrescriptionLetterheadForm({super.key, required this.settings});
  final PrescriptionPrintSettings settings;
  @override
  State<PrescriptionLetterheadForm> createState() =>
      _PrescriptionLetterheadFormState();
}

class _PrescriptionLetterheadFormState
    extends State<PrescriptionLetterheadForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.settings.clinicianName),
      _qualification = TextEditingController(
        text: widget.settings.qualifications,
      ),
      _registration = TextEditingController(text: widget.settings.registration),
      _footer = TextEditingController(text: widget.settings.footerNote);
  late var _layout = widget.settings.layout;
  late bool _diagnoses = widget.settings.showDiagnoses,
      _vitals = widget.settings.showVitals,
      _phone = widget.settings.showPhone;
  late double _size = widget.settings.fontSize,
      _margin = widget.settings.marginMm;
  @override
  void dispose() {
    for (final c in [_name, _qualification, _registration, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context), s = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.text('letterhead')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<PrescriptionLayout>(
                  initialValue: _layout,
                  decoration: InputDecoration(labelText: l.text('layout')),
                  items: [
                    for (final layout in PrescriptionLayout.values)
                      DropdownMenuItem(
                        value: layout,
                        child: Text(l.text(layout.name)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _layout = value!),
                ),
                const SizedBox(height: 16),
                for (final (controller, key, max) in [
                  (_name, 'clinicianName', 160),
                  (_qualification, 'qualifications', 160),
                  (_registration, 'registration', 160),
                  (_footer, 'footerNote', 400),
                ])
                  TextFormField(
                    controller: controller,
                    decoration: InputDecoration(labelText: l.text(key)),
                    maxLength: max,
                    maxLines: key == 'footerNote' ? 3 : 1,
                  ),
                SwitchListTile(
                  title: Text(l.text('printDiagnoses')),
                  value: _diagnoses,
                  onChanged: (v) => setState(() => _diagnoses = v),
                ),
                SwitchListTile(
                  title: Text(l.text('printVitals')),
                  value: _vitals,
                  onChanged: (v) => setState(() => _vitals = v),
                ),
                SwitchListTile(
                  title: Text(l.text('printPhone')),
                  value: _phone,
                  onChanged: (v) => setState(() => _phone = v),
                ),
                Text('${l.text('printTextSize')}: ${_size.round()} pt'),
                Slider(
                  value: _size,
                  min: 11,
                  max: 14,
                  divisions: 3,
                  onChanged: (v) => setState(() => _size = v),
                ),
                Text('${l.text('printMargin')}: ${_margin.round()} mm'),
                Slider(
                  value: _margin,
                  min: 12,
                  max: 25,
                  divisions: 13,
                  onChanged: (v) => setState(() => _margin = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              PrescriptionPrintSettings(
                layout: _layout,
                clinicianName: _name.text,
                qualifications: _qualification.text,
                registration: _registration.text,
                footerNote: _footer.text,
                showDiagnoses: _diagnoses,
                showVitals: _vitals,
                showPhone: _phone,
                fontSize: _size,
                marginMm: _margin,
              ),
            );
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}
