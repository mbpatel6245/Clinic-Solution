import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/clinic_scope.dart';
import 'sync_contract.dart';

/// Contract adapter for a FUTURE authenticated sync endpoint.
/// No production endpoint is configured or deployed by Phase 1.
final class HttpsSyncTransport implements SyncTransport, PatientChangeSource {
  HttpsSyncTransport({
    required this.endpoint,
    required this.client,
    required this.idToken,
  }) {
    if (endpoint.scheme != 'https' &&
        !(endpoint.scheme == 'http' &&
            ['127.0.0.1', 'localhost'].contains(endpoint.host))) {
      throw ArgumentError('Secure endpoint required.');
    }
  }
  final Uri endpoint;
  final http.Client client;
  final Future<String?> Function(ClinicScope) idToken;
  Future<Map<String, dynamic>> _request(
    ClinicScope scope,
    Map<String, Object?> data,
  ) async {
    final token = await idToken(scope);
    if (token == null || token.isEmpty) {
      throw const SyncTransportException(
        TransportFailureKind.authentication,
        'sign-in-required',
      );
    }
    try {
      final response = await client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'schemaVersion': 1,
              'scope': scope.toJson(),
              ...data,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw SyncTransportException(
          response.statusCode == 401
              ? TransportFailureKind.authentication
              : response.statusCode >= 500 || response.statusCode == 429
              ? TransportFailureKind.transient
              : TransportFailureKind.permanent,
          'http-${response.statusCode}',
        );
      }
      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic> ||
          result['scope'] is! Map ||
          result['scope']['projectId'] != scope.projectId ||
          result['scope']['userId'] != scope.userId ||
          result['scope']['clinicId'] != scope.clinicId) {
        throw const FormatException('Invalid response scope');
      }
      return result;
    } on http.ClientException {
      throw const SyncTransportException(
        TransportFailureKind.transient,
        'network-unavailable',
      );
    } on TimeoutException {
      throw const SyncTransportException(
        TransportFailureKind.transient,
        'timeout',
      );
    }
  }

  @override
  Future<PushResult> push(SyncOperation operation) async {
    final r = await _request(operation.scope, {
      'action': 'push',
      'operationId': operation.id,
      'entityType': 'patient',
      'entityId': operation.entityId,
      'kind': operation.kind.name,
      'baseRevision': operation.baseRevision,
      'payload': operation.payload,
    });
    if (r['operationId'] != operation.id) {
      throw const FormatException('Mismatched receipt');
    }
    return switch (r['status']) {
      'accepted' when r['revision'] is int => Accepted(r['revision'] as int),
      'conflict' when r['revision'] is int => Conflicted(
        r['revision'] as int,
        r['payload'] == null
            ? null
            : Map<String, Object?>.from(r['payload'] as Map),
      ),
      'rejected' => const Rejected('server-rejected'),
      _ => throw const FormatException('Invalid sync response'),
    };
  }

  @override
  Future<ChangePage> pull(ClinicScope scope, String? cursor) async {
    final r = await _request(scope, {
      'action': 'pull',
      'cursor': cursor,
      'limit': 100,
    });
    if (r['records'] is! List || r['cursor'] is! String) {
      throw const FormatException('Invalid page');
    }
    return ChangePage(
      cursor: r['cursor'] as String,
      records: (r['records'] as List).map((value) {
        final row = value as Map;
        return RemotePatient(
          row['id'] as String,
          row['revision'] as int,
          row['payload'] == null
              ? null
              : Map<String, Object?>.from(row['payload'] as Map),
        );
      }).toList(),
    );
  }
}
