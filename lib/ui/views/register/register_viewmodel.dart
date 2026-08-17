import 'package:flutter/material.dart';

import '../../../services/firestore_services.dart';
import '../../../core/auth/app_role.dart';

class RegisterViewModel with ChangeNotifier {
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
  final List<String> roles = [AppRole.patient.displayName];

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
      await _fireStoreService.registerUserData(
        emailController.text.trim(),
        passwordController.text.trim(),
        nameController.text.trim(),
        phoneController.text,
        AppRole.fromValue(selectedRole).storageValue,
      );
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  // Dispose controllers
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
