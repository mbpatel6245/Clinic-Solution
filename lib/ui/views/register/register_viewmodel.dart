import 'package:clinic_solution/main.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RegisterViewModel with ChangeNotifier {
  // Text Editing Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // Selected Role
  String? selectedRole;

  // List of roles for the dropdown
  final List<String> roles = ['User', 'Admin', 'Guest'];

  // Firebase Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form validation logic
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(navigatorKey.currentContext!)!.emailRequired;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return AppLocalizations.of(navigatorKey.currentContext!)!.validEmail;
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(navigatorKey.currentContext!)!.passwordRequired;
    }
    if (value.length < 6) {
      return AppLocalizations.of(navigatorKey.currentContext!)!.validPassword;
    }
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(navigatorKey.currentContext!)!.phoneRequired;
    }
    final phoneRegex = RegExp(r'^\d{10}$'); // Simple 10-digit validation
    if (!phoneRegex.hasMatch(value)) {
      return AppLocalizations.of(navigatorKey.currentContext!)!.validPhone;
    }
    return null;
  }

  void onRoleChanged(String? value) {
    selectedRole = value;
    notifyListeners();
  }

  // Validate all fields
  bool validateForm(GlobalKey<FormState> formKey) {
    return formKey.currentState?.validate() ?? false;
  }

  // Save data to Firestore
  Future<void> saveData() async {
    try {
      await _firestore.collection('users').add({
        'email': emailController.text,
        'password': passwordController.text, // For demo purposes only; avoid saving passwords like this in production
        'phone': phoneController.text,
        'role': selectedRole,
      });
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
