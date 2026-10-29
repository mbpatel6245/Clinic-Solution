import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class ClinicCallableFailure implements Exception {
  const ClinicCallableFailure(
    this.code, {
    this.uncertain = false,
    this.details = const {},
  });
  final String code;
  final bool uncertain;
  final Map<String, dynamic> details;
}

/// One authenticated principal/clinic for the lifetime of the transport.
/// Unknown replies never become successful clinical acknowledgements.
class ScopedClinicCallable {
  ScopedClinicCallable(
    this.clinicId, {
    FirebaseAuth? auth,
    http.Client? client,
    String? projectId,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _user = (auth ?? FirebaseAuth.instance).currentUser?.uid,
       _client = client ?? http.Client(),
       _project = projectId ?? Firebase.app().options.projectId;
  final String clinicId, _project;
  final String? _user;
  final FirebaseAuth _auth;
  final http.Client _client;
  void _check() {
    if (_user == null || _auth.currentUser?.uid != _user) {
      throw const ClinicCallableFailure('unauthenticated');
    }
  }

  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, Object?> input,
  ) async {
    _check();
    if (input['clinicId'] != null && input['clinicId'] != clinicId) {
      throw const ClinicCallableFailure('permission-denied');
    }
    try {
      final token = await _auth.currentUser!.getIdToken().timeout(
        const Duration(seconds: 20),
      );
      _check();
      if (token == null || token.isEmpty) {
        throw const ClinicCallableFailure('unauthenticated');
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
      _check();
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw const ClinicCallableFailure('unavailable', uncertain: true);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ClinicCallableFailure('permission-denied');
      }
      final body = jsonDecode(response.body) as Map;
      if (body['error'] is Map) {
        final error = body['error'] as Map;
        throw ClinicCallableFailure(
          error['status']?.toString().toLowerCase().replaceAll('_', '-') ??
              'rejected',
          details: error['details'] is Map
              ? Map<String, dynamic>.from(error['details'] as Map)
              : const {},
        );
      }
      if (response.statusCode != 200 || body['result'] is! Map) {
        throw const ClinicCallableFailure('unknown', uncertain: true);
      }
      return Map<String, dynamic>.from(body['result'] as Map);
    } on ClinicCallableFailure {
      rethrow;
    } catch (_) {
      throw const ClinicCallableFailure('unknown', uncertain: true);
    }
  }

  void close() => _client.close();
}
