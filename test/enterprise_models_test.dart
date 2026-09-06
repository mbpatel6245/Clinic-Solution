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

  test('team invitation preserves its pending clinic role', () {
    final invitation = TeamInvitation.fromMap({
      'email': 'doctor@example.com',
      'role': 'doctor',
      'status': 'pending',
    }, 'invite-1');

    expect(invitation.email, 'doctor@example.com');
    expect(invitation.role, AppRole.doctor);
    expect(invitation.status, 'pending');
  });
}
