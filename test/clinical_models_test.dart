import 'package:clinic_solution/data/datasources/clinical_models.dart';
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
}
