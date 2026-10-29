// Test-only SDK interface doubles; none of these types ships in the app.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clinic_solution/services/auth_services.dart';
import 'package:clinic_solution/services/firestore_services.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/data/datasources/patient_intake.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  String get uid => 'staff';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Store implements FirebaseFirestore {
  final data = <String, Map<String, dynamic>>{};
  bool failCommit = false;
  int counter = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> action, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final tx = _Transaction(this);
    final result = await action(tx);
    if (failCommit) throw StateError('Simulated failed commit');
    for (final write in tx.writes) {
      data[write.$1] = write.$2;
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.path);
  final _Store db;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      _Collection(db, '$path/$name');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(this, db.data[path]);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Snapshot
    implements
        DocumentSnapshot<Map<String, dynamic>>,
        QueryDocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.ref, this.value);
  final _Document ref;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  String get id => ref.id;
  @override
  Map<String, dynamic> data() => Map.from(value ?? {});
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Query implements Query<Map<String, dynamic>> {
  _Query(this.db, this.path, this.field, this.value);
  final _Store db;
  final String path;
  final Object field;
  final Object? value;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Results([
    for (final item in db.data.entries)
      if (item.key.startsWith('$path/') &&
          item.key.split('/').length == path.split('/').length + 1 &&
          item.value[field] == value)
        _Snapshot(_Document(db, item.key), item.value),
  ]);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Store db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? name]) =>
      _Document(db, '$path/${name ?? 'auto-${db.counter++}'}');
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #where) {
      return _Query(
        db,
        path,
        i.positionalArguments.first,
        i.namedArguments[#isEqualTo],
      );
    }
    return super.noSuchMethod(i);
  }
}

