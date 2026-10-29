import 'package:flutter/material.dart';
import '../../../shared/presentation/guarded_dialog_content.dart';
import 'package:intl/intl.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../ui/widgets/app_design.dart';
import '../domain/patient_directory.dart';
import 'patient_labels.dart';

class RegistrationReview extends StatefulWidget {
  const RegistrationReview({
    super.key,
    required this.patient,
    required this.patients,
    this.authorizationChanges,
    this.isAuthorized,
  });
  final PatientModel patient;
  final Stream<List<PatientModel>> patients;
  final Listenable? authorizationChanges;
  final bool Function()? isAuthorized;
  @override
  State<RegistrationReview> createState() => _RegistrationReviewState();
}

class _RegistrationReviewState extends State<RegistrationReview> {
  bool _reviewed = false, _separate = false, _care = false;
  @override
  Widget build(BuildContext context) {
    final l = PatientLabels.of(context), p = widget.patient;
    return GuardedDialogContent(
      message: l('scopeChanged'),
      changes: widget.authorizationChanges,
      isAuthorized: widget.isAuthorized,
      child: Theme(
        data: UviloTheme.light,
        child: Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: StreamBuilder<List<PatientModel>>(
                stream: widget.patients,
                builder: (context, snapshot) {
                  final matches = registrationCandidates(
                    p,
                    snapshot.data ?? [],
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l('review'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(l('reviewHint')),
                      const SizedBox(height: 24),
                      AppSection(
                        title: p.fullName,
                        child: Wrap(
                          spacing: 32,
                          runSpacing: 12,
                          children: [
                            Text('${p.phone}\n${p.email ?? ''}'),
                            Text(
                              '${p.gender}\n${p.dateOfBirth == null ? '—' : DateFormat.yMMMd().format(p.dateOfBirth!)}',
                            ),
                            Text(p.address),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppSection(
                        title: l('possibleMatch'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l('matchHint')),
                            const SizedBox(height: 12),
                            if (snapshot.hasError)
                              Text(l('loadError'))
                            else if (!snapshot.hasData)
                              const LinearProgressIndicator()
                            else if (matches.isEmpty)
                              Text(l('none'))
                            else
                              for (final match in matches)
                                ListTile(
                                  title: Text(match.fullName),
                                  subtitle: Text(
                                    '${match.id} · ${match.phone}',
                                  ),
                                ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _reviewed,
                              onChanged: (v) =>
                                  setState(() => _reviewed = v ?? false),
                              title: Text(l('reviewed')),
                            ),
                            if (matches.isNotEmpty)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _separate,
                                onChanged: (v) =>
                                    setState(() => _separate = v ?? false),
                                title: Text(l('separate')),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppSection(
                        title: l('consent'),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _care,
                              onChanged: (v) =>
                                  setState(() => _care = v ?? false),
                              title: Text(l('careConsent')),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l('reminder')),
                              subtitle: Text(
                                l(
                                  p.notificationConsent == true
                                      ? 'yes'
                                      : 'unknown',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(l('edit')),
                          ),
                          FilledButton(
                            onPressed:
                                snapshot.hasData &&
                                    !snapshot.hasError &&
                                    _reviewed &&
                                    _care &&
                                    (matches.isEmpty || _separate)
                                ? () => Navigator.pop(context, true)
                                : null,
                            child: Text(l('confirm')),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
