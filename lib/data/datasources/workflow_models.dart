import 'package:cloud_firestore/cloud_firestore.dart';
import 'clinical_models.dart';

DateTime? workflowDate(Object? value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
    ? value
    : DateTime.tryParse('$value');

class PrescriptionTemplate {
  const PrescriptionTemplate({
    this.id = '',
    required this.name,
    this.diagnoses = const [],
    this.complaints = '',
    this.investigation = '',
    this.advice = '',
    this.medicines = const [],
  });
  final String id, name, complaints, investigation, advice;
  final List<String> diagnoses;
  final List<MedicineLine> medicines;
  factory PrescriptionTemplate.fromMap(Map<String, dynamic> data, String id) =>
      PrescriptionTemplate(
        id: id,
        name: data['name']?.toString() ?? '',
        diagnoses: (data['diagnoses'] as Iterable? ?? [])
            .map((e) => e.toString())
            .toList(),
        complaints: data['complaints']?.toString() ?? '',
        investigation: data['investigation']?.toString() ?? '',
        advice: data['advice']?.toString() ?? '',
        medicines: (data['medicines'] as Iterable? ?? [])
            .whereType<Map>()
            .map((e) => MedicineLine.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
  // Patient identifiers, demographics, vital measurements, visit dates and
  // private notes are intentionally impossible to serialize into a template.
  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'diagnoses': diagnoses,
    'complaints': complaints.trim(),
    'investigation': investigation.trim(),
    'advice': advice.trim(),
    'medicines': medicines
        .where((e) => !e.isEmpty)
        .map((e) => e.toMap())
        .toList(),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

class TreatmentSitting {
  const TreatmentSitting({
    required this.name,
    required this.scheduledAt,
    this.completed = false,
    this.notes = '',
  });
  final String name, notes;
  final DateTime scheduledAt;
  final bool completed;
  factory TreatmentSitting.fromMap(Map<String, dynamic> data) =>
      TreatmentSitting(
        name: '${data['name'] ?? ''}',
        scheduledAt: workflowDate(data['scheduled_at']) ?? DateTime(1970),
        completed: data['completed'] == true,
        notes: '${data['notes'] ?? ''}',
      );
  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'scheduled_at': Timestamp.fromDate(scheduledAt),
    'completed': completed,
    'notes': notes.trim(),
  };
  TreatmentSitting withCompleted(bool value) => TreatmentSitting(
    name: name,
    scheduledAt: scheduledAt,
    completed: value,
    notes: notes,
  );
}

enum TreatmentPlanStatus { active, completed, cancelled }

class TreatmentPlan {
  const TreatmentPlan({
    this.id = '',
    required this.patientId,
    required this.patientName,
    required this.name,
    required this.sittings,
    this.notes = '',
    this.status = TreatmentPlanStatus.active,
  });
  final String id, patientId, patientName, name, notes;
  final List<TreatmentSitting> sittings;
  final TreatmentPlanStatus status;
  double get progress => sittings.isEmpty
      ? 0
      : sittings.where((s) => s.completed).length / sittings.length;
  factory TreatmentPlan.fromMap(Map<String, dynamic> data, String id) =>
      TreatmentPlan(
        id: id,
        patientId: '${data['patient_id'] ?? ''}',
        patientName: '${data['patient_name'] ?? ''}',
        name: '${data['name'] ?? ''}',
        notes: '${data['notes'] ?? ''}',
        status:
            TreatmentPlanStatus.values
                .where((v) => v.name == data['status'])
                .firstOrNull ??
            TreatmentPlanStatus.active,
        sittings: (data['sittings'] as Iterable? ?? [])
            .whereType<Map>()
            .map((e) => TreatmentSitting.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
  Map<String, dynamic> toMap() => {
    'patient_id': patientId,
    'patient_name': patientName,
    'name': name.trim(),
    'notes': notes.trim(),
    'status': status.name,
    'sittings': sittings.map((e) => e.toMap()).toList(),
    'updated_at': FieldValue.serverTimestamp(),
  };
  TreatmentPlan withSittings(List<TreatmentSitting> value) => TreatmentPlan(
    id: id,
    patientId: patientId,
    patientName: patientName,
    name: name,
    sittings: value,
    notes: notes,
    status: status,
  );
}

class TreatmentSittingLog {
  const TreatmentSittingLog({
    required this.id,
    required this.sittingIndex,
    required this.workDone,
    this.notes = '',
    required this.performedAt,
    required this.authorId,
  });
  final String id, workDone, notes, authorId;
  final int sittingIndex;
  final DateTime performedAt;
  factory TreatmentSittingLog.fromMap(Map<String, dynamic> data, String id) =>
      TreatmentSittingLog(
        id: id,
        sittingIndex: (data['sitting_index'] as num?)?.toInt() ?? 0,
        workDone: '${data['work_done'] ?? ''}',
        notes: '${data['notes'] ?? ''}',
        performedAt: workflowDate(data['performed_at']) ?? DateTime(1970),
        authorId: '${data['author_id'] ?? ''}',
      );
}

class LabObservation {
  const LabObservation({
    this.id = '',
    required this.patientId,
    required this.patientName,
    required this.analyte,
    required this.value,
    required this.unit,
    required this.reportedAt,
    this.lower,
    this.upper,
    this.notes = '',
  });
  final String id, patientId, patientName, analyte, unit, notes;
  final double value;
  final double? lower, upper;
  final DateTime reportedAt;
  bool get outsideReportedRange =>
      (lower != null && value < lower!) || (upper != null && value > upper!);
  // Units are part of the series key: mg/dL is never mixed with mmol/L.
  String get seriesKey =>
      '${patientId.trim()}|${analyte.trim().toLowerCase()}|${unit.trim().toLowerCase()}';
  factory LabObservation.fromMap(Map<String, dynamic> data, String id) =>
      LabObservation(
        id: id,
        patientId: '${data['patient_id'] ?? ''}',
        patientName: '${data['patient_name'] ?? ''}',
        analyte: '${data['analyte'] ?? ''}',
        value: (data['value'] as num?)?.toDouble() ?? 0,
        unit: '${data['unit'] ?? ''}',
        reportedAt: workflowDate(data['reported_at']) ?? DateTime(1970),
        lower: (data['lower'] as num?)?.toDouble(),
        upper: (data['upper'] as num?)?.toDouble(),
        notes: '${data['notes'] ?? ''}',
      );
  Map<String, dynamic> toMap() => {
    'patient_id': patientId,
    'patient_name': patientName,
    'analyte': analyte.trim(),
    'value': value,
    'unit': unit.trim(),
    'reported_at': Timestamp.fromDate(reportedAt),
    'lower': lower,
    'upper': upper,
    'notes': notes.trim(),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

class StaffMessage {
  const StaffMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    this.sentAt,
  });
  final String id, text, senderId, senderName;
  final DateTime? sentAt;
  factory StaffMessage.fromMap(Map<String, dynamic> data, String id) =>
      StaffMessage(
        id: id,
        text: '${data['text'] ?? ''}',
        senderId: '${data['sender_id'] ?? ''}',
        senderName: '${data['sender_name'] ?? ''}',
        sentAt: workflowDate(data['sent_at']),
      );
}
