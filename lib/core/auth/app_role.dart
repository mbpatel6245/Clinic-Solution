enum AppFeature {
  dashboard,
  createPrescription,
  prescriptionList,
  appointments,
  inventory,
  finance,
  team,
}

enum AppRole {
  admin,
  doctor,
  patient,
  pharmacyOperator;

  static AppRole fromValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    return switch (normalized) {
      'admin' || 'administrator' => AppRole.admin,
      'patient' || 'user' || 'guest' => AppRole.patient,
      'pharmacy' ||
      'pharmacist' ||
      'pharmacyoperator' => AppRole.pharmacyOperator,
      'doctor' || 'physician' => AppRole.doctor,
      _ => AppRole.doctor,
    };
  }

  String get storageValue => switch (this) {
    AppRole.admin => 'admin',
    AppRole.doctor => 'doctor',
    AppRole.patient => 'patient',
    AppRole.pharmacyOperator => 'pharmacy_operator',
  };

  String get displayName => switch (this) {
    AppRole.admin => 'Admin',
    AppRole.doctor => 'Doctor',
    AppRole.patient => 'Patient',
    AppRole.pharmacyOperator => 'Pharmacy Operator',
  };

  Set<AppFeature> get features => switch (this) {
    AppRole.admin => AppFeature.values.toSet(),
    AppRole.doctor => {
      AppFeature.dashboard,
      AppFeature.createPrescription,
      AppFeature.prescriptionList,
      AppFeature.appointments,
    },
    AppRole.patient => {AppFeature.appointments},
    AppRole.pharmacyOperator => {
      AppFeature.dashboard,
      AppFeature.prescriptionList,
      AppFeature.inventory,
    },
  };

  bool can(AppFeature feature) => features.contains(feature);
}
