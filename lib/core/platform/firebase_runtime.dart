import 'package:flutter/foundation.dart';

/// Platforms currently supported by the official FlutterFire plugins used by
/// this application.
abstract final class FirebaseRuntime {
  static bool get isSupported {
    if (kIsWeb) {
      return true;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.linux || TargetPlatform.fuchsia => false,
    };
  }

  static bool get supportsPersistentFirestoreCache {
    if (kIsWeb) {
      return true;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      TargetPlatform.linux ||
      TargetPlatform.windows ||
      TargetPlatform.fuchsia => false,
    };
  }
}
