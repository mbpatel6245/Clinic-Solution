import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'phase3_preview.dart';

/// Native UI qualification only. No Firebase initialization or patient data.
Future<void> main() async {
  var failed = false;
  FlutterError.onError = (details) {
    failed = true;
    FlutterError.presentError(details);
  };
  for (final screen in ['record', 'consultation', 'final-review', 'signed']) {
    runApp(Phase3Preview(key: ValueKey(screen), screen: screen));
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  stdout.writeln(
    failed ? 'PHASE3_NATIVE_RENDER_FAILED' : 'PHASE3_NATIVE_RENDER_OK',
  );
  exit(failed ? 1 : 0);
}
