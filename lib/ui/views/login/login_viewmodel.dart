import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class LoginViewModel {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final _errorController = BehaviorSubject<String?>();

  Stream<String?> get errorStream => _errorController.stream;

  void login() {
    final email = emailController.text;
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _errorController.add('Please fill in all fields');
      return;
    }

    // Perform login logic here, such as calling a repository
    // Example: authenticationRepository.login(email, password);

    _errorController.add(null); // Clear errors if login is successful
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _errorController.close();
  }
}
