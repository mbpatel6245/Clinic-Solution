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
    this.openingTime = '09:00',
    this.closingTime = '18:00',
    this.workingDays = const {1, 2, 3, 4, 5, 6},
    this.sharePrescriptionsWithPatients = false,
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
  final String openingTime;
  final String closingTime;
  final Set<int> workingDays;
  final bool sharePrescriptionsWithPatients;

  bool isOpenAt(DateTime value) {
    if (!active || !workingDays.contains(value.weekday)) return false;
    int minutes(String time) {
      final parts = time.split(':');
      return (int.tryParse(parts.first) ?? 0) * 60 +
          (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
    }

    final current = value.hour * 60 + value.minute;
    return current >= minutes(openingTime) && current < minutes(closingTime);
  }

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
      openingTime: data['opening_time']?.toString() ?? '09:00',
      closingTime: data['closing_time']?.toString() ?? '18:00',
      workingDays: (data['working_days'] as Iterable? ?? [1, 2, 3, 4, 5, 6])
          .map((value) => int.tryParse('$value'))
          .whereType<int>()
          .toSet(),
      sharePrescriptionsWithPatients:
          data['share_prescriptions_with_patients'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'name_normalized': name.trim().toLowerCase(),
    'code': code.trim(),
    'phone': phone.trim(),
    'address': address.trim(),
    'currency': currency,
    'timezone': timezone,
    'enabled_modules': enabledModules.map((e) => e.storageValue).toList(),
    'active': active,
    'opening_time': openingTime,
    'closing_time': closingTime,
    'working_days': workingDays.toList(),
    'share_prescriptions_with_patients': sharePrescriptionsWithPatients,
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
    String? openingTime,
    String? closingTime,
    Set<int>? workingDays,
    bool? sharePrescriptionsWithPatients,
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
    openingTime: openingTime ?? this.openingTime,
    closingTime: closingTime ?? this.closingTime,
    workingDays: workingDays ?? this.workingDays,
    sharePrescriptionsWithPatients:
        sharePrescriptionsWithPatients ?? this.sharePrescriptionsWithPatients,
  );
}

class PlatformModuleSettings {
  const PlatformModuleSettings({this.disabledModules = const {}});

  final Set<ClinicModule> disabledModules;

  Set<ClinicModule> get enabledModules =>
      ClinicModule.values.toSet()..removeAll(disabledModules);

  factory PlatformModuleSettings.fromMap(Map<String, dynamic> data) =>
      PlatformModuleSettings(
        disabledModules: (data['disabled_modules'] as Iterable? ?? const [])
            .map((value) => ClinicModule.fromValue(value.toString()))
            .whereType<ClinicModule>()
            .toSet(),
      );

  Map<String, dynamic> toMap() => {
    'disabled_modules': disabledModules
        .map((module) => module.storageValue)
        .toList(),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

class PlatformModuleRecord {
  const PlatformModuleRecord({
    required this.id,
    required this.clinicId,
    required this.data,
  });

  final String id;
  final String clinicId;
  final Map<String, dynamic> data;
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
    this.roles = const [],
    this.status = 'pending',
    this.createdAt,
    this.clinicId = '',
    this.notificationStatus = 'queued',
    this.notificationError = '',
    this.approvalStatus = 'pending',
    this.approvalError = '',
  });

  final String id;
  final String email;
  final AppRole role;
  final List<AppRole> roles;
  final String status;
  final DateTime? createdAt;
  final String clinicId;
  final String notificationStatus;
  final String notificationError;
  final String approvalStatus;
  final String approvalError;

