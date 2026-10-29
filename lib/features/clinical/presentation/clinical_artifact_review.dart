import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../shared/presentation/guarded_dialog_content.dart';
import '../domain/clinical_artifact.dart';
import '../data/firebase_clinical_artifact_repository.dart';
import 'clinical_artifact_labels.dart';
import 'clinical_artifact_document.dart';
import 'clinical_artifact_pdf.dart';
import 'clinical_components.dart';

class ClinicalArtifactReviewScreen extends StatefulWidget {
  const ClinicalArtifactReviewScreen({
    super.key,
    required this.initial,
    required this.repository,
    required this.authorized,
    required this.changes,
    required this.sharingEnabled,
  });
  final ClinicalArtifact initial;
  final ClinicalArtifactRepository repository;
  final bool Function() authorized, sharingEnabled;
  final Listenable changes;
  @override
  State<ClinicalArtifactReviewScreen> createState() =>
      _ClinicalArtifactReviewScreenState();
}

class _ClinicalArtifactReviewScreenState
    extends State<ClinicalArtifactReviewScreen> {
  late ClinicalArtifact _artifact = widget.initial;
  final _checks = <int>{};
  final _operations = <String, Map<String, Object?>>{};
  bool _busy = false,
      _error = false,
      _release = false,
      _sharingUnverified = false;
  late bool _sharing = widget.sharingEnabled();
  String? _duplicate;
  bool get _allowed => mounted && widget.authorized();
  void _apply(ClinicalArtifact current) {
    if (current.id != widget.initial.id ||
        current.kind != widget.initial.kind ||
        current.patient.id != widget.initial.patient.id) {
      throw const ClinicalArtifactFailure('permission-denied');
    }
    _artifact = current;
    _checks.clear();
    _release = false;
    _error = false;
    _duplicate = null;
    _sharingUnverified = false;
  }

  Future<void> _reload() async {
    if (_busy || !_allowed) return;
    setState(() => _busy = true);
    try {
      final value = await widget.repository.load(_artifact.id);
      if (_allowed) setState(() => _apply(value));
    } catch (_) {
      if (_allowed) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mutate(
    String action, [
    Map<String, Object?> extra = const {},
  ]) async {
    if (_busy || !_allowed) return;
    final request = <String, Object?>{
      'action': action,
      'artifactId': _artifact.id,
      'artifactKind': _artifact.kind.name,
      'expectedRevision': _artifact.revision,
      ...extra,
    };
    final command = _operations.putIfAbsent(
      jsonEncode(request),
      () => {...request, 'operationId': widget.repository.newId()},
    );
    setState(() => _busy = true);
    try {
      await widget.repository.command(command);
      final value = await widget.repository.load(_artifact.id);
      if (!mounted || !_allowed) return;
      if (action == 'amend') {
        Navigator.pop(context, value);
        return;
      }
      setState(() => _apply(value));
    } catch (e) {
      if (_allowed) {
        setState(() {
          _error = true;
          _duplicate = e is ClinicalArtifactFailure
              ? e.details['existingId']?.toString()
              : null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reason(String action) async {
    if (!mounted || !_allowed || _busy) return;
    final l = ArtifactLabels.of(context),
        controller = TextEditingController(),
        form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => GuardedDialogContent(
        changes: widget.changes,
        isAuthorized: () => _allowed,
        message: ClinicalLabels.of(context)('remoteError'),
        child: AlertDialog(
          title: Text(
            action == 'amend'
                ? ClinicalLabels.of(context)('amend')
                : action == 'revoke'
                ? ClinicalLabels.of(context)('revoke')
                : l('cancelOrder'),
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: TextFormField(
                controller: controller,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(labelText: l('reason')),
                validator: (v) =>
                    (v?.trim().length ?? 0) >= 5 ? null : l('reason'),
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
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    final reason = controller.text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (!mounted || !_allowed || accepted != true) return;
    await _mutate(action, {
      'reason': reason,
      if (action == 'revoke') 'revokeAcknowledgement': true,
    });
  }

  Future<void> _collect() async {
    if (!mounted || !_allowed || _busy) return;
    var selected = DateTime.now(), confirmed = false;
    final l = ArtifactLabels.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => GuardedDialogContent(
        changes: widget.changes,
        isAuthorized: () => _allowed,
        message: ClinicalLabels.of(context)('remoteError'),
        child: StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: Text(l('collect')),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l('collectionPrecision')),
                    Text('${l('deviceTime')}: ${selected.timeZoneName}'),
                    TextButton.icon(
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        DateFormat.yMMMd(l.language).add_jm().format(selected),
                      ),
                      onPressed: () async {
                        final day = await showDatePicker(
                          context: dialogContext,
                          initialDate: selected,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (day == null ||
                            !dialogContext.mounted ||
                            !_allowed) {
                          return;
                        }
                        final time = await showTimePicker(
                          context: dialogContext,
                          initialTime: TimeOfDay.fromDateTime(selected),
                        );
                        if (time == null ||
                            !dialogContext.mounted ||
                            !_allowed) {
                          return;
                        }
                        setDialog(
                          () => selected = DateTime(
                            day.year,
                            day.month,
                            day.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l('collectAck')),
                      value: confirmed,
                      onChanged: (v) => setDialog(() => confirmed = v == true),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: confirmed
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: Text(l('collect')),
              ),
            ],
          ),
        ),
      ),
    );
    if (accepted == true && _allowed) {
      await _mutate('collect', {
        'collectionReviewed': true,
        'collectedAt': selected.toUtc().toIso8601String(),
      });
    }
  }

  Future<void> _existing() async {
    if (_duplicate == null || !_allowed || _busy) return;
    setState(() => _busy = true);
    try {
      final value = await widget.repository.load(_duplicate!);
      if (!mounted ||
          !_allowed ||
          value.patient.id != _artifact.patient.id ||
          value.kind != ClinicalArtifactKind.labOrder) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ClinicalArtifactReviewScreen(
            initial: value,
            repository: widget.repository,
            authorized: () => _allowed,
            changes: widget.changes,
            sharingEnabled: widget.sharingEnabled,
          ),
        ),
      );
    } catch (_) {
      if (_allowed) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _history() async {
    if (!mounted || !_allowed) return;
    final data = widget.repository.history(_artifact.id),
        versions = widget.repository.versions(_artifact.id),
        l = ArtifactLabels.of(context),
        c = ClinicalLabels.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => GuardedDialogContent(
        changes: widget.changes,
        isAuthorized: () => _allowed,
        message: c('remoteError'),
        child: AlertDialog(
          title: Text(l('history')),
          content: SizedBox(
            width: 500,
            height: 360,
            child:
                FutureBuilder<
                  (List<ClinicalArtifact>, List<Map<String, dynamic>>)
                >(
                  future: (() async => (await versions, await data))(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text(c('remoteError'));
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView(
                      children: [
                        Text(
                          l('versions'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        for (final version in snapshot.data!.$1)
                          ListTile(
                            title: Text('${l('version')} ${version.version}'),
                            subtitle: Text(version.title),
                            trailing: const Icon(Icons.print_outlined),
                            onTap: () => Navigator.of(dialogContext).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ClinicalArtifactPrintScreen(
                                  artifact: version,
                                  authorized: () => _allowed,
                                  changes: widget.changes,
                                ),
                              ),
                            ),
                          ),
                        const Divider(),
                        Text(
                          l('history'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        for (final event in snapshot.data!.$2)
                          ListTile(
                            title: Text(
                              '${c(event['action'] == 'revoke' ? 'revoke' : 'release')} · ${l('version')} ${event['version']}',
                            ),
                            subtitle: Text(
                              artifactDate(
                                    event['created_at'],
                                  )?.toLocal().toString() ??
                                  '—',
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.changes,
    builder: (context, _) {
      final l = ArtifactLabels.of(context), c = ClinicalLabels.of(context);
      if (!_allowed) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(c('remoteError'))),
        );
      }
      final sharing = widget.sharingEnabled();
      if (sharing != _sharing) {
        _sharing = sharing;
        _sharingUnverified = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_allowed && !_busy) _reload();
        });
      }
      final controls = ClinicalCard(
        title: l(
          _artifact.issued
              ? 'issued'
              : _artifact.state == 'cancelled'
              ? 'cancelled'
              : 'draft',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_artifact.kind == ClinicalArtifactKind.labOrder &&
                _artifact.orderStatus.isNotEmpty)
              Text(l(_artifact.orderStatus)),
            if (_artifact.state == 'draft') ...[
              for (var index = 0; index < 4; index++)
                CheckboxListTile(
                  key: ValueKey('artifact-review-$index'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    l(
                      [
                        'ackIdentity',
                        'ackContent',
                        'ackSource',
                        'ackFinal',
                      ][index],
                    ),
                  ),
                  value: _checks.contains(index),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          value == true
                              ? _checks.add(index)
                              : _checks.remove(index);
                        }),
                ),
              FilledButton.icon(
                key: const ValueKey('artifact-issue'),
                onPressed: _busy || _error || _checks.length != 4
                    ? null
                    : () => _mutate('issue', {
                        'identityReviewed': true,
                        'contentReviewed': true,
                        'sourceReviewed': true,
                        'finalAcknowledgement': true,
                      }),
                icon: const Icon(Icons.verified_outlined),
                label: Text(l('issue')),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.pop(context, _artifact),
                child: Text(
                  MaterialLocalizations.of(context).backButtonTooltip,
                ),
              ),
            ],
            if (_artifact.issued) ...[
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => ClinicalArtifactPrintScreen(
                            artifact: _artifact,
                            authorized: () => _allowed,
                            changes: widget.changes,
                          ),
                        ),
                      ),
                icon: const ClinicalArtifactIcon('4_19096_imgDownload.svg'),
                label: Text(c('print')),
              ),
              const SizedBox(height: 16),
              if (_artifact.releasedVersion > 0 && !_sharingUnverified) ...[
                Text(sharing ? c('released') : l('sharingDisabled')),
                TextButton(
                  onPressed: _busy || _error ? null : () => _reason('revoke'),
                  child: Text(c('revoke')),
                ),
              ] else if (sharing && _artifact.recipientId.isNotEmpty) ...[
                Text('${_artifact.patient.fullName} · ${_artifact.patient.id}'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l('releaseAck')),
                  value: _release,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _release = value == true),
                ),
                FilledButton.icon(
                  onPressed: _busy || _error || !_release || _sharingUnverified
                      ? null
                      : () => _mutate('release', {
                          'version': _artifact.version,
                          'recipientId': _artifact.recipientId,
                          'releaseAcknowledgement': true,
                        }),
                  icon: const ClinicalArtifactIcon('4_19096_imgShare2.svg'),
                  label: Text(c('release')),
                ),
              ] else
                Text(l('sharingDisabled')),
              const Divider(height: 28),
              if (_artifact.kind == ClinicalArtifactKind.labOrder &&
                  _artifact.orderStatus == 'ordered')
                OutlinedButton(
                  onPressed: _busy || _error ? null : _collect,
                  child: Text(l('collect')),
                ),
              if (_artifact.kind != ClinicalArtifactKind.labOrder)
                OutlinedButton(
                  onPressed: _busy || _error ? null : () => _reason('amend'),
                  child: Text(c('amend')),
                ),
            ],
            if (_artifact.kind == ClinicalArtifactKind.labOrder &&
                (_artifact.state == 'draft' && _artifact.version == 0 ||
                    _artifact.orderStatus == 'ordered'))
              TextButton(
                onPressed: _busy || _error ? null : () => _reason('cancel'),
                child: Text(l('cancelOrder')),
              ),
            if (_artifact.releasedVersion > 0 &&
                _artifact.state == 'draft') ...[
              Text(l('publishedVersion')),
              TextButton(
                onPressed: _busy || _error ? null : () => _reason('revoke'),
                child: Text(c('revoke')),
              ),
            ],
            if (_error)
              Text(_duplicate == null ? c('remoteError') : l('matchingOrder')),
            if (_error && _duplicate == null && _artifact.state == 'draft')
              Text(l('resaveHint')),
            if (_duplicate != null)
              TextButton(
                onPressed: _busy ? null : _existing,
                child: Text(l('viewExisting')),
              ),
            if (_error)
              TextButton(
                onPressed: _busy ? null : _reload,
                child: Text(c('reload')),
              ),
            if (_artifact.version > 0)
              TextButton(
                onPressed: _busy ? null : _history,
                child: Text(l('history')),
              ),
          ],
        ),
      );
      return Theme(
        data: UviloTheme.light,
        child: PopScope(
          canPop: !_busy,
          child: Scaffold(
            appBar: AppBar(title: Text(l(_artifact.kind.name))),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1250),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClinicalPatientBanner(
                        patient: _artifact.patient,
                        encounter: _artifact.encounterId,
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, box) => box.maxWidth >= 1000
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClinicalArtifactDocument(
                                      artifact: _artifact.issued
                                          ? _artifact.asPublished()
                                          : _artifact,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  SizedBox(width: 320, child: controls),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ClinicalArtifactDocument(
                                    artifact: _artifact.issued
                                        ? _artifact.asPublished()
                                        : _artifact,
                                  ),
                                  const SizedBox(height: 20),
                                  controls,
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
