import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String password;
  final String phone;
  final String role;
  final Timestamp createdAt;

  UserModel(
      {required this.id,
      required this.name,
      required this.email,
      required this.password,
      required this.phone,
      required this.role,
      required this.createdAt});

  // Convert Firestore document to a User object
  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Convert User object to Firestore document format
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'role': role,
      'createdAt': createdAt,
    };
  }
}
