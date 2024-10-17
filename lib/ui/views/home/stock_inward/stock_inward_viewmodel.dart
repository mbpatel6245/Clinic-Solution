import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../services/auth_services.dart';
import '../../../../services/firestore_services.dart';

class StockInwardViewmodel with ChangeNotifier {
  // Text Editing Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFireStore _fireStoreService = FirebaseFireStore();

  // Selected Role
  String? selectedRole;

  // List of roles for the dropdown
  final List<String> roles = ['User', 'Admin', 'Guest'];

  void onRoleChanged(String? value) {
    selectedRole = value;
    notifyListeners();
  }

  // Validate all fields
  bool validateForm(GlobalKey<FormState> formKey) {
    return formKey.currentState?.validate() ?? false;
  }

  // Save data to Firestore
  Future<void> registerUser() async {
    try {
      _fireStoreService.registerUserData(
          emailController.text.trim(),
          passwordController.text.trim(),
          nameController.text.trim(),
          phoneController.text,
          selectedRole ?? selectedRole![0]);
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  // Dispose controllers
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
