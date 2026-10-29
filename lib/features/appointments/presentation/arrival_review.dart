import 'package:flutter/material.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../patients/presentation/patient_labels.dart';
import '../../../shared/presentation/guarded_dialog_content.dart';

Future<bool> reviewArrival(
  BuildContext context,
  AppointmentModel patient, {
  Listenable? changes,
  bool Function()? authorized,
}) async {
  final l = PatientLabels.of(context);
  bool name = false, contact = false, consent = false;
  return await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => GuardedDialogContent(
            changes: changes,
            isAuthorized: authorized,
            message: l('scopeChanged'),
            child: AlertDialog(
              title: Text(l('checkIn')),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(patient.patientName),
                        subtitle: Text(
                          '${patient.patientId} · ${patient.phone}',
                        ),
                      ),
                      CheckboxListTile(
                        title: Text(l('nameChecked')),
                        value: name,
                        onChanged: (v) => update(() => name = v ?? false),
                      ),
                      CheckboxListTile(
                        title: Text(l('contactChecked')),
                        value: contact,
                        onChanged: (v) => update(() => contact = v ?? false),
                      ),
                      CheckboxListTile(
                        title: Text(l('arrivalConsent')),
                        value: consent,
                        onChanged: (v) => update(() => consent = v ?? false),
                      ),
                      Text(l('arrivalHint')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l('cancel')),
                ),
                FilledButton(
                  onPressed: name && contact && consent
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(l('checkIn')),
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}
