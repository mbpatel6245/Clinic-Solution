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
  final String status;
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
    this.status = 'approved',
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
      status: data['status']?.toString() ?? 'approved',
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
      'status': status,
      'createdAt': createdAt,
    };
  }
}
