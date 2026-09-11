import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clinic configuration reads enabled modules', () {
    final clinic = ClinicProfile.fromMap({
      'name': 'Small Clinic',
      'enabled_modules': ['clinical', 'pharmacy', 'vaccination'],
    }, 'clinic-1');

    expect(clinic.enabledModules, contains(ClinicModule.pharmacy));
    expect(clinic.enabledModules, isNot(contains(ClinicModule.reception)));
  });

  test('invoice calculates total and outstanding balance', () {
    final invoice = ClinicInvoice(
      patientName: 'Asha',
      issuedAt: DateTime(2026, 9, 6),
      amountPaid: 400,
      lines: const [
        InvoiceLine(type: 'doctor', description: 'Consultation', amount: 500),
        InvoiceLine(type: 'clinic', description: 'Case fee', amount: 100),
      ],
    );

    expect(invoice.total, 600);
    expect(invoice.balance, 200);
  });

  test('module gating maps features to clinic modules', () {
    expect(moduleForFeature(AppFeature.inventory), ClinicModule.pharmacy);
    expect(moduleForFeature(AppFeature.team), isNull);
  });

  test('reminder preserves recipient and provider delivery state', () {
    final reminder = ClinicReminder.fromMap({
      'patient_name': 'Asha',
      'message': 'Appointment tomorrow',
      'scheduled_at': DateTime(2026, 9, 7),
      'recipient': 'asha@example.com',
      'channel': 'email',
      'status': 'failed',
      'failure_reason': 'Template not configured',
      'attempts': 2,
    }, 'reminder-1');

    expect(reminder.recipient, 'asha@example.com');
    expect(reminder.failureReason, 'Template not configured');
    expect(reminder.attempts, 2);
  });

  test(
    'global notification settings preserve primary and fallback providers',
    () {
      final settings = PlatformNotificationSettings.fromMap({
        'primary_provider': 'twilio',
        'fallback_provider': 'msg91',
        'fallback_enabled': true,
        'default_country_code': '91',
        'msg91': {'sms_template_id': 'flow-1'},
        'twilio': {
          'messaging_service_sid': 'MG123',
          'whatsapp_content_sid': 'HX123',
        },
      });

      expect(settings.primaryProvider, 'twilio');
      expect(settings.fallbackProvider, 'msg91');
      expect(settings.fallbackEnabled, isTrue);
      expect(settings.msg91SmsTemplateId, 'flow-1');
      expect(settings.twilioWhatsappContentSid, 'HX123');
    },
  );

  test('team invitation preserves its pending clinic role', () {
    final invitation = TeamInvitation.fromMap(
      {'email': 'doctor@example.com', 'role': 'doctor', 'status': 'pending'},
      'invite-1',
      clinicId: 'clinic-1',
    );

    expect(invitation.email, 'doctor@example.com');
    expect(invitation.role, AppRole.doctor);
    expect(invitation.status, 'pending');
    expect(invitation.clinicId, 'clinic-1');
  });
}
