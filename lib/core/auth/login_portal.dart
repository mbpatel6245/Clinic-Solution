import 'app_role.dart';

enum LoginPortal { clinic, staff }

/// Entry points never assign a role. Membership remains the authority for
/// workspace access; the staff entry additionally rejects non-staff accounts.
bool acceptsStaffProfile(Map<String, dynamic> profile) {
  if ((profile['status'] ?? 'approved') != 'approved') return false;
  const staff = {
    'reception',
    'receptionist',
    'pharmacy',
    'pharmacist',
    'pharmacyoperator',
    'accounts',
    'accountant',
    'vaccinator',
    'nurse',
    'branchmanager',
    'manager',
  };
  String normalize(Object? value) =>
      '$value'.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  final clinic = profile['active_clinic_id']?.toString() ?? '';
  final lists = profile['clinic_role_lists'];
  final roles = lists is Map ? lists[clinic] : null;
  final singles = profile['clinic_roles'];
  final single = singles is Map ? singles[clinic] : null;
  final values = roles is Iterable && roles.isNotEmpty
      ? roles
      : [single ?? profile['role']];
  return values.any((role) => staff.contains(normalize(role)));
}

bool isFrontDeskOnly(Set<AppRole> roles) =>
    roles.isNotEmpty && roles.every((role) => role == AppRole.receptionist);
