import 'package:clinic_solution/data/datasources/notification_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('editor uses the same catalog as the delivery service', () async {
    final catalog = await NotificationTemplateDefinition.load();
    expect(catalog.length, 17);
    for (final item in catalog) {
      for (final channel in ['sms', 'email']) {
        final data = item.defaults(channel, 'en');
        expect(
          item.validateContent(data['body'] as String, body: true),
          isNull,
        );
        expect(templatePreview(data['body'] as String), isNot(contains('{{')));
      }
    }
    final reset = catalog.firstWhere((item) => item.id == 'password_reset');
    expect(reset.validateContent('Missing reset link', body: true), isNotNull);
    expect(reset.validateContent('{{unknown}}', body: true), isNotNull);
  });
}
