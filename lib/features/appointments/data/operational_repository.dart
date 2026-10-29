import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../../../data/datasources/clinical_models.dart';
import 'booking_outbox_store.dart';

class OperationalFailure implements Exception {
  const OperationalFailure(this.code, {this.unknown = false});
  final String code;
  final bool unknown;
}

/// Only an encrypted, explicitly unlocked snapshot can populate an offline form.
/// The server still revalidates every selection when a request is replayed.
class CachedOperationalRepository implements OperationalRepository {
  CachedOperationalRepository(this.remote, this.vault);
  final OperationalRepository remote;
  final BookingVault vault;
  int? _validatedAt;
  @override
  Future<List<Practitioner>> practitioners() async {
    try {
      final result = await remote.practitioners();
      _validatedAt = DateTime.now().millisecondsSinceEpoch;
      await vault.cache('practitioners', {
        'at': _validatedAt,
        'items': [
          for (final p in result) {'id': p.id, 'name': p.name},
        ],
      });
      return result;
    } on OperationalFailure catch (e) {
      final code = e.code.toLowerCase().replaceAll('_', '-');
      if (!e.unknown &&
          !['unavailable', 'deadline-exceeded', 'internal'].contains(code)) {
        rethrow;
      }
      final cached = await vault.cached('practitioners');
      if (!_fresh(cached)) rethrow;
      _validatedAt = cached!['at'] as int;
      return [
        for (final p in cached['items'] as List)
          Practitioner(p['id'] as String, p['name'] as String),
      ];
    }
  }

  static bool _fresh(Map<String, Object?>? value) {
    final at = value?['at'];
    final age = at is int ? DateTime.now().millisecondsSinceEpoch - at : -1;
    return age >= 0 && age <= const Duration(hours: 24).inMilliseconds;
  }

  Stream<List<PatientModel>> patients(
    Stream<List<PatientModel>> source,
  ) async* {
    final cached = await vault.cached('patients');
    if (_fresh(cached)) {
      yield [
        for (final p in cached!['items'] as List)
          PatientModel(id: p['id'] as String, firstName: p['name'] as String),
      ];
    }
    await for (final items in source) {
      await vault.cache('patients', {
        'at': _validatedAt ?? 0,
        'items': [
          for (final p in items) {'id': p.id, 'name': p.fullName},
        ],
      });
      yield items;
    }
  }

  @override
  Stream<List<AppointmentModel>> appointments({String? doctorId}) =>
      remote.appointments(doctorId: doctorId);
  @override
  Future<void> command(Map<String, Object?> input) => remote.command(input);
  @override
  String newOperationId() => remote.newOperationId();
}

class Practitioner {
  const Practitioner(this.id, this.name);
  final String id, name;
}

abstract interface class OperationalRepository {
  Future<List<Practitioner>> practitioners();
  Stream<List<AppointmentModel>> appointments({String? doctorId});
  Future<void> command(Map<String, Object?> input);
  String newOperationId();
}

class FirebaseOperationalRepository implements OperationalRepository {
  FirebaseOperationalRepository(
    this.clinicId, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? client,
    String? projectId,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _userId = (auth ?? FirebaseAuth.instance).currentUser?.uid,
       _client = client ?? http.Client(),
       _project = projectId ?? Firebase.app().options.projectId;
  final String clinicId, _project;
  final String? _userId;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final http.Client _client;
  void close() => _client.close();
  Future<Map<String, dynamic>> _call(
    String endpoint,
    Map<String, Object?> input,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != _userId) {
      throw const OperationalFailure('unauthenticated');
    }
    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        throw const OperationalFailure('unauthenticated');
      }
      if (_auth.currentUser?.uid != user.uid) {
        throw const OperationalFailure('unauthenticated');
      }
      final response = await _client
          .post(
            Uri.https('asia-south1-$_project.cloudfunctions.net', '/$endpoint'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'data': {...input, 'clinicId': clinicId},
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (_auth.currentUser?.uid != user.uid) {
        throw const OperationalFailure('unauthenticated');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw OperationalFailure(
          response.statusCode == 401 ? 'unauthenticated' : 'permission-denied',
        );
      }
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw const OperationalFailure('unavailable', unknown: true);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['error'] != null) {
        throw OperationalFailure(
          (body['error'] as Map?)?['status']?.toString() ?? 'unavailable',
        );
      }
      final result = body['result'] ?? body['data'];
      if (result is! Map) {
        throw const OperationalFailure('unknown', unknown: true);
      }
      return Map<String, dynamic>.from(result);
    } on OperationalFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      if (['network-request-failed', 'too-many-requests'].contains(e.code)) {
        throw const OperationalFailure('unavailable', unknown: true);
      }
      throw const OperationalFailure('unauthenticated');
    } catch (_) {
      throw const OperationalFailure('unknown', unknown: true);
    }
  }

  @override
  Future<List<Practitioner>> practitioners() async {
    final result = await _call('operationalPractitioners', {});
    if (result['enabled'] != true) {
      throw const OperationalFailure('not-migrated');
    }
    return (result['doctors'] as List)
        .map((v) => Practitioner(v['id'] as String, v['name'] as String))
        .toList();
  }

  @override
  Stream<List<AppointmentModel>> appointments({String? doctorId}) {
    Query<Map<String, dynamic>> query = _db
        .collection('clinics')
        .doc(clinicId)
        .collection('appointments');
    if (doctorId != null) {
      query = query.where('practitioner_id', isEqualTo: doctorId);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  @override
  Future<void> command(Map<String, Object?> input) async {
    final result = await _call('operationalCommand', input);
    final expected = input['kind'] == 'book'
        ? 'booked'
        : input['kind'] == 'checkIn'
        ? 'confirmed'
        : 'saved';
    if (result['status'] != expected) {
      throw const OperationalFailure('unknown', unknown: true);
    }
  }

  @override
  String newOperationId() => _db
      .collection('clinics')
      .doc(clinicId)
      .collection('appointments')
      .doc()
      .id;
}
