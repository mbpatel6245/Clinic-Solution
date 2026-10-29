import 'package:drift_flutter/drift_flutter.dart';
import 'clinic_database.dart';

/// Synthetic Phase 1 sandbox ONLY: encryption/key management is not integrated.
/// Separate filename prevents any access to legacy Firebase or real user caches.
ClinicDatabase openFoundationDatabase({
  String name = 'uvilo_foundation_synthetic_v1',
  void Function(String mode, bool durable)? onPersistence,
}) => ClinicDatabase(
  driftDatabase(
    name: name,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
      onResult: (result) {
        final mode = result.chosenImplementation.name;
        if (mode == 'unsafeIndexedDb') {
          throw StateError(
            'This browser cannot safely share persistent storage across tabs.',
          );
        }
        onPersistence?.call(mode, mode != 'inMemory');
      },
    ),
  ),
);
