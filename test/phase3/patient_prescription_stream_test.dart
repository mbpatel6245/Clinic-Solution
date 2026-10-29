import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/features/clinical/data/patient_prescription_stream.dart';

Future<void> tick() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'patient records merge authorized clinics and disappear on sharing, membership or identity changes',
    () async {
      final identities = StreamController<String?>.broadcast(),
          access = StreamController<PatientClinicAccess>.broadcast();
      final sharing = {
        for (final id in ['a', 'b']) id: StreamController<bool>.broadcast(),
      };
      final records = {
        for (final id in ['a', 'b'])
          id: StreamController<List<PrescriptionModel>>.broadcast(),
      };
      var latest = <PrescriptionModel>[];
      final subscription = patientPrescriptionStream(
        userId: 'patient',
        identities: identities.stream,
        access: access.stream,
        sharing: (c) => sharing[c]!.stream,
        records: (c) => records[c]!.stream,
      ).listen((v) => latest = v);
      PrescriptionModel row(String clinic) => PrescriptionModel(
        id: 'same-id',
        patient: const PatientModel(firstName: 'Synthetic'),
        clinicId: clinic,
        visitDate: DateTime(2026, 10, 28),
      );
      access.add(const PatientClinicAccess({'a', 'b'}));
      await tick();
      sharing['a']!.add(true);
      sharing['b']!.add(true);
      await tick();
      records['a']!.add([row('a')]);
      records['b']!.add([row('b')]);
      await tick();
      expect(latest.length, 2);
      sharing['a']!.add(false);
      await tick();
      expect(latest.single.clinicId, 'b');
      expect(records['a']!.hasListener, false);
      access.add(const PatientClinicAccess({'a'}));
      await tick();
      expect(latest, isEmpty);
      expect(records['b']!.hasListener, false);
      sharing['a']!.add(true);
      await tick();
      records['a']!.add([row('a')]);
      await tick();
      expect(latest.single.clinicId, 'a');
      identities.add('other-patient');
      await tick();
      expect(latest, isEmpty);
      expect(records['a']!.hasListener, false);
      access.add(const PatientClinicAccess({'a', 'b'}));
      await tick();
      expect(sharing['b']!.hasListener, false);
      await subscription.cancel();
      await identities.close();
      await access.close();
      for (final source in [...sharing.values, ...records.values]) {
        await source.close();
      }
    },
  );
  test(
    'revoked membership and failed clinic reads remove previously displayed data',
    () async {
      final identities = StreamController<String?>(),
          access = StreamController<PatientClinicAccess>(),
          sharing = StreamController<bool>(),
          records = StreamController<List<PrescriptionModel>>();
      var latest = <PrescriptionModel>[];
      final errors = <Object>[];
      final subscription = patientPrescriptionStream(
        userId: 'patient',
        identities: identities.stream,
        access: access.stream,
        sharing: (_) => sharing.stream,
        records: (_) => records.stream,
      ).listen((v) => latest = v, onError: errors.add);
      access.add(const PatientClinicAccess({'a'}));
      await tick();
      sharing.add(true);
      await tick();
      records.add([
        PrescriptionModel(
          id: 'row',
          patient: const PatientModel(firstName: 'Synthetic'),
        ),
      ]);
      await tick();
      expect(latest.length, 1);
      sharing.addError(StateError('Synthetic permission rejection'));
      await tick();
      expect(latest, isEmpty);
      expect(errors.length, 1);
      expect(records.hasListener, false);
      await subscription.cancel();
      await identities.close();
      await access.close();
      await sharing.close();
      await records.close();
    },
  );
}
