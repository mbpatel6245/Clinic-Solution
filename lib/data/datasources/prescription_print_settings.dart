enum PrescriptionLayout { classic, minimal, bordered }

/// Clinic-managed letterhead. Never includes a patient identity or signature.
class PrescriptionPrintSettings {
  const PrescriptionPrintSettings({
    this.layout = PrescriptionLayout.classic,
    this.clinicianName = '',
    this.qualifications = '',
    this.registration = '',
    this.footerNote = '',
    this.showDiagnoses = true,
    this.showVitals = true,
    this.showPhone = true,
    this.fontSize = 12,
    this.marginMm = 18,
  });
  final PrescriptionLayout layout;
  final String clinicianName, qualifications, registration, footerNote;
  final bool showDiagnoses, showVitals, showPhone;
  final double fontSize, marginMm;
  factory PrescriptionPrintSettings.fromMap(Map<String, dynamic> map) =>
      PrescriptionPrintSettings(
        layout:
            PrescriptionLayout.values
                .where((v) => v.name == map['layout'])
                .firstOrNull ??
            PrescriptionLayout.classic,
        clinicianName: '${map['clinician_name'] ?? ''}',
        qualifications: '${map['qualifications'] ?? ''}',
        registration: '${map['registration'] ?? ''}',
        footerNote: '${map['footer_note'] ?? ''}',
        showDiagnoses: map['show_diagnoses'] != false,
        showVitals: map['show_vitals'] != false,
        showPhone: map['show_phone'] != false,
        fontSize: _bounded(map['font_size'], 12, 11, 14),
        marginMm: _bounded(map['margin_mm'], 18, 12, 25),
      );
  static double _bounded(
    Object? raw,
    double fallback,
    double min,
    double max,
  ) => raw is num && raw.isFinite ? raw.toDouble().clamp(min, max) : fallback;
  Map<String, dynamic> toMap() => {
    'layout': layout.name,
    'clinician_name': clinicianName.trim(),
    'qualifications': qualifications.trim(),
    'registration': registration.trim(),
    'footer_note': footerNote.trim(),
    'show_diagnoses': showDiagnoses,
    'show_vitals': showVitals,
    'show_phone': showPhone,
    'font_size': fontSize,
    'margin_mm': marginMm,
  };
}
