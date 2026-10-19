import '../../../../data/datasources/clinical_models.dart';
import '../../../../data/datasources/enterprise_models.dart';

enum PracticePeriod { today, week, month, year }

/// Calendar boundaries deliberately use local dates, never elapsed 24-hour
/// arithmetic, so midnight and daylight-saving transitions stay consistent.
class PracticeMetrics {
  PracticeMetrics({
    required DateTime now,
    required PracticePeriod period,
    this.patients = const [],
    this.prescriptions = const [],
    this.appointments = const [],
    this.invoices = const [],
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) : today = DateTime(now.year, now.month, now.day),
       end = rangeEnd == null
           ? DateTime(now.year, now.month, now.day + 1)
           : DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day + 1),
       start = rangeStart == null
           ? switch (period) {
               PracticePeriod.today => DateTime(now.year, now.month, now.day),
               PracticePeriod.week => DateTime(
                 now.year,
                 now.month,
                 now.day - now.weekday + 1,
               ),
               PracticePeriod.month => DateTime(now.year, now.month),
               PracticePeriod.year => DateTime(now.year),
             }
           : DateTime(rangeStart.year, rangeStart.month, rangeStart.day);

  final DateTime today, start, end;
  final List<PatientModel> patients;
  final List<PrescriptionModel> prescriptions;
  final List<AppointmentModel> appointments;
  final List<ClinicInvoice> invoices;

  bool contains(DateTime? value) =>
      value != null && !value.isBefore(start) && value.isBefore(end);
  List<PrescriptionModel> get visits => prescriptions
      .where((item) => contains(item.visitDate ?? item.createdAt))
      .toList();
  int get newPatients =>
      patients.where((item) => contains(item.createdAt)).length;
  int get bookings => appointments
      .where((item) => contains(item.scheduledAt) && item.status != 'cancelled')
      .length;
  List<ClinicInvoice> get periodInvoices =>
      invoices.where((item) => contains(item.issuedAt)).toList();
  // The schema stores cumulative amountPaid, not payment-event timestamps.
  // This is collected against invoices issued in the selected period.
  double get collected =>
      periodInvoices.fold(0, (sum, item) => sum + item.amountPaid);
  double get outstanding => invoices.fold(0, (sum, item) => sum + item.balance);
  List<(DateTime, int)> get dailyVisits => List.generate(7, (index) {
    final date = DateTime(today.year, today.month, today.day - 6 + index);
    final next = DateTime(date.year, date.month, date.day + 1);
    return (
      date,
      prescriptions.where((item) {
        final time = item.visitDate ?? item.createdAt;
        return time != null && !time.isBefore(date) && time.isBefore(next);
      }).length,
    );
  });
  List<MapEntry<String, int>> get diagnoses {
    final counts = <String, int>{};
    for (final visit in visits) {
      for (final diagnosis
          in visit.diagnoses
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()) {
        counts.update(diagnosis, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts.entries.toList()..sort((a, b) {
      final count = b.value.compareTo(a.value);
      return count == 0 ? a.key.compareTo(b.key) : count;
    });
  }

  List<MapEntry<String, int>> get medications {
    final counts = <String, int>{};
    for (final visit in visits) {
      for (final name
          in visit.medicines
              .map((m) => m.name.trim())
              .where((e) => e.isNotEmpty)
              .toSet()) {
        counts.update(name, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Map<String, int> get ageGroups {
    final counts = {
      '0–4': 0,
      '5–17': 0,
      '18–39': 0,
      '40–59': 0,
      '60+': 0,
      'unspecified': 0,
    };
    for (final patient in patients) {
      final age = patient.ageInYearsAt(today);
      final group = age == null
          ? 'unspecified'
          : age < 5
          ? '0–4'
          : age < 18
          ? '5–17'
          : age < 40
          ? '18–39'
          : age < 60
          ? '40–59'
          : '60+';
      counts[group] = counts[group]! + 1;
    }
    return counts;
  }

  Map<String, int> get genders {
    final counts = {'male': 0, 'female': 0, 'other': 0, 'unspecified': 0};
    for (final p in patients) {
      final key = counts.containsKey(p.gender.toLowerCase())
          ? p.gender.toLowerCase()
          : 'unspecified';
      counts[key] = counts[key]! + 1;
    }
    return counts;
  }

  List<AppointmentModel> get recordedOutcomes => appointments
      .where(
        (a) =>
            contains(a.scheduledAt) &&
            ['confirmed', 'completed', 'no_show'].contains(a.status),
      )
      .toList();
  double? get noShowRate => recordedOutcomes.isEmpty
      ? null
      : recordedOutcomes.where((a) => a.status == 'no_show').length /
            recordedOutcomes.length;
}
