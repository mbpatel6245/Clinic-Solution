import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/clinic_scope.dart';
import '../sync/sync_contract.dart';

/// In-memory credentials for the desktop transport spike. Persisting credentials
/// requires a separate platform-backed vault, not shared_preferences.
final class RestAuthSession {
  const RestAuthSession({
    required this.userId,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });
  final String userId, idToken, refreshToken;
  final DateTime expiresAt;
  @override
  String toString() => 'RestAuthSession(redacted)';
}

/// Pure Dart: usable on Windows/Linux without Firebase native plugins.
/// This adapter is not installed into the existing production bootstrap.
final class FirebaseRestClient {
  FirebaseRestClient({
    required this.projectId,
    required this.apiKey,
    required http.Client client,
    Uri? authBase,
    Uri? firestoreBase,
    Uri? tokenBase,
    DateTime Function()? clock,
  }) : _client = client,
       clock = clock ?? DateTime.now,
       authBase =
           authBase ?? Uri.https('identitytoolkit.googleapis.com', '/v1/'),
       firestoreBase =
           firestoreBase ?? Uri.https('firestore.googleapis.com', '/v1/'),
       tokenBase =
           tokenBase ?? Uri.https('securetoken.googleapis.com', '/v1/') {
    for (final uri in [this.authBase, this.firestoreBase, this.tokenBase]) {
      if (uri.scheme != 'https' &&
          !(uri.scheme == 'http' &&
              ['localhost', '127.0.0.1', '::1'].contains(uri.host))) {
        throw ArgumentError('HTTPS or a loopback emulator is required.');
      }
    }
  }
  final String projectId, apiKey;
  final http.Client _client;
  final Uri authBase, firestoreBase, tokenBase;
  final DateTime Function() clock;

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SyncTransportException(
          response.statusCode == 401
              ? TransportFailureKind.authentication
              : response.statusCode == 429 || response.statusCode >= 500
              ? TransportFailureKind.transient
              : TransportFailureKind.permanent,
          'http-${response.statusCode}',
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Invalid response');
      }
      return body;
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

  Future<RestAuthSession> signIn(String email, String password) async {
    final result = await _send(
      () => _client.post(
        authBase
            .replace(path: '${authBase.path}accounts:signInWithPassword')
            .replace(queryParameters: {'key': apiKey}),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      ),
    );
    return RestAuthSession(
      userId: result['localId'] as String,
      idToken: result['idToken'] as String,
      refreshToken: result['refreshToken'] as String,
      expiresAt: clock().add(
        Duration(seconds: int.parse(result['expiresIn'] as String)),
      ),
    );
  }

  Future<RestAuthSession> refresh(RestAuthSession session) async {
    final result = await _send(
      () => _client.post(
        tokenBase.resolve('token').replace(queryParameters: {'key': apiKey}),
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': session.refreshToken,
        },
      ),
    );
    if (result['user_id'] != session.userId) {
      throw const FormatException('Identity changed during refresh');
    }
    return RestAuthSession(
      userId: session.userId,
      idToken: result['id_token'] as String,
      refreshToken: result['refresh_token'] as String,
      expiresAt: clock().add(
        Duration(seconds: int.parse(result['expires_in'] as String)),
      ),
    );
  }

  Future<Map<String, dynamic>> listPatients(
    ClinicScope scope,
    RestAuthSession session, {
    int pageSize = 50,
    String? pageToken,
  }) async {
    if (scope.projectId != projectId || session.userId != scope.userId) {
      throw StateError('Identity/scope mismatch.');
    }
    if (pageSize < 1 || pageSize > 200) {
      throw ArgumentError('Invalid page size.');
    }
    if (!session.expiresAt.isAfter(clock())) {
      throw const SyncTransportException(
        TransportFailureKind.authentication,
        'token-expired',
      );
    }
    final uri = firestoreBase
        .resolve(
          'projects/${Uri.encodeComponent(projectId)}/databases/(default)/documents/clinics/${Uri.encodeComponent(scope.clinicId)}/patients',
        )
        .replace(
          queryParameters: {'pageSize': '$pageSize', 'pageToken': ?pageToken},
        );
    return _send(
      () => _client.get(
        uri,
        headers: {'Authorization': 'Bearer ${session.idToken}'},
      ),
    );
  }
}
