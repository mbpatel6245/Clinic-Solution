import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _dateTimeFrom(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final parts = value.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
  }
  return null;
}

double _doubleFrom(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class PatientModel {
  const PatientModel({
    this.id = '',
    required this.firstName,
    this.middleName = '',
    this.lastName = '',
    this.gender = '',
    this.phone = '',
    this.address = '',
    this.age,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String gender;
  final String phone;
  final String address;
  final int? age;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName => [
    firstName,
    middleName,
    lastName,
  ].where((part) => part.trim().isNotEmpty).join(' ');

  factory PatientModel.fromMap(Map<String, dynamic> data, String id) {
    return PatientModel(
      id: id,
      firstName: data['first_name']?.toString() ?? '',
      middleName: data['middle_name']?.toString() ?? '',
      lastName: data['last_name']?.toString() ?? '',
      gender: data['gender']?.toString() ?? '',
      phone: data['phone']?.toString() ?? data['mobile']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      age: int.tryParse(data['age']?.toString() ?? ''),
      createdAt: _dateTimeFrom(data['created_at']),
      updatedAt: _dateTimeFrom(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'first_name': firstName.trim(),
    'middle_name': middleName.trim(),
    'last_name': lastName.trim(),
    'full_name_search': fullName.toLowerCase(),
    'gender': gender,
    'phone': phone.trim(),
    'address': address.trim(),
    'age': age,
    'created_at': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

class MedicineLine {
  const MedicineLine({
    this.name = '',
    this.dosage = '',
    this.frequency = '',
    this.duration = '',
    this.instructions = '',
  });

  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String instructions;

  bool get isEmpty => name.trim().isEmpty;

  factory MedicineLine.fromMap(Map<String, dynamic> data) => MedicineLine(
    name: data['name']?.toString() ?? '',
    dosage: data['dosage']?.toString() ?? '',
    frequency: data['frequency']?.toString() ?? '',
    duration: data['duration']?.toString() ?? '',
    instructions: data['instructions']?.toString() ?? '',
  );

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'dosage': dosage.trim(),
    'frequency': frequency.trim(),
    'duration': duration.trim(),
    'instructions': instructions.trim(),
  };
}

class PrescriptionModel {
  const PrescriptionModel({
    this.id = '',
    required this.patient,
    this.diagnoses = const [],
    this.complaints = '',
    this.vitals = '',
    this.investigation = '',
    this.advice = '',
    this.medicines = const [],
    this.status = 'pending',
    this.visitDate,
    this.followUpDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final PatientModel patient;
  final List<String> diagnoses;
  final String complaints;
  final String vitals;
  final String investigation;
  final String advice;
  final List<MedicineLine> medicines;
  final String status;
  final DateTime? visitDate;
  final DateTime? followUpDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DateTime get visitTimestamp => createdAt ?? visitDate ?? DateTime.now();

  bool canStartNewVisitAt(DateTime now) =>
      now.difference(visitTimestamp) >= const Duration(hours: 4);

  factory PrescriptionModel.fromMap(Map<String, dynamic> data, String id) {
    final patientData = data['patient'] is Map
        ? Map<String, dynamic>.from(data['patient'] as Map)
        : <String, dynamic>{
            'first_name': data['first_name'],
            'middle_name': data['middle_name'],
            'last_name': data['last_name'] ?? data['surname'],
            'phone': data['phone'] ?? data['mobile'],
            'address': data['address'],
            'age': data['age'],
          };
    final medicineData = data['medicines'];
    return PrescriptionModel(
      id: id,
      patient: PatientModel.fromMap(
        patientData,
        data['patient_id']?.toString() ?? '',
      ),
      diagnoses:
          (data['diagnoses'] as Iterable?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      complaints: data['complaints']?.toString() ?? '',
      vitals: data['vitals']?.toString() ?? '',
      investigation: data['investigation']?.toString() ?? '',
      advice: data['advice']?.toString() ?? '',
      medicines: medicineData is Iterable
          ? medicineData
                .whereType<Map>()
                .map(
                  (item) =>
                      MedicineLine.fromMap(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      status: data['status']?.toString() ?? 'pending',
      visitDate: _dateTimeFrom(data['visit_date']),
      followUpDate: _dateTimeFrom(data['follow_up_date']),
      createdAt: _dateTimeFrom(data['created_at']),
      updatedAt: _dateTimeFrom(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap(String patientId) => {
    'patient_id': patientId,
    'patient': patient.toMap()
      ..remove('created_at')
      ..remove('updated_at'),
    'patient_name_search': patient.fullName.toLowerCase(),
    'patient_phone_search': patient.phone.toLowerCase(),
    'diagnoses': diagnoses,
    'complaints': complaints.trim(),
    'vitals': vitals.trim(),
    'investigation': investigation.trim(),
    'advice': advice.trim(),
    'medicines': medicines
        .where((medicine) => !medicine.isEmpty)
        .map((medicine) => medicine.toMap())
        .toList(),
    'status': status,
    'visit_date': Timestamp.fromDate(visitDate ?? DateTime.now()),
    'follow_up_date': followUpDate == null
        ? null
        : Timestamp.fromDate(followUpDate!),
    'created_at': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

class AppointmentModel {
  const AppointmentModel({
    this.id = '',
    required this.patientName,
    required this.phone,
    required this.scheduledAt,
    this.patientId = '',
    this.reason = '',
    this.notes = '',
    this.status = 'booked',
    this.createdBy = '',
    this.createdAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String phone;
  final DateTime scheduledAt;
  final String reason;
  final String notes;
  final String status;
  final String createdBy;
  final DateTime? createdAt;

  factory AppointmentModel.fromMap(Map<String, dynamic> data, String id) {
    return AppointmentModel(
      id: id,
      patientId: data['patient_id']?.toString() ?? '',
      patientName: data['patient_name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      scheduledAt: _dateTimeFrom(data['scheduled_at']) ?? DateTime.now(),
      reason: data['reason']?.toString() ?? '',
      notes: data['notes']?.toString() ?? '',
      status: data['status']?.toString() ?? 'booked',
      createdBy: data['created_by']?.toString() ?? '',
      createdAt: _dateTimeFrom(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'patient_id': patientId,
    'patient_name': patientName.trim(),
    'patient_name_search': patientName.toLowerCase().trim(),
    'phone': phone.trim(),
    'scheduled_at': Timestamp.fromDate(scheduledAt),
    'reason': reason.trim(),
    'notes': notes.trim(),
    'status': status,
    'created_by': createdBy,
    'created_at': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'updated_at': FieldValue.serverTimestamp(),
  };

  AppointmentModel copyWith({String? status}) => AppointmentModel(
    id: id,
    patientId: patientId,
    patientName: patientName,
    phone: phone,
    scheduledAt: scheduledAt,
    reason: reason,
    notes: notes,
    status: status ?? this.status,
    createdBy: createdBy,
    createdAt: createdAt,
  );
}

class InventoryItem {
  const InventoryItem({
    this.id = '',
    required this.name,
    required this.invoiceNumber,
    required this.quantityIn,
    required this.remainingQuantity,
    this.unit = 'units',
    this.batchNumber = '',
    this.supplier = '',
    this.manufacturer = '',
    this.purchaseRate = 0,
    this.mrp = 0,
    this.minimumLevel = 0,
    this.purchaseDate,
    this.expiryDate,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String invoiceNumber;
  final String batchNumber;
  final String supplier;
  final String manufacturer;
  final double quantityIn;
  final double remainingQuantity;
  final String unit;
  final double purchaseRate;
  final double mrp;
  final double minimumLevel;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get usedQuantity =>
      (quantityIn - remainingQuantity).clamp(0, double.infinity).toDouble();
  bool get isLowStock => remainingQuantity <= minimumLevel;
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get expiresSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.isBefore(DateTime.now().add(const Duration(days: 60)));

  factory InventoryItem.fromMap(Map<String, dynamic> data, String id) {
    final quantity = _doubleFrom(
      data['quantity_in'] ?? data['quantity_medicine'] ?? data['quantity'],
    );
    return InventoryItem(
      id: id,
      name:
          data['name']?.toString() ??
          data['brand_name']?.toString() ??
          data['short_name']?.toString() ??
          '',
      invoiceNumber:
          data['invoice_number']?.toString() ??
          data['bill_number']?.toString() ??
          '',
      batchNumber: data['batch_number']?.toString() ?? '',
      supplier:
          data['supplier']?.toString() ??
          data['purchasing_person']?.toString() ??
          '',
      manufacturer:
          data['manufacturer']?.toString() ??
          data['manufacturer_name']?.toString() ??
          '',
      quantityIn: quantity,
      remainingQuantity: data.containsKey('remaining_quantity')
          ? _doubleFrom(data['remaining_quantity'])
          : quantity,
      unit: data['unit']?.toString() ?? 'units',
      purchaseRate: _doubleFrom(
        data['purchase_rate'] ?? data['rate_of_purchase'],
      ),
      mrp: _doubleFrom(data['mrp']),
      minimumLevel: _doubleFrom(
        data['minimum_level'] ?? data['minimum_availability'],
      ),
      purchaseDate: _dateTimeFrom(
        data['purchase_date'] ?? data['date_of_purchase'],
      ),
      expiryDate: _dateTimeFrom(data['expiry_date']),
      notes: data['notes']?.toString() ?? '',
      createdAt: _dateTimeFrom(data['created_at']),
      updatedAt: _dateTimeFrom(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'name_search': name.toLowerCase().trim(),
    'invoice_number': invoiceNumber.trim(),
    'batch_number': batchNumber.trim(),
    'supplier': supplier.trim(),
    'manufacturer': manufacturer.trim(),
    'quantity_in': quantityIn,
    'remaining_quantity': remainingQuantity,
    'unit': unit,
    'purchase_rate': purchaseRate,
    'mrp': mrp,
    'minimum_level': minimumLevel,
    'purchase_date': purchaseDate == null
        ? null
        : Timestamp.fromDate(purchaseDate!),
    'expiry_date': expiryDate == null ? null : Timestamp.fromDate(expiryDate!),
    'notes': notes.trim(),
    'created_at': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'updated_at': FieldValue.serverTimestamp(),
  };

  InventoryItem copyWith({double? remainingQuantity}) => InventoryItem(
    id: id,
    name: name,
    invoiceNumber: invoiceNumber,
    quantityIn: quantityIn,
    remainingQuantity: remainingQuantity ?? this.remainingQuantity,
    unit: unit,
    batchNumber: batchNumber,
    supplier: supplier,
    manufacturer: manufacturer,
    purchaseRate: purchaseRate,
    mrp: mrp,
    minimumLevel: minimumLevel,
    purchaseDate: purchaseDate,
    expiryDate: expiryDate,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

enum FinanceEntryType {
  income,
  expense;

  static FinanceEntryType fromValue(dynamic value) =>
      value?.toString().toLowerCase() == 'expense'
      ? FinanceEntryType.expense
      : FinanceEntryType.income;
}

class FinanceEntry {
  const FinanceEntry({
    this.id = '',
    required this.type,
    required this.amount,
    required this.category,
    required this.occurredAt,
    this.description = '',
    this.paymentMethod = 'cash',
    this.createdBy = '',
    this.createdAt,
  });

  final String id;
  final FinanceEntryType type;
  final double amount;
  final String category;
  final DateTime occurredAt;
  final String description;
  final String paymentMethod;
  final String createdBy;
  final DateTime? createdAt;

  factory FinanceEntry.fromMap(Map<String, dynamic> data, String id) =>
      FinanceEntry(
        id: id,
        type: FinanceEntryType.fromValue(data['type']),
        amount: _doubleFrom(data['amount']),
        category: data['category']?.toString() ?? '',
        occurredAt: _dateTimeFrom(data['occurred_at']) ?? DateTime.now(),
        description: data['description']?.toString() ?? '',
        paymentMethod: data['payment_method']?.toString() ?? 'cash',
        createdBy: data['created_by']?.toString() ?? '',
        createdAt: _dateTimeFrom(data['created_at']),
      );

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'amount': amount,
    'category': category.trim(),
    'occurred_at': Timestamp.fromDate(occurredAt),
    'description': description.trim(),
    'payment_method': paymentMethod,
    'created_by': createdBy,
    'created_at': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'updated_at': FieldValue.serverTimestamp(),
  };
}
