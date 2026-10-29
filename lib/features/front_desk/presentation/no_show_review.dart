import 'package:flutter/material.dart';
import '../../../shared/presentation/guarded_dialog_content.dart';
import '../../patients/presentation/patient_labels.dart';
import 'front_desk_components.dart';

Future<String?> reviewNoShow(
  BuildContext context, {
  required Listenable changes,
  required bool Function() authorized,
}) async {
  final reason = TextEditingController();
  final l = PatientLabels.of(context), d = DeskLabels.of(context);
  bool checked = false;
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => GuardedDialogContent(
          changes: changes,
          isAuthorized: authorized,
          message: l('scopeChanged'),
          child: AlertDialog(
            title: Text(d('noShow')),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d('noShowHint')),
                    TextField(
                      controller: reason,
                      maxLength: 500,
                      decoration: InputDecoration(labelText: l('reason')),
                      onChanged: (_) => update(() {}),
                    ),
                    CheckboxListTile(
                      value: checked,
                      onChanged: (v) => update(() => checked = v ?? false),
                      title: Text(d('noShowConfirmed')),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: Text(l('cancel')),
              ),
              FilledButton(
                onPressed: checked && reason.text.trim().length >= 5
                    ? () => Navigator.pop(dialog, reason.text.trim())
                    : null,
                child: Text(d('noShow')),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    reason.dispose();
  }
}
