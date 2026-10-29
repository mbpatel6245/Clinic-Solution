import 'dart:async';
import '../../../data/datasources/clinical_models.dart';

class PatientClinicAccess {
  const PatientClinicAccess(this.clinics, {this.approved = true});
  final Set<String> clinics;
  final bool approved;
}

/// Merge explicitly authorized clinic queries rather than an unbounded
/// collection-group query. Disabling sharing or removing membership immediately
/// removes that clinic's rows and cancels its subscription.
Stream<List<T>> scopedPatientRecordStream<T>({
  required String userId,
  required Stream<String?> identities,
  required Stream<PatientClinicAccess> access,
  required Stream<bool> Function(String clinic) sharing,
  required Stream<List<T>> Function(String clinic) records,
  required Comparator<T> compare,
}) {
  late StreamController<List<T>> output;
  StreamSubscription<String?>? identitySubscription;
  StreamSubscription<PatientClinicAccess>? accessSubscription;
  final children = <StreamSubscription<Object?>>[];
  final recordSubscriptions = <String, StreamSubscription<List<T>>>{};
  final items = <String, List<T>>{};
  var generation = 0, active = true;
  void emit() {
    if (!active || output.isClosed) {
      return;
    }
    final combined = items.values.expand((v) => v).toList()..sort(compare);
    output.add(combined);
  }

  void clearChildren() {
    generation++;
    for (final child in children) {
      unawaited(child.cancel());
    }
    for (final child in recordSubscriptions.values) {
      unawaited(child.cancel());
    }
    children.clear();
    recordSubscriptions.clear();
    items.clear();
  }

  void error(Object failure, StackTrace stack) {
    if (active && !output.isClosed) {
      output.addError(failure, stack);
    }
  }

  output = StreamController<List<T>>(
    onListen: () {
      identitySubscription = identities.listen((uid) {
        if (uid == userId || !active) {
          return;
        }
        clearChildren();
        emit();
        active = false;
        unawaited(accessSubscription?.cancel());
      }, onError: error);
      accessSubscription = access.listen(
        (scope) {
          if (!active) {
            return;
          }
          clearChildren();
          emit();
          if (!scope.approved) {
            return;
          }
          final epoch = generation;
          for (final clinic in scope.clinics) {
            children.add(
              sharing(clinic).listen(
                (allowed) {
                  if (!active || epoch != generation) {
                    return;
                  }
                  if (!allowed) {
                    unawaited(recordSubscriptions.remove(clinic)?.cancel());
                    items.remove(clinic);
                    emit();
                    return;
                  }
                  recordSubscriptions.putIfAbsent(
                    clinic,
                    () => records(clinic).listen(
                      (values) {
                        if (!active ||
                            epoch != generation ||
                            !recordSubscriptions.containsKey(clinic)) {
                          return;
                        }
                        items[clinic] = values;
                        emit();
                      },
                      onError: (Object failure, StackTrace stack) {
                        if (!active || epoch != generation) {
                          return;
                        }
                        items.remove(clinic);
                        emit();
                        error(failure, stack);
                      },
                    ),
                  );
                },
                onError: (Object failure, StackTrace stack) {
                  if (!active || epoch != generation) {
                    return;
                  }
                  unawaited(recordSubscriptions.remove(clinic)?.cancel());
                  items.remove(clinic);
                  emit();
                  error(failure, stack);
                },
              ),
            );
          }
        },
        onError: (Object failure, StackTrace stack) {
          clearChildren();
          emit();
          error(failure, stack);
        },
      );
    },
    onCancel: () async {
      active = false;
      await identitySubscription?.cancel();
      await accessSubscription?.cancel();
      final subscriptions = [...children, ...recordSubscriptions.values];
      children.clear();
      recordSubscriptions.clear();
      items.clear();
      await Future.wait(subscriptions.map((s) => s.cancel()));
    },
  );
  return output.stream;
}

Stream<List<PrescriptionModel>> patientPrescriptionStream({
  required String userId,
  required Stream<String?> identities,
  required Stream<PatientClinicAccess> access,
  required Stream<bool> Function(String clinic) sharing,
  required Stream<List<PrescriptionModel>> Function(String clinic) records,
}) => scopedPatientRecordStream<PrescriptionModel>(
  userId: userId,
  identities: identities,
  access: access,
  sharing: sharing,
  records: records,
  compare: (a, b) => b.visitTimestamp.compareTo(a.visitTimestamp),
);
