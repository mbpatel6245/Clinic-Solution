import 'dart:io';
import 'package:flutter/material.dart';
import 'package:clinic_solution/features/clinical/domain/clinical_artifact.dart';
import 'clinical_artifacts_preview.dart';

/// Native renderer qualification with synthetic data and no Firebase services.
Future<void> main() async {
  var failed = false;
  FlutterError.onError = (details) {
    failed = true;
    FlutterError.presentError(details);
  };
  for (final kind in ClinicalArtifactKind.values) {
    for (final editor in [false, true]) {
      runApp(
        ClinicalArtifactsPreview(
          key: ValueKey((kind, editor)),
          kind: kind,
          editor: editor,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
  stdout.writeln(
    failed
        ? 'CLINICAL_ARTIFACTS_RENDER_FAILED'
        : 'CLINICAL_ARTIFACTS_RENDER_OK',
  );
  exit(failed ? 1 : 0);
}
