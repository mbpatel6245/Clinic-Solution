import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/data/datasources/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invited member preserves mandatory password change state', () {
    final user = UserModel.fromMap({
      'email': 'member@example.com',
      'role': 'doctor',
      'status': 'pending',
      'must_change_password': true,
      'requested_clinic_name': 'Sunrise Clinic',
      'createdAt': Timestamp.fromDate(DateTime(2026)),
    }, 'member-1');

    expect(user.status, 'pending');
    expect(user.mustChangePassword, isTrue);
    expect(user.requestedClinicName, 'Sunrise Clinic');
    expect(user.toMap()['must_change_password'], isTrue);
  });

  test('member preserves multiple roles independently for each clinic', () {
    final user = UserModel.fromMap({
      'email': 'member@example.com',
      'role': 'doctor',
      'clinic_roles': {'clinic-1': 'doctor'},
      'clinic_role_lists': {
        'clinic-1': ['doctor', 'vaccinator'],
      },
      'createdAt': Timestamp.fromDate(DateTime(2026)),
    }, 'member-1');

    expect(user.clinicRoleLists['clinic-1'], ['doctor', 'vaccinator']);
    expect(user.toMap()['clinic_role_lists'], isNotEmpty);
  });

  test('clinic configuration reads enabled modules', () {
    final clinic = ClinicProfile.fromMap({
      'name': 'Small Clinic',
      'enabled_modules': ['clinical', 'pharmacy', 'vaccination'],
    }, 'clinic-1');

    expect(clinic.enabledModules, contains(ClinicModule.pharmacy));
    expect(clinic.enabledModules, isNot(contains(ClinicModule.reception)));
  });

  test('platform-disabled modules are removed from global availability', () {
    final settings = PlatformModuleSettings.fromMap({
      'disabled_modules': ['pharmacy', 'reminders'],
    });

    expect(settings.enabledModules, isNot(contains(ClinicModule.pharmacy)));
    expect(settings.enabledModules, isNot(contains(ClinicModule.reminders)));
    expect(settings.enabledModules, contains(ClinicModule.clinical));
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
      {
        'email': 'doctor@example.com',
        'role': 'doctor',
        'roles': ['doctor', 'vaccinator'],
        'status': 'pending',
        'notification_status': 'failed',
        'notification_error': 'Provider configuration missing',
        'approval_status': 'failed',
        'approval_error': 'Provisioning failed',
      },
      'invite-1',
      clinicId: 'clinic-1',
    );

    expect(invitation.email, 'doctor@example.com');
    expect(invitation.role, AppRole.doctor);
    expect(invitation.roles, [AppRole.doctor, AppRole.vaccinator]);
    expect(invitation.status, 'pending');
    expect(invitation.clinicId, 'clinic-1');
    expect(invitation.notificationStatus, 'failed');
    expect(invitation.notificationError, 'Provider configuration missing');
    expect(invitation.approvalStatus, 'failed');
    expect(invitation.approvalError, 'Provisioning failed');
  });
}
