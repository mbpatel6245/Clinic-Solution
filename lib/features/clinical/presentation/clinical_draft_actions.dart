import 'package:flutter/material.dart';
import '../data/encrypted_clinical_draft_repository.dart';
import '../domain/clinical_draft_repository.dart';
import 'clinical_components.dart';

/// Explicit device-local recovery, independent from Firestore's write queue.
/// The caller supplies an authenticated, patient/encounter-specific scope.
class ClinicalDraftActions extends StatefulWidget {
  const ClinicalDraftActions({
    super.key,
    required this.scope,
    required this.authorized,
    required this.capture,
    required this.restore,
    this.repositoryFactory,
    this.canSave = true,
  });
  final String scope;
  final bool Function() authorized;
  final Map<String, Object?> Function() capture;
  final void Function(Map<String, Object?>) restore;
  final ClinicalDraftRepository Function()? repositoryFactory;
  final bool canSave;
  @override
  State<ClinicalDraftActions> createState() => _ClinicalDraftActionsState();
}

class _ClinicalDraftActionsState extends State<ClinicalDraftActions> {
  int _revision = 0;
  bool _busy = false;
  Future<void> _discard() async {
    if (_busy || !widget.authorized()) return;
    final l = ClinicalLabels.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l('discard')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true || !widget.authorized()) return;
    setState(() => _busy = true);
    ClinicalDraftRepository? repository;
    try {
      repository =
          widget.repositoryFactory?.call() ??
          EncryptedClinicalDraftRepository.open(widget.scope);
      await repository.remove(_revision);
      _revision = 0;
    } catch (_) {
      if (mounted && widget.authorized()) _message(l('localError'));
    } finally {
      await repository?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(bool restore) async {
    if (_busy || !widget.authorized()) return;
    final l = ClinicalLabels.of(context), password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l(restore ? 'localRestore' : 'localSave')),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l('localHint')),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: l('password')),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    final secret = password.text;
    // The dialog may still be animating out with its text field attached.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    password.dispose();
    if (!mounted || accepted != true || !widget.authorized()) return;
    if (secret.length < 16) {
      _message(l('password'));
      return;
    }
    setState(() => _busy = true);
    ClinicalDraftRepository? store;
    try {
      store =
          widget.repositoryFactory?.call() ??
          EncryptedClinicalDraftRepository.open(widget.scope);
      if (restore) {
        final saved = await store.restore(secret);
        if (!mounted || !widget.authorized()) return;
        if (saved == null) throw StateError('No draft');
        widget.restore(saved.payload);
        _revision = saved.revision;
      } else {
        final snapshot = widget.capture();
        _revision = await store.save(
          snapshot,
          secret,
          expectedRevision: _revision,
        );
      }
      if (mounted && widget.authorized()) {
        _message(l(restore ? 'restored' : 'localDone'));
      }
    } catch (_) {
      if (mounted && widget.authorized()) _message(l('localError'));
    } finally {
      await store?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) {
    final l = ClinicalLabels.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _busy || !widget.canSave ? null : () => _run(false),
          icon: const Icon(Icons.lock_outline),
          label: Text(l('localSave')),
        ),
        TextButton.icon(
          onPressed: _busy ? null : () => _run(true),
          icon: const Icon(Icons.restore),
          label: Text(l('localRestore')),
        ),
        if (_revision > 0)
          TextButton.icon(
            onPressed: _busy ? null : _discard,
            icon: const Icon(Icons.delete_outline),
            label: Text(l('discard')),
          ),
        if (_busy)
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
