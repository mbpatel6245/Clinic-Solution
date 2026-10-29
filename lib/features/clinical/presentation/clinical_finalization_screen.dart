import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../domain/clinical_repository.dart';
import '../../../data/datasources/clinical_models.dart';
import 'clinical_components.dart';
import 'prescription_review.dart';
import '../../../shared/presentation/guarded_dialog_content.dart';

/// Every visible signed/released state comes from a fresh server read. Network
/// errors preserve the same operation ID; finalization never replays on resume.
class ClinicalFinalizationScreen extends StatefulWidget {
  const ClinicalFinalizationScreen({
    super.key,
    required this.initial,
    required this.repository,
    required this.clinicName,
    required this.authorized,
    required this.changes,
    required this.sharingEnabled,
    this.onPrint,
    this.onAmended,
    this.onDone,
  });
  final ClinicalEncounter initial;
  final ClinicalRepository repository;
  final String clinicName;
  final bool Function() authorized, sharingEnabled;
  final Listenable changes;
  final ValueChanged<PrescriptionModel>? onPrint;
  final ValueChanged<ClinicalEncounter>? onAmended;
  final VoidCallback? onDone;
  @override
  State<ClinicalFinalizationScreen> createState() =>
      _ClinicalFinalizationScreenState();
}

class _ClinicalFinalizationScreenState
    extends State<ClinicalFinalizationScreen> {
  late ClinicalEncounter _encounter = widget.initial;
  final _reason = TextEditingController();
  final _operations = <String, Map<String, Object?>>{};
  bool _busy = false, _error = false, _releaseChecked = false;
  Future<void> _revoke() async {
    if (_busy || !widget.authorized()) return;
    final l = ClinicalLabels.of(context),
        reason = TextEditingController(),
        form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => GuardedDialogContent(
        changes: widget.changes,
        isAuthorized: widget.authorized,
        message: l('remoteError'),
        child: AlertDialog(
          title: Text(l('revoke')),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: TextFormField(
                controller: reason,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(labelText: l('revokeReason')),
                validator: (v) =>
                    (v?.trim().length ?? 0) >= 5 ? null : l('revokeReason'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(l('revoke')),
            ),
          ],
        ),
      ),
    );
    final text = reason.text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    reason.dispose();
    if (!mounted || accepted != true || !widget.authorized()) return;
    await _command('revoke', {'reason': text, 'revokeAcknowledgement': true});
  }

  Future<void> _history() async {
    if (!widget.authorized() ||
        widget.repository is! ClinicalVersionRepository) {
      return;
    }
    final l = ClinicalLabels.of(context);
    final versions = (widget.repository as ClinicalVersionRepository).versions(
      _encounter.id,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => GuardedDialogContent(
        changes: widget.changes,
        isAuthorized: widget.authorized,
        message: l('remoteError'),
        child: AlertDialog(
          title: Text(l('versions')),
          content: SizedBox(
            width: 520,
            height: 420,
            child: FutureBuilder<List<PrescriptionModel>>(
              future: versions,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text(l('remoteError'));
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: [
                    for (final record in snapshot.data!)
                      ListTile(
                        title: Text(
                          '${l('signedRecord')} · ${record.clinicalVersion}',
                        ),
                        subtitle: Text(
                          record.clinicalPrintContext['clinician_name']
                                  ?.toString() ??
                              '',
                        ),
                        trailing: widget.onPrint == null
                            ? null
                            : IconButton(
                                tooltip: l('print'),
                                icon: const Icon(Icons.print_outlined),
                                onPressed: () {
                                  if (!widget.authorized()) return;
                                  Navigator.pop(dialogContext);
                                  widget.onPrint!(record);
                                },
                              ),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_busy || !widget.authorized()) return;
    setState(() => _busy = true);
    try {
      final current = await widget.repository.load(_encounter.id);
      if (!mounted || !widget.authorized()) return;
      setState(() {
        _encounter = current;
        _error = false;
        _releaseChecked = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _command(
    String kind, [
    Map<String, Object?> extra = const {},
  ]) async {
    if (_busy || !widget.authorized()) return;
    final details = <String, Object?>{
      'kind': kind,
      'encounterId': _encounter.id,
      'expectedRevision': _encounter.revision,
      ...extra,
    };
    final operation = _operations.putIfAbsent(
      jsonEncode(details),
      () => {...details, 'operationId': widget.repository.newOperationId()},
    );
    setState(() => _busy = true);
    try {
      await widget.repository.command(operation);
      final current = await widget.repository.load(_encounter.id);
      if (!mounted || !widget.authorized()) return;
      if (kind == 'amend') {
        if (widget.onAmended != null) {
          widget.onAmended!(current);
        } else {
          Navigator.pop(context, current);
        }
        return;
      }
      setState(() {
        _encounter = current;
        _error = false;
        _releaseChecked = false;
      });
    } catch (_) {
      if (mounted && widget.authorized()) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.changes,
    builder: (context, _) {
      final l = ClinicalLabels.of(context);
      if (!widget.authorized()) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(l('remoteError'))),
        );
      }
      return PopScope(
        canPop: !_busy,
        child: PrescriptionReview(
          key: ValueKey((_encounter.id, _encounter.revision)),
          record: _encounter.record,
          clinicName: widget.clinicName,
          signing: !_encounter.signed,
          signed: _encounter.signed,
          busy: _busy || _error,
          notice: Column(
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error) Text(l('remoteError')),
              if (_error)
                TextButton(
                  onPressed: _busy ? null : _reload,
                  child: Text(l('reload')),
                ),
            ],
          ),
          onConfirm: () => _command('sign', {
            'identityReviewed': true,
            'medicationReviewed': true,
            'planReviewed': true,
            'finalAcknowledgement': true,
          }),
          actions: !_encounter.signed
              ? (_encounter.releasedVersion > 0
                    ? Column(
                        children: [
                          Text(l('publishedVersion')),
                          TextButton(
                            onPressed: _busy || _error ? null : _revoke,
                            child: Text(l('revoke')),
                          ),
                        ],
                      )
                    : null)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onPrint != null)
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => widget.onPrint!(_encounter.record),
                        icon: SvgPicture.asset(
                          'assets/figma/phase3/4_18896_imgPrinter.svg',
                          width: 16,
                          height: 16,
                        ),
                        label: Text(l('print')),
                      ),
                    if (widget.repository is ClinicalVersionRepository)
                      TextButton(
                        onPressed: _busy ? null : _history,
                        child: Text(l('versions')),
                      ),
                    const SizedBox(height: 16),
                    if (_encounter.releasedVersion == _encounter.version) ...[
                      Text(l('released')),
                      TextButton(
                        onPressed: _busy || _error ? null : _revoke,
                        child: Text(l('revoke')),
                      ),
                    ] else if (widget.sharingEnabled() &&
                        _encounter.record.patient.userId.isNotEmpty) ...[
                      Text(
                        '${_encounter.record.patient.fullName} · ${_encounter.record.patient.id}',
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l('releaseAck')),
                        value: _releaseChecked,
                        onChanged: _busy
                            ? null
                            : (v) =>
                                  setState(() => _releaseChecked = v == true),
                      ),
                      FilledButton(
                        onPressed: _busy || _error || !_releaseChecked
                            ? null
                            : () => _command('release', {
                                'version': _encounter.version,
                                'recipientId': _encounter.record.patient.userId,
                                'releaseAcknowledgement': true,
                              }),
                        child: Text(l('release')),
                      ),
                    ],
                    const Divider(height: 32),
                    if (widget.onDone != null)
                      TextButton(
                        onPressed: _busy ? null : widget.onDone,
                        child: Text(l('done')),
                      ),
                    TextField(
                      controller: _reason,
                      enabled: !_busy,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: InputDecoration(labelText: l('amendReason')),
                      onChanged: (_) => setState(() {}),
                    ),
                    OutlinedButton(
                      onPressed:
                          _busy || _error || _reason.text.trim().length < 5
                          ? null
                          : () => _command('amend', {
                              'reason': _reason.text.trim(),
                            }),
                      child: Text(l('amend')),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}