  factory TeamInvitation.fromMap(
    Map<String, dynamic> data,
    String id, {
    String clinicId = '',
  }) => TeamInvitation(
    id: id,
    email: data['email']?.toString() ?? '',
    role: AppRole.fromValue(data['role']?.toString()),
    roles:
        (data['roles'] is Iterable
                ? data['roles'] as Iterable
                : const <dynamic>[])
            .map((value) => AppRole.fromValue(value.toString()))
            .toSet()
            .toList(),
    status: data['status']?.toString() ?? 'pending',
    createdAt: _date(data['created_at']),
    clinicId: clinicId,
    notificationStatus: data['notification_status']?.toString() ?? 'queued',
    notificationError: data['notification_error']?.toString() ?? '',
    approvalStatus: data['approval_status']?.toString() ?? 'pending',
    approvalError: data['approval_error']?.toString() ?? '',
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

class PlatformNotificationSettings {
  const PlatformNotificationSettings({
    this.primaryProvider = 'msg91',
    this.fallbackProvider = 'twilio',
    this.fallbackEnabled = false,
    this.defaultCountryCode = '91',
    this.msg91SmsTemplateId = '',
    this.msg91WhatsappTemplateName = '',
    this.msg91WhatsappNamespace = '',
    this.msg91WhatsappIntegratedNumber = '',
    this.msg91EmailTemplateId = '',
    this.msg91EmailDomain = '',
    this.msg91EmailFrom = '',
    this.msg91EmailFromName = 'Clinic',
    this.twilioMessagingServiceSid = '',
    this.twilioSmsFrom = '',
    this.twilioSmsContentSid = '',
    this.twilioWhatsappFrom = '',
    this.twilioWhatsappContentSid = '',
    this.sendGridFromEmail = '',
    this.sendGridFromName = 'Clinic',
    this.sendGridTemplateId = '',
    this.twilioStatusCallbackUrl = '',
  });

  final String primaryProvider;
  final String fallbackProvider;
  final bool fallbackEnabled;
  final String defaultCountryCode;
  final String msg91SmsTemplateId;
  final String msg91WhatsappTemplateName;
  final String msg91WhatsappNamespace;
  final String msg91WhatsappIntegratedNumber;
  final String msg91EmailTemplateId;
  final String msg91EmailDomain;
  final String msg91EmailFrom;
  final String msg91EmailFromName;
  final String twilioMessagingServiceSid;
  final String twilioSmsFrom;
  final String twilioSmsContentSid;
  final String twilioWhatsappFrom;
  final String twilioWhatsappContentSid;
  final String sendGridFromEmail;
  final String sendGridFromName;
  final String sendGridTemplateId;
  final String twilioStatusCallbackUrl;

  factory PlatformNotificationSettings.fromMap(Map<String, dynamic> data) {
    final msg91 = data['msg91'] is Map
        ? Map<String, dynamic>.from(data['msg91'] as Map)
        : const <String, dynamic>{};
    final twilio = data['twilio'] is Map
        ? Map<String, dynamic>.from(data['twilio'] as Map)
        : const <String, dynamic>{};
    return PlatformNotificationSettings(
      primaryProvider: data['primary_provider']?.toString() == 'twilio'
          ? 'twilio'
          : 'msg91',
      fallbackProvider: data['fallback_provider']?.toString() == 'msg91'
          ? 'msg91'
          : 'twilio',
      fallbackEnabled: data['fallback_enabled'] == true,
      defaultCountryCode: data['default_country_code']?.toString() ?? '91',
      msg91SmsTemplateId: msg91['sms_template_id']?.toString() ?? '',
      msg91WhatsappTemplateName:
          msg91['whatsapp_template_name']?.toString() ?? '',
      msg91WhatsappNamespace: msg91['whatsapp_namespace']?.toString() ?? '',
      msg91WhatsappIntegratedNumber:
          msg91['whatsapp_integrated_number']?.toString() ?? '',
      msg91EmailTemplateId: msg91['email_template_id']?.toString() ?? '',
      msg91EmailDomain: msg91['email_domain']?.toString() ?? '',
      msg91EmailFrom: msg91['email_from']?.toString() ?? '',
      msg91EmailFromName: msg91['email_from_name']?.toString() ?? 'Clinic',
      twilioMessagingServiceSid:
          twilio['messaging_service_sid']?.toString() ?? '',
      twilioSmsFrom: twilio['sms_from']?.toString() ?? '',
      twilioSmsContentSid: twilio['sms_content_sid']?.toString() ?? '',
      twilioWhatsappFrom: twilio['whatsapp_from']?.toString() ?? '',
      twilioWhatsappContentSid:
          twilio['whatsapp_content_sid']?.toString() ?? '',
      sendGridFromEmail: twilio['sendgrid_from_email']?.toString() ?? '',
      sendGridFromName: twilio['sendgrid_from_name']?.toString() ?? 'Clinic',
      sendGridTemplateId: twilio['sendgrid_template_id']?.toString() ?? '',
      twilioStatusCallbackUrl: twilio['status_callback_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'primary_provider': primaryProvider,
    'fallback_provider': fallbackProvider,
    'fallback_enabled': fallbackEnabled,
    'default_country_code': defaultCountryCode.trim(),
    'msg91': {
      'sms_template_id': msg91SmsTemplateId.trim(),
      'whatsapp_template_name': msg91WhatsappTemplateName.trim(),
      'whatsapp_namespace': msg91WhatsappNamespace.trim(),
      'whatsapp_integrated_number': msg91WhatsappIntegratedNumber.trim(),
      'email_template_id': msg91EmailTemplateId.trim(),
      'email_domain': msg91EmailDomain.trim(),
      'email_from': msg91EmailFrom.trim(),
      'email_from_name': msg91EmailFromName.trim(),
    },
    'twilio': {
      'messaging_service_sid': twilioMessagingServiceSid.trim(),
      'sms_from': twilioSmsFrom.trim(),
      'sms_content_sid': twilioSmsContentSid.trim(),
      'whatsapp_from': twilioWhatsappFrom.trim(),
      'whatsapp_content_sid': twilioWhatsappContentSid.trim(),
      'sendgrid_from_email': sendGridFromEmail.trim(),
      'sendgrid_from_name': sendGridFromName.trim(),
      'sendgrid_template_id': sendGridTemplateId.trim(),
      'status_callback_url': twilioStatusCallbackUrl.trim(),
    },
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
    required this.recipient,
    this.patientId = '',
    this.channel = 'sms',
    this.status = 'scheduled',
    this.consent = true,
    this.templateId = '',
    this.templateLanguage = 'en',
    this.providerMessageId = '',
    this.failureReason = '',
    this.attempts = 0,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String type;
  final String message;
  final DateTime scheduledAt;
  final String recipient;
  final String channel;
  final String status;
  final bool consent;
  final String templateId;
  final String templateLanguage;
  final String providerMessageId;
  final String failureReason;
  final int attempts;

  factory ClinicReminder.fromMap(Map<String, dynamic> data, String id) =>
      ClinicReminder(
        id: id,
        patientId: data['patient_id']?.toString() ?? '',
        patientName: data['patient_name']?.toString() ?? '',
        type: data['type']?.toString() ?? 'appointment',
        message: data['message']?.toString() ?? '',
        scheduledAt: _date(data['scheduled_at']) ?? DateTime.now(),
        recipient: data['recipient']?.toString() ?? '',
        channel: data['channel']?.toString() ?? 'sms',
        status: data['status']?.toString() ?? 'scheduled',
        consent: data['consent'] != false,
        templateId: data['template_id']?.toString() ?? '',
        templateLanguage: data['template_language']?.toString() ?? 'en',
        providerMessageId: data['provider_message_id']?.toString() ?? '',
        failureReason: data['failure_reason']?.toString() ?? '',
        attempts: int.tryParse('${data['attempts'] ?? 0}') ?? 0,
      );

  Map<String, dynamic> toMap() => {
    'patient_id': patientId,
    'patient_name': patientName.trim(),
    'type': type,
    'message': message.trim(),
    'scheduled_at': Timestamp.fromDate(scheduledAt),
    'recipient': recipient.trim(),
    'channel': channel,
    'status': status,
    'consent': consent,
    if (templateId.trim().isNotEmpty) 'template_id': templateId.trim(),
    'template_language': templateLanguage.trim().isEmpty
        ? 'en'
        : templateLanguage.trim(),
    'updated_at': FieldValue.serverTimestamp(),
  };
}
