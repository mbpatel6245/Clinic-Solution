import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/app_role.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../services/session_controller.dart';
import '../../../ui/views/home/revamp/clinical_workspaces.dart';
import '../data/firebase_clinical_artifact_repository.dart';
import '../domain/clinical_artifact.dart';
import '../domain/clinical_draft_repository.dart';
import 'clinical_artifact_document.dart';

import 'clinical_artifact_editor.dart';
import 'clinical_artifact_labels.dart';
import 'clinical_artifact_review.dart';
import 'clinical_components.dart';

/// The managed pilot keeps existing clinic workflows available during migration.
class ClinicalArtifactWorkspace extends StatefulWidget {
  const ClinicalArtifactWorkspace({
    super.key,
    required this.care,
    this.patient,
  });
  final bool care;
  final PatientModel? patient;
  @override
  State<ClinicalArtifactWorkspace> createState() =>
      _ClinicalArtifactWorkspaceState();
}

class _ClinicalArtifactWorkspaceState extends State<ClinicalArtifactWorkspace> {
  late final SessionController _session = context.read<SessionController>();
  late final String _clinic = _session.activeClinicId;
  late final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _repository = FirebaseClinicalArtifactRepository(_clinic);
  final _identity = ValueNotifier<String?>(null);
  StreamSubscription<User?>? _auth;
  late final Listenable _changes = Listenable.merge([_session, _identity]);
  PatientModel? _patient;
  String? _selectedId;
  bool _busy = false, _error = false;
  bool get _allowed =>
      mounted &&
      _uid != null &&
      FirebaseAuth.instance.currentUser?.uid == _uid &&
      !_session.isLoading &&
      _session.activeClinicId == _clinic &&
      _session.roles.contains(AppRole.doctor) &&
      _session.clinicalArtifactsV1 &&
      _session.can(AppFeature.createPrescription) &&
      (widget.care || _session.can(AppFeature.laboratory));
  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _auth = FirebaseAuth.instance.authStateChanges().listen(
      (user) => _identity.value = user?.uid,
    );
  }

  String _scope(ClinicalArtifactKind kind, ClinicalArtifact? initial) =>
      ClinicalDraftIdentity(
        project: Firebase.app().options.projectId,
        user: _uid!,
        clinic: _clinic,
        patient: _patient!.id,
        encounter: 'artifact-${kind.name}-${initial?.id ?? 'new'}',
      ).scope;
  Future<void> _edit(
    ClinicalArtifactKind kind, [
    ClinicalArtifact? initial,
  ]) async {
    if (!_allowed || _patient == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ClinicalArtifactEditor(
          patient: _patient!,
          kind: kind,
          repository: _repository,
          scope: _scope(kind, initial),
          timezone: _session.clinicTimezone,
          authorized: () => _allowed,
          changes: _changes,
          sharingEnabled: () => _session.shareClinicalArtifactsWithPatients,
          initial: initial,
        ),
      ),
    );
  }

  Future<void> _open(ClinicalArtifact item) async {
    if (!_allowed || _busy) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final value = await _repository.load(item.id);
      if (!mounted || !_allowed || value.patient.id != _patient?.id) return;
      if (value.state == 'draft') {
        await _edit(value.kind, value);
        return;
      }
      final draft = await Navigator.of(context).push<ClinicalArtifact>(
        MaterialPageRoute(
          builder: (_) => ClinicalArtifactReviewScreen(
            initial: value,
            repository: _repository,
            authorized: () => _allowed,
            changes: _changes,
            sharingEnabled: () => _session.shareClinicalArtifactsWithPatients,
          ),
        ),
      );
      if (_allowed && draft?.state == 'draft') await _edit(draft!.kind, draft);
    } catch (_) {
      if (_allowed) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_auth?.cancel());
    _identity.dispose();
    _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) {
      final l = ArtifactLabels.of(context), c = ClinicalLabels.of(context);
      if (!_allowed) return Center(child: Text(c('remoteError')));
      return Theme(
        data: UviloTheme.light,
        child: Scaffold(
          backgroundColor: UviloTheme.canvas,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l(widget.care ? 'care' : 'labs'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    if (widget.patient == null)
                      ClinicalCard(
                        title: l('choosePatient'),
                        child: WorkflowPatientPicker(
                          key: ValueKey((_clinic, _uid)),
                          onSelected: (value) =>
                              setState(() => _patient = value),
                        ),
                      ),
                    if (_patient != null) ...[
                      const SizedBox(height: 20),
                      ClinicalPatientBanner(patient: _patient!),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final kind
                              in widget.care
                                  ? [ClinicalArtifactKind.carePlan]
                                  : [
                                      ClinicalArtifactKind.labOrder,
                                      ClinicalArtifactKind.labResult,
                                    ])
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _edit(kind),
                              icon: const Icon(Icons.add),
                              label: Text(
                                l(switch (kind) {
                                  ClinicalArtifactKind.labOrder => 'newOrder',
                                  ClinicalArtifactKind.labResult => 'newResult',
                                  ClinicalArtifactKind.carePlan => 'newCare',
                                }),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_busy) const LinearProgressIndicator(),
                      if (_error) Text(c('remoteError')),
                      StreamBuilder<List<ClinicalArtifact>>(
                        key: ValueKey((_clinic, _uid, _patient!.id)),
                        stream: _repository.watch(patientId: _patient!.id),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return ClinicalCard(
                              title: c('remoteError'),
                              child: Text(l('sourcesUnavailable')),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final items =
                              snapshot.data!
                                  .where(
                                    (a) => widget.care
                                        ? a.kind ==
                                              ClinicalArtifactKind.carePlan
                                        : a.kind !=
                                              ClinicalArtifactKind.carePlan,
                                  )
                                  .toList()
                                ..sort(
                                  (a, b) => (b.issuedAt ?? DateTime(1970))
                                      .compareTo(a.issuedAt ?? DateTime(1970)),
                                );
                          if (items.isEmpty) {
                            return ClinicalArtifactList(
                              items: items,
                              onOpen: _open,
                            );
                          }
                          final selected =
                              items
                                  .where((item) => item.id == _selectedId)
                                  .firstOrNull ??
                              items.first;
                          return LayoutBuilder(
                            builder: (context, box) => box.maxWidth < 1050
                                ? ClinicalArtifactList(
                                    items: items,
                                    onOpen: _open,
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 340,
                                        child: ClinicalArtifactList(
                                          items: items,
                                          onOpen: (item) => setState(
                                            () => _selectedId = item.id,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            ClinicalArtifactDocument(
                                              artifact: selected,
                                            ),
                                            const SizedBox(height: 12),
                                            OutlinedButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _open(selected),
                                              child: Text(l('openReview')),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    ClinicalCard(
                      title: l('legacy'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l('legacyHint')),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ListenableBuilder(
                                  listenable: _changes,
                                  builder: (context, _) => _allowed
                                      ? (widget.care
                                            ? TreatmentPlansScreen(
                                                patient: _patient,
                                                legacy: true,
                                              )
                                            : const LaboratoryScreen(
                                                legacy: true,
                                              ))
                                      : Scaffold(
                                          appBar: AppBar(),
                                          body: Center(
                                            child: Text(c('remoteError')),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            child: Text(l('legacy')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Cached rows are navigation hints. Review always reloads the authoritative copy.
class ClinicalArtifactList extends StatelessWidget {
  const ClinicalArtifactList({
    super.key,
    required this.items,
    required this.onOpen,
  });
  final List<ClinicalArtifact> items;
  final ValueChanged<ClinicalArtifact> onOpen;
  @override
  Widget build(BuildContext context) {
    final l = ArtifactLabels.of(context);
    return ClinicalCard(
      title: l('documents'),
      icon: '4_19096_imgFileText.svg',
      child: items.isEmpty
          ? Text(l('empty'))
          : Column(
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text(
                      '${l(item.kind.name)} · ${l(item.state)}${item.orderStatus.isEmpty ? '' : ' · ${l(item.orderStatus)}'} · ${l('version')} ${item.version}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpen(item),
                  ),
              ],
            ),
    );
  }
}
