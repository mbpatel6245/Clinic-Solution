import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:clinic_solution/core/auth/login_portal.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/workflow_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/ui/views/home/revamp/practice_metrics.dart';

void main() {
  test(
    'staff entry accepts assigned active-clinic staff roles without elevating roles',
    () {
      expect(
        acceptsStaffProfile({
          'role': 'doctor',
          'active_clinic_id': 'a',
          'clinic_role_lists': {
            'a': ['receptionist'],
          },
        }),
        isTrue,
      );
      expect(
        acceptsStaffProfile({'role': 'receptionist', 'status': 'pending'}),
        isFalse,
      );
      expect(
        acceptsStaffProfile({
          'role': 'receptionist',
          'active_clinic_id': 'a',
          'clinic_roles': {'a': 'doctor'},
        }),
        isFalse,
      );
      expect(acceptsStaffProfile({'role': 'unknown'}), isFalse);
      expect(isFrontDeskOnly({AppRole.receptionist}), isTrue);
      expect(isFrontDeskOnly({AppRole.receptionist, AppRole.doctor}), isFalse);
    },
  );
  test('patient age units and demographic fields survive serialization', () {
    const baby = PatientModel(
      id: 'baby',
      firstName: 'Demo',
      age: 6,
      ageUnit: 'months',
      abhaId: 'test-only',
      allergies: ['Example'],
      notificationConsent: true,
      locale: 'gu',
    );
    final restored = PatientModel.fromMap(baby.toMap(), baby.id);
    expect(restored.ageInYearsAt(DateTime(2026)), .5);
    expect(restored.allergies, ['Example']);
    expect(restored.abhaId, 'test-only');
    expect(restored.notificationConsent, isTrue);
    expect(restored.copyWith(id: 'same').ageUnit, 'months');
    final birthday = PatientModel(
      firstName: 'Demo',
      dateOfBirth: DateTime(2000, 10, 20),
    );
    expect(birthday.ageInYearsAt(DateTime(2026, 10, 19)), 25);
    expect(birthday.ageInYearsAt(DateTime(2026, 10, 20)), 26);
  });
  test(
    'template schema excludes patient identity, private notes and measured vitals',
    () {
      const template = PrescriptionTemplate(
        name: ' Example ',
        diagnoses: ['Example'],
        medicines: [MedicineLine(name: 'Sample item')],
      );
      final map = template.toMap();
      expect(
        map.keys,
        unorderedEquals([
          'name',
          'diagnoses',
          'complaints',
          'investigation',
          'advice',
          'medicines',
          'updated_at',
        ]),
      );
      expect(map['name'], 'Example');
      expect(
        PrescriptionTemplate.fromMap(map, 't').medicines.single.name,
        'Sample item',
      );
    },
  );
  test('plan completion keeps sitting notes and dates', () {
    final plan = TreatmentPlan(
      patientId: 'p',
      patientName: 'Demo',
      name: 'Plan',
      sittings: [
        TreatmentSitting(
          name: 'One',
          scheduledAt: DateTime(2026),
          notes: 'Keep',
        ),
        TreatmentSitting(name: 'Two', scheduledAt: DateTime(2027)),
      ],
    );
    final completed = plan.withSittings([
      plan.sittings.first.withCompleted(true),
      plan.sittings.last,
    ]);
    expect(completed.progress, .5);
    expect(plan.progress, 0);
    final restored = TreatmentPlan.fromMap(completed.toMap(), 'one');
    expect(restored.sittings.first.notes, 'Keep');
    expect(restored.progress, .5);
  });
  test(
    'lab flags use reported ranges and series never mix patients or units',
    () {
      LabObservation observation({
        String patient = 'p',
        String unit = 'mg/dL',
        double value = 5,
        double? lower,
        double? upper,
      }) => LabObservation(
        patientId: patient,
        patientName: 'Demo',
        analyte: 'Test',
        value: value,
        unit: unit,
        reportedAt: DateTime(2026),
        lower: lower,
        upper: upper,
      );
      expect(observation().outsideReportedRange, isFalse);
      expect(observation(lower: 5, upper: 10).outsideReportedRange, isFalse);
      expect(observation(value: 4, lower: 5).outsideReportedRange, isTrue);
      expect(observation(upper: 4).outsideReportedRange, isTrue);
      expect(
        observation(unit: 'mmol/L').seriesKey,
        isNot(observation().seriesKey),
      );
      expect(
        observation(patient: 'other').seriesKey,
        isNot(observation().seriesKey),
      );
    },
  );
  test('queue linkage survives prescription serialization', () {
    const prescription = PrescriptionModel(
      patient: PatientModel(firstName: 'Demo'),
      appointmentId: 'visit',
    );
    expect(
      PrescriptionModel.fromMap(prescription.toMap('p'), 'rx').appointmentId,
      'visit',
    );
  });
  test(
    'analytics use explicit attendance and keep infant ages in the right cohort',
    () {
      final metrics = PracticeMetrics(
        now: DateTime(2026, 10, 19),
        period: PracticePeriod.today,
        patients: const [
          PatientModel(
            firstName: 'Infant',
            age: 6,
            ageUnit: 'months',
            gender: 'female',
          ),
          PatientModel(firstName: 'Unknown'),
        ],
        appointments: [
          for (final status in ['completed', 'no_show', 'booked', 'cancelled'])
            AppointmentModel(
              patientName: 'Demo',
              phone: '',
              scheduledAt: DateTime(2026, 10, 19),
              status: status,
            ),
        ],
      );
      expect(metrics.noShowRate, .5);
      expect(metrics.ageGroups['0–4'], 1);
      expect(metrics.ageGroups['unspecified'], 1);
      expect(metrics.genders['female'], 1);
    },
  );
}
