import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/auth/app_role.dart';

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

double _amount(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class ClinicProfile {
  const ClinicProfile({
    required this.id,
    required this.name,
    this.code = '',
    this.phone = '',
    this.address = '',
    this.currency = 'INR',
    this.timezone = 'Asia/Kolkata',
    this.enabledModules = const {},
    this.active = true,
  });

  final String id;
  final String name;
  final String code;
  final String phone;
  final String address;
  final String currency;
  final String timezone;
  final Set<ClinicModule> enabledModules;
  final bool active;

  static Set<ClinicModule> get defaultModules => {
    ClinicModule.patients,
    ClinicModule.appointments,
    ClinicModule.clinical,
    ClinicModule.billing,
    ClinicModule.expenses,
    ClinicModule.reports,
  };

  factory ClinicProfile.fromMap(Map<String, dynamic> data, String id) {
    final rawModules = (data['enabled_modules'] as Iterable?) ?? const [];
    final modules = rawModules
        .map((value) => ClinicModule.fromValue(value.toString()))
        .whereType<ClinicModule>()
        .toSet();
    return ClinicProfile(
      id: id,
      name: data['name']?.toString() ?? 'Clinic',
      code: data['code']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      currency: data['currency']?.toString() ?? 'INR',
      timezone: data['timezone']?.toString() ?? 'Asia/Kolkata',
      enabledModules: modules.isEmpty ? defaultModules : modules,
      active: data['active'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'code': code.trim(),
    'phone': phone.trim(),
    'address': address.trim(),
    'currency': currency,
    'timezone': timezone,
    'enabled_modules': enabledModules.map((e) => e.storageValue).toList(),
    'active': active,
    'updated_at': FieldValue.serverTimestamp(),
  };

  ClinicProfile copyWith({
    String? name,
    String? code,
    String? phone,
    String? address,
    String? currency,
    String? timezone,
    Set<ClinicModule>? enabledModules,
    bool? active,
  }) => ClinicProfile(
    id: id,
    name: name ?? this.name,
    code: code ?? this.code,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    currency: currency ?? this.currency,
    timezone: timezone ?? this.timezone,
    enabledModules: enabledModules ?? this.enabledModules,
    active: active ?? this.active,
  );
}

class ClinicMembership {
  const ClinicMembership({
    required this.clinicId,
    required this.userId,
    required this.role,
    this.branchIds = const [],
    this.permissionOverrides = const {},
    this.active = true,
  });

  final String clinicId;
  final String userId;
  final AppRole role;
  final List<String> branchIds;
  final Set<AppPermission> permissionOverrides;
  final bool active;

  Set<AppPermission> get permissions => {
    ...role.permissions,
    ...permissionOverrides,
  };

  factory ClinicMembership.fromMap(Map<String, dynamic> data, String id) =>
      ClinicMembership(
        clinicId: data['clinic_id']?.toString() ?? '',
        userId: data['user_id']?.toString() ?? id,
        role: AppRole.fromValue(data['role']?.toString()),
        branchIds: (data['branch_ids'] as Iterable? ?? const [])
            .map((e) => e.toString())
            .toList(),
        permissionOverrides:
            (data['permission_overrides'] as Iterable? ?? const [])
                .map((value) {
                  final normalized = value.toString().replaceAll('_', '');
                  return AppPermission.values.where(
                    (item) =>
                        item.name.toLowerCase() == normalized.toLowerCase(),
                  );
                })
                .expand((items) => items)
                .toSet(),
        active: data['active'] != false,
      );
}

class TeamInvitation {
  const TeamInvitation({
    required this.id,
    required this.email,
    required this.role,
    this.status = 'pending',
    this.createdAt,
  });

  final String id;
  final String email;
  final AppRole role;
  final String status;
  final DateTime? createdAt;

  factory TeamInvitation.fromMap(Map<String, dynamic> data, String id) =>
      TeamInvitation(
        id: id,
        email: data['email']?.toString() ?? '',
        role: AppRole.fromValue(data['role']?.toString()),
        status: data['status']?.toString() ?? 'pending',
        createdAt: _date(data['created_at']),
      );
}

enum InvoiceStatus {
  draft,
  unpaid,
  partiallyPaid,
  paid,
  waived,
  refunded,
  cancelled,
}

class InvoiceLine {
  const InvoiceLine({
    required this.type,
    required this.description,
    required this.amount,
  });

  final String type;
  final String description;
  final double amount;

  factory InvoiceLine.fromMap(Map<String, dynamic> data) => InvoiceLine(
    type: data['type']?.toString() ?? 'other',
    description: data['description']?.toString() ?? '',
    amount: _amount(data['amount']),
  );

  Map<String, dynamic> toMap() => {
    'type': type,
    'description': description.trim(),
    'amount': amount,
  };
}

class ClinicInvoice {
  const ClinicInvoice({
    this.id = '',
    required this.patientName,
    required this.lines,
    required this.issuedAt,
    this.patientId = '',
    this.amountPaid = 0,
    this.status = InvoiceStatus.unpaid,
    this.paymentMethod = 'cash',
    this.notes = '',
  });

  final String id;
  final String patientId;
  final String patientName;
  final List<InvoiceLine> lines;
  final DateTime issuedAt;
  final double amountPaid;
  final InvoiceStatus status;
  final String paymentMethod;
  final String notes;

  double get total =>
      lines.fold(0, (runningTotal, line) => runningTotal + line.amount);
  double get balance => (total - amountPaid).clamp(0, double.infinity);

  factory ClinicInvoice.fromMap(Map<String, dynamic> data, String id) =>
      ClinicInvoice(
        id: id,
        patientId: data['patient_id']?.toString() ?? '',
        patientName: data['patient_name']?.toString() ?? '',
        lines: (data['lines'] as Iterable? ?? const [])
            .whereType<Map>()
            .map((e) => InvoiceLine.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        issuedAt: _date(data['issued_at']) ?? DateTime.now(),
        amountPaid: _amount(data['amount_paid']),
        status: InvoiceStatus.values.firstWhere(
          (item) => item.name == data['status'],
          orElse: () => InvoiceStatus.unpaid,
        ),
        paymentMethod: data['payment_method']?.toString() ?? 'cash',
        notes: data['notes']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {
    'patient_id': patientId,
    'patient_name': patientName.trim(),
    'lines': lines.map((e) => e.toMap()).toList(),
    'total': total,
    'amount_paid': amountPaid,
    'balance': balance,
    'status': status.name,
    'payment_method': paymentMethod,
    'notes': notes.trim(),
    'issued_at': Timestamp.fromDate(issuedAt),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

class VaccinationRecord {
  const VaccinationRecord({
    this.id = '',
    required this.patientName,
    required this.vaccine,
    required this.administeredAt,
    this.patientId = '',
    this.doseNumber = 1,
    this.batchNumber = '',
    this.manufacturer = '',
    this.route = '',
    this.site = '',
    this.vaccinator = '',
    this.nextDoseAt,
    this.adverseReaction = '',
  });

  final String id;
  final String patientId;
  final String patientName;
  final String vaccine;
  final int doseNumber;
  final String batchNumber;
  final String manufacturer;
  final String route;
  final String site;
  final String vaccinator;
  final DateTime administeredAt;
  final DateTime? nextDoseAt;
  final String adverseReaction;

  factory VaccinationRecord.fromMap(Map<String, dynamic> data, String id) =>
      VaccinationRecord(
        id: id,
        patientId: data['patient_id']?.toString() ?? '',
        patientName: data['patient_name']?.toString() ?? '',
        vaccine: data['vaccine']?.toString() ?? '',
        doseNumber: int.tryParse('${data['dose_number']}') ?? 1,
        batchNumber: data['batch_number']?.toString() ?? '',
        manufacturer: data['manufacturer']?.toString() ?? '',
        route: data['route']?.toString() ?? '',
        site: data['site']?.toString() ?? '',
        vaccinator: data['vaccinator']?.toString() ?? '',
        administeredAt: _date(data['administered_at']) ?? DateTime.now(),
        nextDoseAt: _date(data['next_dose_at']),
        adverseReaction: data['adverse_reaction']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {
    'patient_id': patientId,
    'patient_name': patientName.trim(),
    'vaccine': vaccine.trim(),
    'dose_number': doseNumber,
    'batch_number': batchNumber.trim(),
    'manufacturer': manufacturer.trim(),
    'route': route.trim(),
    'site': site.trim(),
    'vaccinator': vaccinator.trim(),
    'administered_at': Timestamp.fromDate(administeredAt),
    'next_dose_at': nextDoseAt == null ? null : Timestamp.fromDate(nextDoseAt!),
    'adverse_reaction': adverseReaction.trim(),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

class ClinicReminder {
  const ClinicReminder({
    this.id = '',
    required this.patientName,
    required this.type,
    required this.message,
    required this.scheduledAt,
    this.patientId = '',
    this.channel = 'sms',
    this.status = 'scheduled',
    this.consent = true,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String type;
  final String message;
  final DateTime scheduledAt;
  final String channel;
  final String status;
  final bool consent;

  factory ClinicReminder.fromMap(Map<String, dynamic> data, String id) =>
      ClinicReminder(
        id: id,
        patientId: data['patient_id']?.toString() ?? '',
        patientName: data['patient_name']?.toString() ?? '',
        type: data['type']?.toString() ?? 'appointment',
        message: data['message']?.toString() ?? '',
        scheduledAt: _date(data['scheduled_at']) ?? DateTime.now(),
        channel: data['channel']?.toString() ?? 'sms',
        status: data['status']?.toString() ?? 'scheduled',
        consent: data['consent'] != false,
      );

  Map<String, dynamic> toMap() => {
    'patient_id': patientId,
    'patient_name': patientName.trim(),
    'type': type,
    'message': message.trim(),
    'scheduled_at': Timestamp.fromDate(scheduledAt),
    'channel': channel,
    'status': status,
    'consent': consent,
    'updated_at': FieldValue.serverTimestamp(),
  };
}
