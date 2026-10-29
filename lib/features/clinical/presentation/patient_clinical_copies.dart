import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/design/uvilo_theme.dart';
import '../data/patient_clinical_artifacts.dart';
import 'clinical_artifact_document.dart';
import 'clinical_artifact_labels.dart';
import 'clinical_artifact_pdf.dart';
import 'clinical_components.dart';

class PatientClinicalCopies extends StatefulWidget {
  const PatientClinicalCopies({super.key, required this.userId});
  final String userId;
  @override
  State<PatientClinicalCopies> createState() => _PatientClinicalCopiesState();
}

class _PatientClinicalCopiesState extends State<PatientClinicalCopies> {
  late final _stream = patientClinicalArtifacts(widget.userId);
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<PatientClinicalCopy>>(
    stream: _stream,
    builder: (context, snapshot) {
      final l = ArtifactLabels.of(context), c = ClinicalLabels.of(context);
      return ClinicalCard(
        title: l('patientCopies'),
        child: snapshot.hasError
            ? Text(c('remoteError'))
            : !snapshot.hasData
            ? const Center(child: CircularProgressIndicator())
            : snapshot.data!.isEmpty
            ? Text(l('empty'))
            : Column(
                children: [
                  for (final copy in snapshot.data!)
                    ListTile(
                      title: Text(copy.artifact.title),
                      subtitle: Text(
                        '${(copy.artifact.context['clinic'] as Map?)?['name']} · ${l(copy.artifact.kind.name)} · ${l('version')} ${copy.artifact.version}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => _PatientCopyView(
                            userId: widget.userId,
                            initial: copy,
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

class _PatientCopyView extends StatefulWidget {
  const _PatientCopyView({required this.userId, required this.initial});
  final String userId;
  final PatientClinicalCopy initial;
  @override
  State<_PatientCopyView> createState() => _PatientCopyViewState();
}

class _PatientCopyViewState extends State<_PatientCopyView> {
  late final stream = patientClinicalArtifacts(widget.userId);
  PatientClinicalCopy? _current;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<PatientClinicalCopy>>(
    stream: stream,
    builder: (context, snapshot) {
      // No initialData: a released copy must be re-observed before displaying it.
      final copy =
          snapshot.hasError ||
              FirebaseAuth.instance.currentUser?.uid != widget.userId
          ? null
          : snapshot.data
                ?.where(
                  (v) =>
                      v.clinicId == widget.initial.clinicId &&
                      v.artifact.id == widget.initial.artifact.id,
                )
                .firstOrNull;
      _current = copy;
      final c = ClinicalLabels.of(context);
      return Theme(
        data: UviloTheme.light,
        child: Scaffold(
          appBar: AppBar(
            title: Text(ArtifactLabels.of(context)('patientCopies')),
          ),
          body: copy == null
              ? Center(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const CircularProgressIndicator()
                      : Text(c('remoteError')),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClinicalPatientBanner(patient: copy.artifact.patient),
                          const SizedBox(height: 20),
                          ClinicalArtifactDocument(artifact: copy.artifact),
                          const SizedBox(height: 20),
                          ExpansionTile(
                            title: Text(c('print')),
                            children: [
                              SizedBox(
                                height: 600,
                                child: PdfPreview(
                                  key: ValueKey((
                                    copy.clinicId,
                                    copy.artifact.id,
                                    copy.artifact.version,
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode,
                                  )),
                                  canChangePageFormat: false,
                                  canChangeOrientation: false,
                                  build: (_) async {
                                    if (!mounted ||
                                        !identical(_current, copy) ||
                                        FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.uid !=
                                            widget.userId) {
                                      throw StateError('Access changed');
                                    }
                                    final bytes =
                                        await ClinicalArtifactPdf.build(
                                          copy.artifact,
                                          Localizations.localeOf(
                                            context,
                                          ).languageCode,
                                        );
                                    if (!mounted ||
                                        !identical(_current, copy) ||
                                        FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.uid !=
                                            widget.userId) {
                                      throw StateError('Access changed');
                                    }
                                    return bytes;
                                  },
                                ),
                              ),
                            ],
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
