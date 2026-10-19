import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;
  User? get currentUser => _auth.currentUser;

  // Firebase owns authentication email delivery and its localized templates.
  Future<void> sendPasswordResetEmail(
    String email, {
    String locale = 'en',
  }) async {
    await _auth.setLanguageCode(
      ['en', 'hi', 'gu'].contains(locale) ? locale : 'en',
    );
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Keep the same response for addresses that are not registered.
      if (error.code != 'user-not-found') rethrow;
    }
  }

  Future<void> sendEmailVerification({String locale = 'en'}) async {
    await _auth.setLanguageCode(
      ['en', 'hi', 'gu'].contains(locale) ? locale : 'en',
    );
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) await user.sendEmailVerification();
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
