import 'dart:convert';
import 'package:http/http.dart' as http;

enum ClinicalAiTask { labText, translation, consultationSummary }

/// Prepared for the existing Firebase project. No client API key is used.
/// App Check and ID tokens must come from their SDKs, never saved in settings.
/// The application must supply its review UI before enabling this adapter.
class ClinicalAiService {
  ClinicalAiService({
    required this.projectId,
    required this.idToken,
    required this.appCheckToken,
    this.enabled = false,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String projectId;
  final bool enabled;
  final Future<String?> Function() idToken, appCheckToken;
  final http.Client _client;
  final bool _ownsClient;

  Future<Map<String, dynamic>> prepareDraft({
    required String clinicId,
    required ClinicalAiTask task,
    required String sourceText,
    String? language,
  }) async {
    if (!enabled) throw StateError('AI assistance is disabled.');
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(projectId) ||
        !RegExp(r'^[\w-]{1,128}$').hasMatch(clinicId) ||
        sourceText.trim().isEmpty ||
        sourceText.length > 20000 ||
        (task == ClinicalAiTask.translation &&
            !['en', 'hi', 'gu'].contains(language))) {
      throw ArgumentError('Invalid draft request.');
    }
    final auth = await idToken(), check = await appCheckToken();
    if (auth == null || auth.isEmpty || check == null || check.isEmpty) {
      throw StateError('Verified sign-in is required.');
    }
    final response = await _client
        .post(
          Uri.https(
            'asia-south1-$projectId.cloudfunctions.net',
            '/prepareClinicalAiDraft',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $auth',
            'X-Firebase-AppCheck': check,
          },
          body: jsonEncode({
            'data': {
              'clinicId': clinicId,
              'task': switch (task) {
                ClinicalAiTask.labText => 'lab_text',
                ClinicalAiTask.translation => 'translation',
                ClinicalAiTask.consultationSummary => 'consultation_summary',
              },
              'text': sourceText,
              'language': ?language,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));
    // Provider errors must never expose clinical input or credentials.
    if (response.statusCode != 200) {
      throw StateError('Draft preparation failed.');
    }
    final decoded = jsonDecode(response.body);
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! Map || result['reviewRequired'] != true) {
      throw const FormatException('A reviewable draft was not returned.');
    }
    return Map<String, dynamic>.from(result);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
