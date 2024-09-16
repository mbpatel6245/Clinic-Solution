import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/auth_services.dart';

class ForgotPasswordViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Method to send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e,stacktrace) {
      print(stacktrace.toString());
      _handleAuthException(e);
    } catch (e,stacktrace) {
      print(stacktrace.toString());
      _errorMessage = 'An error occurred. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  bool validateForm(GlobalKey<FormState> formKey) {
    return formKey.currentState?.validate() ?? false;
  }
  // Method to handle different Firebase Auth errors
  void _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        _errorMessage = 'No user found for that email.';
        break;
      case 'invalid-email':
        _errorMessage = 'Invalid email address.';
        break;
      case 'missing-client-identifier':
        _errorMessage = 'reCAPTCHA verification failed. Please try again.';
        break;
      case 'recaptcha-required':
        _errorMessage = 'reCAPTCHA verification is required. Please try again.';
        break;
      default:
        _errorMessage = 'An error occurred. Please try again.';
    }
  }
}
