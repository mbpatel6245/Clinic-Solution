import 'package:flutter/material.dart';
import '../../../../features/front_desk/presentation/front_desk_queue.dart';
import '../../../../data/datasources/enterprise_models.dart';

import '../../../../data/datasources/clinical_models.dart';

enum QueueStage { scheduled, live, done, cancelled, noShow }

List<AppointmentModel> filterQueue(
  List<AppointmentModel> items,
  DateTime day,
  QueueStage stage,
  String search,
) {
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  final query = search.trim().toLowerCase();
  return items.where((item) {
    final matchesStage = switch (stage) {
      QueueStage.scheduled =>
        item.status == 'booked' || item.status == 'pending',
      QueueStage.live => item.status == 'confirmed',
      QueueStage.done => item.status == 'completed',
      QueueStage.cancelled => item.status == 'cancelled',
      QueueStage.noShow => item.status == 'no_show',
    };
    return !item.scheduledAt.isBefore(start) &&
        item.scheduledAt.isBefore(end) &&
        matchesStage &&
        '${item.patientName} ${item.phone}'.toLowerCase().contains(query);
  }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
}

class QueueWorkspace extends StatelessWidget {
  const QueueWorkspace({
    super.key,
    required this.items,
    required this.onAction,
    this.onReviewedArrival,
    this.onRegister,
    this.onAppointments,
    this.canPrescribe = false,
    this.loading = false,
    this.hasError = false,
    this.now,
    this.clinic = const ClinicProfile(id: '', name: ''),
  });
  final List<AppointmentModel> items;
  final Future<void> Function(AppointmentModel, String) onAction;
  final Future<void> Function(AppointmentModel)? onReviewedArrival;
  final VoidCallback? onRegister, onAppointments;
  final bool canPrescribe, loading, hasError;
  final DateTime? now;
  final ClinicProfile clinic;
  @override
  Widget build(BuildContext context) => FrontDeskQueue(
    items: items,
    onAction: onAction,
    onReviewedArrival: onReviewedArrival,
    onRegister: onRegister,
    onAppointments: onAppointments,
    canPrescribe: canPrescribe,
    loading: loading,
    hasError: hasError,
    now: now,
    clinic: clinic,
  );
}
