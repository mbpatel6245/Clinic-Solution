import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String activeClinicId;
  final List<String> clinicIds;
  final Map<String, String> clinicRoles;
  final Map<String, List<String>> clinicRoleLists;
  final String status;
  final bool mustChangePassword;
  final String requestedClinicName;
  final Timestamp createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.activeClinicId = '',
    this.clinicIds = const [],
    this.clinicRoles = const {},
    this.clinicRoleLists = const {},
    this.status = 'approved',
    this.mustChangePassword = false,
    this.requestedClinicName = '',
    required this.createdAt,
  });

  // Convert Firestore document to a User object
  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? '',
      activeClinicId: data['active_clinic_id']?.toString() ?? '',
      clinicIds: (data['clinic_ids'] as Iterable? ?? const [])
          .map((item) => item.toString())
          .toList(),
      clinicRoles: data['clinic_roles'] is Map
          ? Map<String, String>.from(
              (data['clinic_roles'] as Map).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            )
          : const {},
      clinicRoleLists: data['clinic_role_lists'] is Map
          ? (data['clinic_role_lists'] as Map).map(
              (key, value) => MapEntry(
                key.toString(),
                (value is Iterable ? value : [value])
                    .map((role) => role.toString())
                    .toList(),
              ),
            )
          : const {},
      status: data['status']?.toString() ?? 'approved',
      mustChangePassword: data['must_change_password'] == true,
      requestedClinicName: data['requested_clinic_name']?.toString() ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Convert User object to Firestore document format
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'email_normalized': email.trim().toLowerCase(),
      'phone': phone,
      'role': role,
      'active_clinic_id': activeClinicId,
      'clinic_ids': clinicIds,
      'clinic_roles': clinicRoles,
      'clinic_role_lists': clinicRoleLists,
      'status': status,
      'must_change_password': mustChangePassword,
      if (requestedClinicName.isNotEmpty)
        'requested_clinic_name': requestedClinicName.trim(),
      'createdAt': createdAt,
    };
  }
}