class _Results implements QuerySnapshot<Map<String, dynamic>> {
  _Results(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Transaction implements Transaction {
  _Transaction(this.db);
  final _Store db;
  final writes = <(String, Map<String, dynamic>)>[];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async =>
      _Snapshot(ref as _Document, db.data[ref.path]) as DocumentSnapshot<T>;
  @override
  Transaction set<T>(DocumentReference<T> ref, T value, [SetOptions? options]) {
    writes.add((ref.path, Map<String, dynamic>.from(value as Map)));
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<Object, Object?> value) {
    writes.add((
      ref.path,
      {
        ...db.data[ref.path]!,
        for (final e in value.entries) e.key.toString(): e.value,
      },
    ));
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _Store db;
  late FirebaseFireStore service;
  final patient = PatientModel(
    id: 'patient',
    firstName: 'Demo',
    gender: 'other',
  );
  setUp(() {
    db = _Store();
    db.data['clinics/demo'] = const ClinicProfile(
      id: 'demo',
      name: 'Demo',
      workingDays: {1, 2, 3, 4, 5, 6, 7},
    ).toMap();
    service = FirebaseFireStore(
      firestore: db,
      authService: AuthService(auth: _Auth()),
    )..useClinic('demo');
  });
  PatientEntrySubmission request(
    PatientEntryAction action, {
    bool isNew = true,
    DateTime? slot,
  }) => PatientEntrySubmission(
    patient: patient,
    isNew: isNew,
    action: action,
    appointmentId: 'stable-visit',
    scheduledAt: slot ?? DateTime.now(),
  );
  test(
    'arrival atomically records identity acknowledgement and does not replace an existing arrival',
    () async {
      const path = 'clinics/demo/appointments/arrival';
      db.data[path] = {
        'status': 'booked',
        'scheduled_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
      };
      await service.recordAppointmentArrival('arrival');
      expect(db.data[path]!['status'], 'confirmed');
      expect(db.data[path]!['identity_checked'], true);
      expect(db.data[path]!['arrival_by'], 'staff');
      final audits = db.data.keys
          .where((k) => k.contains('/audit_logs/'))
          .length;
      await service.recordAppointmentArrival('arrival');
      expect(
        db.data.keys.where((k) => k.contains('/audit_logs/')).length,
        audits,
      );
    },
  );
  test(
    'no-show review preserves arrived patients and requires a reason',
    () async {
      const path = 'clinics/demo/appointments/no-show';
      db.data[path] = {
        'status': 'confirmed',
        'arrival_at': Timestamp.now(),
        'scheduled_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
      };
      await expectLater(
        service.recordAppointmentNoShow('no-show', 'Confirmed with clinic'),
        throwsA(isA<PatientEntryException>()),
      );
      expect(db.data[path]!['status'], 'confirmed');
      db.data[path] = {
        'status': 'booked',
        'scheduled_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
      };
      await expectLater(
        service.recordAppointmentNoShow('no-show', ''),
        throwsA(isA<PatientEntryException>()),
      );
      await service.recordAppointmentNoShow('no-show', 'Confirmed with clinic');
      expect(db.data[path]!['status'], 'no_show');
      expect(
        db.data.values.any((v) => v['reason'] == 'Confirmed with clinic'),
        true,
      );
    },
  );
  test(
    'new patient and queue visit commit together and retries keep one visit',
    () async {
      final entry = request(PatientEntryAction.queue);
      db.failCommit = true;
      await expectLater(
        service.submitPatientEntry(entry, clinicId: 'demo'),
        throwsStateError,
      );
      expect(
        db.data.keys.where(
          (key) => key.contains('/patients/') || key.contains('/appointments/'),
        ),
        isEmpty,
      );
      db.failCommit = false;
      final saved = await service.submitPatientEntry(entry, clinicId: 'demo');
      expect(saved.patient.id, 'patient');
      await service.submitPatientEntry(entry, clinicId: 'demo');
      expect(
        db.data.keys.where((key) => key.contains('/appointments/')),
        hasLength(1),
      );
      expect(
        db.data['clinics/demo/appointments/stable-visit']?['created_by'],
        'staff',
      );
    },
  );
  test(
    'existing patient queue preserves identity and reuses today booking',
    () async {
      db.data['clinics/demo/patients/patient'] = patient.toMap()
        ..['custom_preserved'] = 'keep';
      final original = Map<String, dynamic>.from(
        db.data['clinics/demo/patients/patient']!,
      );
      db.data['clinics/demo/appointments/already-booked'] = AppointmentModel(
        id: 'already-booked',
        patientId: 'patient',
        patientName: 'Demo',
        phone: '',
        scheduledAt: DateTime.now(),
        createdBy: 'other-staff',
      ).toMap();
      final result = await service.submitPatientEntry(
        request(PatientEntryAction.queue, isNew: false),
        clinicId: 'demo',
      );
      expect(result.appointment?.id, 'already-booked');
      expect(
        db.data['clinics/demo/appointments/already-booked']?['status'],
        'confirmed',
      );
      expect(db.data['clinics/demo/patients/patient'], original);
      expect(
        db.data.containsKey('clinics/demo/appointments/stable-visit'),
        isFalse,
      );
    },
  );
  test(
    'stale clinic and missing existing patient never create a profile',
    () async {
      await expectLater(
        service.submitPatientEntry(
          request(PatientEntryAction.openRecord),
          clinicId: 'other',
        ),
        throwsA(isA<PatientEntryException>()),
      );
      await expectLater(
        service.submitPatientEntry(
          request(PatientEntryAction.openRecord, isNew: false),
          clinicId: 'demo',
        ),
        throwsA(isA<PatientEntryException>()),
      );
      expect(db.data.containsKey('clinics/demo/patients/patient'), isFalse);
    },
  );
  test('occupied slot blocks atomic new patient booking', () async {
    final slot = DateTime.utc(2030, 1, 7, 3, 30);
    db.data['clinics/demo/appointments/occupied'] = AppointmentModel(
      patientName: 'Other',
      phone: '',
      scheduledAt: slot,
    ).toMap();
    await expectLater(
      service.submitPatientEntry(
        request(PatientEntryAction.booked, slot: slot),
        clinicId: 'demo',
      ),
      throwsA(isA<PatientEntryException>()),
    );
    expect(db.data.containsKey('clinics/demo/patients/patient'), isFalse);
  });
}
