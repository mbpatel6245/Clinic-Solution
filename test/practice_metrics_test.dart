import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/ui/views/home/revamp/practice_metrics.dart';
import 'package:clinic_solution/ui/views/home/revamp/queue_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const patient = PatientModel(id: 'patient', firstName: 'Demo');
  test(
    'calendar week excludes tomorrow, cancelled bookings and missing dates',
    () {
      final metrics = PracticeMetrics(
        now: DateTime(2026, 10, 19, 15),
        period: PracticePeriod.week,
        patients: [
          PatientModel(
            firstName: 'Registered without visit',
            createdAt: DateTime(2026, 10, 19),
          ),
        ],
        prescriptions: [
          PrescriptionModel(
            patient: patient,
            visitDate: DateTime(2026, 10, 18),
          ),
          PrescriptionModel(
            patient: patient,
            createdAt: DateTime(2026, 10, 19),
          ),
          PrescriptionModel(patient: patient),
        ],
        appointments: [
          for (final (date, status) in [
            (DateTime(2026, 10, 19), 'booked'),
            (DateTime(2026, 10, 19), 'cancelled'),
            (DateTime(2026, 10, 20), 'booked'),
          ])
            AppointmentModel(
              patientName: 'Demo',
              phone: '',
              scheduledAt: date,
              status: status,
            ),
        ],
      );
      expect(metrics.start, DateTime(2026, 10, 19));
      expect(metrics.visits.length, 1);
      expect(metrics.newPatients, 1);
      expect(metrics.bookings, 1);
      expect(metrics.dailyVisits.map((d) => d.$2).reduce((a, b) => a + b), 2);
    },
  );
  test(
    'payments follow invoice issue period, outstanding includes older invoices',
    () {
      ClinicInvoice invoice(DateTime date, double paid) => ClinicInvoice(
        patientName: 'Demo',
        issuedAt: date,
        amountPaid: paid,
        lines: const [
          InvoiceLine(type: 'doctor', description: 'Visit', amount: 500),
        ],
      );
      final metrics = PracticeMetrics(
        now: DateTime(2026, 10, 19),
        period: PracticePeriod.today,
        invoices: [
          invoice(DateTime(2026, 10, 18), 100),
          invoice(DateTime(2026, 10, 19), 200),
        ],
      );
      expect(metrics.collected, 200);
      expect(metrics.outstanding, 700);
    },
  );
  test('diagnoses count once per visit and sort deterministically', () {
    final metrics = PracticeMetrics(
      now: DateTime(2026, 10, 19),
      period: PracticePeriod.month,
      prescriptions: [
        PrescriptionModel(
          patient: patient,
          visitDate: DateTime(2026, 10, 19),
          diagnoses: ['Cold', 'Cold', ' ', 'Allergy'],
        ),
      ],
    );
    expect(metrics.diagnoses.map((e) => (e.key, e.value)).toList(), [
      ('Allergy', 1),
      ('Cold', 1),
    ]);
  });
  test('queue stages search and calendar boundary do not mix records', () {
    final day = DateTime(2026, 10, 19);
    final items = [
      for (final status in [
        'booked',
        'pending',
        'confirmed',
        'completed',
        'cancelled',
      ])
        AppointmentModel(
          id: status,
          patientName: 'Demo',
          phone: '12345',
          scheduledAt: day,
          status: status,
        ),
      AppointmentModel(
        patientName: 'Other day',
        phone: '',
        scheduledAt: DateTime(2026, 10, 20),
        status: 'confirmed',
      ),
    ];
    expect(filterQueue(items, day, QueueStage.scheduled, '').length, 2);
    expect(filterQueue(items, day, QueueStage.live, '123').map((e) => e.id), [
      'confirmed',
    ]);
    expect(filterQueue(items, day, QueueStage.done, 'DEMO').map((e) => e.id), [
      'completed',
    ]);
    expect(filterQueue(items, day, QueueStage.cancelled, '').length, 1);
    expect(filterQueue(items, day, QueueStage.live, 'missing'), isEmpty);
  });
  test('patient directory respects clinic module and staff role gates', () {
    expect(moduleForFeature(AppFeature.patients), ClinicModule.patients);
    expect(AppRole.doctor.can(AppFeature.patients), isTrue);
    expect(AppRole.receptionist.can(AppFeature.patients), isTrue);
    for (final role in [
      AppRole.patient,
      AppRole.accountant,
      AppRole.pharmacyOperator,
    ]) {
      expect(role.can(AppFeature.patients), isFalse);
    }
  });
}
