import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryItem', () {
    test('reads legacy stock records and calculates availability', () {
      final item = InventoryItem.fromMap({
        'brand_name': 'Paracetamol',
        'bill_number': 'INV-10',
        'quantity_medicine': '25',
        'minimum_availability': '5',
        'expiry_date': '31-12-2027',
      }, 'stock-1');

      expect(item.name, 'Paracetamol');
      expect(item.invoiceNumber, 'INV-10');
      expect(item.quantityIn, 25);
      expect(item.remainingQuantity, 25);
      expect(item.isLowStock, isFalse);
      expect(item.expiryDate, DateTime(2027, 12, 31));
    });

    test('reports used and low stock quantities', () {
      const item = InventoryItem(
        name: 'Gloves',
        invoiceNumber: 'INV-11',
        quantityIn: 100,
        remainingQuantity: 8,
        minimumLevel: 10,
      );

      expect(item.usedQuantity, 92);
      expect(item.isLowStock, isTrue);
    });
  });

  test('PatientModel builds a searchable full name', () {
    const patient = PatientModel(
      firstName: 'Asha',
      middleName: 'R.',
      lastName: 'Patel',
    );

    expect(patient.fullName, 'Asha R. Patel');
  });

  test('PrescriptionModel reads structured medicine lines', () {
    final prescription = PrescriptionModel.fromMap({
      'patient_id': 'patient-1',
      'patient': {'first_name': 'Asha', 'phone': '9876543210'},
      'medicines': [
        {
          'name': 'Tablet A',
          'dosage': '500 mg',
          'frequency': 'Twice daily',
          'duration': '5 days',
        },
      ],
    }, 'rx-1');

    expect(prescription.patient.id, 'patient-1');
    expect(prescription.medicines.single.name, 'Tablet A');
    expect(prescription.medicines.single.duration, '5 days');
  });

  test('a new visit is offered only after four hours', () {
    final createdAt = DateTime(2026, 9, 11, 9);
    final prescription = PrescriptionModel(
      patient: const PatientModel(firstName: 'Asha'),
      createdAt: createdAt,
    );

    expect(
      prescription.canStartNewVisitAt(createdAt.add(const Duration(hours: 3))),
      isFalse,
    );
    expect(
      prescription.canStartNewVisitAt(createdAt.add(const Duration(hours: 4))),
      isTrue,
    );
  });

  test('AppointmentModel preserves the account that created it', () {
    final appointment = AppointmentModel.fromMap({
      'patient_name': 'Asha Patel',
      'phone': '9876543210',
      'scheduled_at': DateTime(2027, 1, 5),
      'created_by': 'patient-user-1',
    }, 'appointment-1');

    expect(appointment.createdBy, 'patient-user-1');
    expect(appointment.toMap()['created_by'], 'patient-user-1');
  });

  test('FinanceEntry reads income and expense records', () {
    final entry = FinanceEntry.fromMap({
      'type': 'expense',
      'amount': '1250.50',
      'category': 'Medicine purchase',
      'occurred_at': DateTime(2027, 1, 5),
    }, 'finance-1');

    expect(entry.type, FinanceEntryType.expense);
    expect(entry.amount, 1250.50);
    expect(entry.toMap()['type'], 'expense');
  });

  group('role permissions', () {
    test(
      'clinic admin can access clinic profile without module purchasing',
      () {
        expect(AppRole.platformOwner.features, containsAll(AppFeature.values));
        expect(AppRole.clinicAdmin.can(AppFeature.dashboard), isTrue);
        expect(AppRole.clinicAdmin.can(AppFeature.clinicSetup), isTrue);
        expect(
          AppRole.clinicAdmin.isAllowed(AppPermission.configureClinic),
          isFalse,
        );
      },
    );

    test('patient can book appointments without staff access', () {
      expect(AppRole.patient.can(AppFeature.appointments), isTrue);
      expect(AppRole.patient.can(AppFeature.finance), isFalse);
      expect(AppRole.patient.can(AppFeature.inventory), isFalse);
    });

    test('normalizes legacy and pharmacy role names', () {
      expect(AppRole.fromValue('User'), AppRole.patient);
      expect(AppRole.fromValue('Pharmacy Operator'), AppRole.pharmacyOperator);
      expect(AppRole.fromValue('Admin'), AppRole.clinicAdmin);
      expect(AppRole.fromValue('Clinic Owner'), AppRole.clinicAdmin);
      expect(AppRole.fromValue('Independent Doctor'), AppRole.doctor);
      expect(AppRole.fromValue('vaccination'), AppRole.vaccinator);
    });

    test('reception and pharmacy permissions stay separated', () {
      expect(AppRole.receptionist.can(AppFeature.reception), isTrue);
      expect(AppRole.receptionist.can(AppFeature.inventory), isFalse);
      expect(AppRole.pharmacyOperator.can(AppFeature.inventory), isTrue);
      expect(AppRole.pharmacyOperator.can(AppFeature.finance), isFalse);
    });
  });
}
