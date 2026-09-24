import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method to send password reset email
  Future<void> sendPasswordResetEmail(
    String email, {
    String locale = 'en',
  }) async {
    final project = Firebase.app().options.projectId;
    final response = await http
        .post(
          Uri.https(
            'asia-south1-$project.cloudfunctions.net',
            '/requestPasswordReset',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'data': {'email': email.trim(), 'locale': locale},
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw FirebaseAuthException(
        code: 'reset-unavailable',
        message: 'Unable to request a reset. Please try again later.',
      );
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential;
  }

  Future<UserCredential> login(String email, String password) async {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential;
  }
}
