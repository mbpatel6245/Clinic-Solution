enum ClinicModule {
  patients,
  reception,
  appointments,
  clinical,
  pharmacy,
  vaccination,
  reminders,
  billing,
  expenses,
  reports,
  dataExchange,
  laboratory;

  static ClinicModule? fromValue(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    for (final module in values) {
      if (module.name.toLowerCase() == normalized) return module;
    }
    return null;
  }

  String get displayName => switch (this) {
    patients => 'Patient registry',
    reception => 'Reception & queue',
    appointments => 'Appointments',
    clinical => 'Clinical records',
    pharmacy => 'Pharmacy & inventory',
    vaccination => 'Vaccination',
    reminders => 'Reminders',
    billing => 'Billing & payments',
    expenses => 'Expenses',
    reports => 'Reports & analytics',
    dataExchange => 'Import & export',
    laboratory => 'Laboratory',
  };

  String get storageValue => this == dataExchange ? 'data_exchange' : name;
}

enum AppFeature {
  dashboard,
  createPrescription,
  prescriptionList,
  appointments,
  reception,
  inventory,
  vaccination,
  reminders,
  billing,
  finance,
  reports,
  dataExchange,
  team,
  clinicSetup,
}

enum AppPermission {
  view,
  create,
  edit,
  archive,
  approve,
  importData,
  exportData,
  collectPayment,
  refundPayment,
  viewFinancialReports,
  configureClinic,
  manageTeam,
}

enum AppRole {
  platformOwner,
  clinicAdmin,
  branchManager,
  doctor,
  receptionist,
  pharmacyOperator,
  vaccinator,
  accountant,
  patient;

  static AppRole fromValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    return switch (normalized) {
      'owner' ||
      'superadmin' ||
      'platformowner' ||
      'productowner' => AppRole.platformOwner,
      'admin' ||
      'administrator' ||
      'clinicadmin' ||
      'clinicowner' => AppRole.clinicAdmin,
      'manager' || 'branchmanager' => AppRole.branchManager,
      'patient' || 'user' || 'guest' => AppRole.patient,
      'pharmacy' ||
      'pharmacist' ||
      'pharmacyoperator' => AppRole.pharmacyOperator,
      'reception' || 'receptionist' => AppRole.receptionist,
      'vaccination' || 'vaccinator' || 'nurse' => AppRole.vaccinator,
      'accounts' || 'accountant' => AppRole.accountant,
      'doctor' || 'physician' || 'independentdoctor' => AppRole.doctor,
      _ => AppRole.doctor,
    };
  }

  String get storageValue => switch (this) {
    platformOwner => 'platform_owner',
    clinicAdmin => 'clinic_admin',
    branchManager => 'branch_manager',
    pharmacyOperator => 'pharmacy_operator',
    _ => name,
  };

  String get displayName => switch (this) {
    platformOwner => 'Platform Owner',
    clinicAdmin => 'Clinic Admin',
    branchManager => 'Branch Manager',
    doctor => 'Doctor',
    receptionist => 'Receptionist',
    patient => 'Patient',
    pharmacyOperator => 'Pharmacy Operator',
    vaccinator => 'Nurse / Vaccinator',
    accountant => 'Accountant',
  };

  Set<AppFeature> get features => switch (this) {
    platformOwner => AppFeature.values.toSet(),
    clinicAdmin => AppFeature.values.toSet(),
    branchManager =>
      AppFeature.values.toSet()
        ..remove(AppFeature.clinicSetup)
        ..remove(AppFeature.team),
    doctor => {
      AppFeature.dashboard,
      AppFeature.createPrescription,
      AppFeature.prescriptionList,
      AppFeature.reception,
      AppFeature.appointments,
      AppFeature.vaccination,
      AppFeature.reminders,
    },
    receptionist => {
      AppFeature.dashboard,
      AppFeature.reception,
      AppFeature.appointments,
      AppFeature.billing,
      AppFeature.reminders,
    },
    patient => {AppFeature.appointments, AppFeature.reminders},
    pharmacyOperator => {
      AppFeature.dashboard,
      AppFeature.prescriptionList,
      AppFeature.inventory,
      AppFeature.billing,
    },
    vaccinator => {
      AppFeature.dashboard,
      AppFeature.appointments,
      AppFeature.vaccination,
      AppFeature.reminders,
    },
    accountant => {
      AppFeature.dashboard,
      AppFeature.billing,
      AppFeature.finance,
      AppFeature.reports,
      AppFeature.dataExchange,
    },
  };

  Set<AppPermission> get permissions => switch (this) {
    platformOwner => AppPermission.values.toSet(),
    clinicAdmin =>
      AppPermission.values.toSet()..remove(AppPermission.configureClinic),
    branchManager =>
      AppPermission.values.toSet()..remove(AppPermission.configureClinic),
    doctor => {
      AppPermission.view,
      AppPermission.create,
      AppPermission.edit,
      AppPermission.approve,
    },
    receptionist || pharmacyOperator || vaccinator => {
      AppPermission.view,
      AppPermission.create,
      AppPermission.edit,
      AppPermission.collectPayment,
    },
    accountant => {
      AppPermission.view,
      AppPermission.create,
      AppPermission.edit,
      AppPermission.archive,
      AppPermission.collectPayment,
      AppPermission.refundPayment,
      AppPermission.viewFinancialReports,
      AppPermission.importData,
      AppPermission.exportData,
    },
    patient => {AppPermission.view, AppPermission.create},
  };

  bool can(AppFeature feature) => features.contains(feature);
  bool isAllowed(AppPermission permission) => permissions.contains(permission);
}

ClinicModule? moduleForFeature(AppFeature feature) => switch (feature) {
  AppFeature.dashboard || AppFeature.team || AppFeature.clinicSetup => null,
  AppFeature.createPrescription ||
  AppFeature.prescriptionList => ClinicModule.clinical,
  AppFeature.appointments => ClinicModule.appointments,
  AppFeature.reception => ClinicModule.reception,
  AppFeature.inventory => ClinicModule.pharmacy,
  AppFeature.vaccination => ClinicModule.vaccination,
  AppFeature.reminders => ClinicModule.reminders,
  AppFeature.billing => ClinicModule.billing,
  AppFeature.finance => ClinicModule.expenses,
  AppFeature.reports => ClinicModule.reports,
  AppFeature.dataExchange => ClinicModule.dataExchange,
};
