import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterViewModel with ChangeNotifier {
  // Text Editing Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'name': nameController.text,
        'email': userCredential.user?.email,
        'password': passwordController.text,
        // For demo purposes only; avoid saving passwords like this in production
        'phone': phoneController.text,
        'role': selectedRole,
        'createdAt': Timestamp.now(),
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
