import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'clinical_models.dart';
import 'enterprise_models.dart';

enum PatientEntryMode { registration, walkIn, booking }

enum PatientEntryAction { openRecord, queue, booked }

class PatientEntryResult {
  const PatientEntryResult(
    this.patient,
    this.action, {
    this.appointment,
    this.clinicId = '',
  });
  final PatientModel patient;
  final PatientEntryAction action;
  final AppointmentModel? appointment;
  final String clinicId;
}

class PatientEntrySubmission {
  const PatientEntrySubmission({
    required this.patient,
    required this.isNew,
    required this.action,
    required this.appointmentId,
    this.scheduledAt,
    this.sendConfirmation = false,
    this.careConsentRecorded = false,
  });
  final PatientModel patient;
  final bool isNew;
  final PatientEntryAction action;
  final String appointmentId;
  final DateTime? scheduledAt;
  final bool sendConfirmation;
  final bool careConsentRecorded;
}

class PatientEntryException implements Exception {
  const PatientEntryException(this.label);
  final String label;
}

/// Slot boundaries are computed in the clinic's IANA zone, independently of
/// the device location. Firestore persists the resulting instant in UTC.
abstract final class ClinicSchedule {
  static bool _initialized = false;
  static tz.Location location(ClinicProfile clinic) {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
    return tz.getLocation(clinic.timezone);
  }

  static tz.TZDateTime local(ClinicProfile clinic, DateTime instant) =>
      tz.TZDateTime.from(instant, location(clinic));
  static DateTime day(ClinicProfile clinic, DateTime instant) {
    final value = local(clinic, instant);
    return DateTime(value.year, value.month, value.day);
  }

  static bool sameDay(ClinicProfile clinic, DateTime instant, DateTime date) {
    final value = local(clinic, instant);
    return value.year == date.year &&
        value.month == date.month &&
        value.day == date.day;
  }

  static int? _minutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]), minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  static List<DateTime> slots(
    ClinicProfile clinic,
    DateTime date, {
    required DateTime now,
    List<AppointmentModel> appointments = const [],
  }) {
    if (!clinic.active || !clinic.workingDays.contains(date.weekday)) return [];
    final start = _minutes(clinic.openingTime),
        end = _minutes(clinic.closingTime);
    if (start == null || end == null || end <= start) return [];
    final zone = location(clinic);
    return [
          for (var minute = start; minute + 15 <= end; minute += 15)
            tz.TZDateTime(
              zone,
              date.year,
              date.month,
              date.day,
              minute ~/ 60,
              minute % 60,
            ).toUtc(),
        ]
        .where(
          (slot) =>
              slot.isAfter(now) &&
              !appointments.any(
                (appointment) =>
                    occupiesSlot(appointment) &&
                    appointment.scheduledAt.isAtSameMomentAs(slot),
              ),
        )
        .toList();
  }

  static bool occupiesSlot(AppointmentModel value) =>
      !{'cancelled', 'no_show'}.contains(value.status);
}
