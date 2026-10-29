import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'phase2_preview.dart';

/// CI-only native renderer check with synthetic data and no Firebase access.
void main() {
  var failed = false;
  FlutterError.onError = (details) {
    failed = true;
    FlutterError.presentError(details);
  };
  runApp(const Phase2Preview(initialDestination: 'dashboard'));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Timer(const Duration(seconds: 3), () {
      stdout.writeln(
        failed ? 'PHASE2_NATIVE_RENDER_FAILED' : 'PHASE2_NATIVE_RENDER_OK',
      );
      exit(failed ? 1 : 0);
    });
  });
}
