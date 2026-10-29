import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/features/patients/domain/patient_directory.dart';

void main() {
  final records = [
    for (var i = 0; i < 19; i++)
      PatientModel(
        id: 'p${i.toString().padLeft(2, '0')}',
        firstName: 'Patient',
        lastName: 'Example',
        phone: '+91 90000 00123',
      ),
  ];
  test('stable pagination clamps deleted pages without duplicating rows', () {
    final first = patientDirectoryPage(records),
        second = patientDirectoryPage(records, page: 1);
    expect(first.items.length, 8);
    expect(second.items.length, 8);
    expect(
      {
        ...first.items.map((p) => p.id),
        ...second.items.map((p) => p.id),
      }.length,
      16,
    );
    expect(patientDirectoryPage(records.take(2).toList(), page: 2).page, 0);
  });
  test('search accepts stable patient IDs and formatted phone numbers', () {
    expect(patientDirectoryPage(records, search: 'p08').items.single.id, 'p08');
    expect(patientDirectoryPage(records, search: '90000 00123').total, 19);
    expect(patientDirectoryPage(records, search: 'absent').total, 0);
  });
  test('duplicate candidates do not merge shared-family contacts', () {
    final draft = PatientModel(
      id: 'new',
      firstName: 'Another person',
      phone: '+919000000123',
    );
    expect(registrationCandidates(draft, records).length, 19);
    expect(records.length, 19);
  });
}
