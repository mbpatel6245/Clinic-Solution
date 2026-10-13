import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/core/utils/module_record_path.dart';

void main() {
  test(
    'cleanup includes only direct records of the selected clinic module',
    () {
      expect(
        isClinicModuleRecordPath('clinics/a/patients/p1', 'patients'),
        isTrue,
      );
      expect(
        isClinicModuleRecordPath('clinics/b/patients/p2', 'patients'),
        isTrue,
      );
      for (final path in [
        'patients/legacy',
        'archive/a/patients/p1',
        'clinics/a/archive/x/patients/p1',
        'clinics/a/invoices/i1',
        'clinics//patients/p1',
        'clinics/a/patients/',
      ]) {
        expect(
          isClinicModuleRecordPath(path, 'patients'),
          isFalse,
          reason: path,
        );
      }
    },
  );
}
