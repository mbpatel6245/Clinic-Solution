import 'dart:convert';
import 'package:clinic_solution/services/clinical_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('disabled AI never requests tokens or calls a provider', () async {
    var calls = 0;
    final service = ClinicalAiService(
      projectId: 'demo-clinic',
      idToken: () async {
        calls++;
        return 'id';
      },
      appCheckToken: () async {
        calls++;
        return 'check';
      },
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      service.prepareDraft(
        clinicId: 'a',
        task: ClinicalAiTask.labText,
        sourceText: 'synthetic report',
      ),
      throwsStateError,
    );
    expect(calls, 0);
  });
  test('missing App Check prevents the request', () async {
    var calls = 0;
    final service = ClinicalAiService(
      enabled: true,
      projectId: 'demo-clinic',
      idToken: () async => 'id',
      appCheckToken: () async => null,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      service.prepareDraft(
        clinicId: 'a',
        task: ClinicalAiTask.labText,
        sourceText: 'synthetic report',
      ),
      throwsStateError,
    );
    expect(calls, 0);
  });
  test(
    'callable protocol sends verified tokens and returns only a review draft',
    () async {
      final service = ClinicalAiService(
        enabled: true,
        projectId: 'demo-clinic',
        idToken: () async => 'synthetic-id',
        appCheckToken: () async => 'synthetic-check',
        client: MockClient((request) async {
          expect(
            request.url.host,
            'asia-south1-demo-clinic.cloudfunctions.net',
          );
          expect(request.headers['Authorization'], 'Bearer synthetic-id');
          expect(request.headers['X-Firebase-AppCheck'], 'synthetic-check');
          expect(jsonDecode(request.body)['data']['task'], 'translation');
          return http.Response(
            jsonEncode({
              'result': {
                'reviewRequired': true,
                'task': 'translation',
                'draft': 'समीक्षा',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final result = await service.prepareDraft(
        clinicId: 'a',
        task: ClinicalAiTask.translation,
        sourceText: 'Review',
        language: 'hi',
      );
      expect(result['draft'], 'समीक्षा');
    },
  );
}
