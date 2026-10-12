import 'package:clinic_solution/services/auth_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAuth extends Fake implements FirebaseAuth {
  String? language;
  String? resetEmail;
  String? errorCode;
  final TestUser user = TestUser();
  @override
  Future<void> setLanguageCode(String? code) async {
    language = code;
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetEmail = email;
    if (errorCode != null) throw FirebaseAuthException(code: errorCode!);
  }

  @override
  User? get currentUser => user;
}

class TestUser extends Fake implements User {
  bool verified = false;
  int sends = 0;
  @override
  bool get emailVerified => verified;
  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    sends++;
  }
}

void main() {
  test(
    'password reset uses Firebase with trimmed email and Gujarati locale',
    () async {
      final auth = TestAuth();
      await AuthService(
        auth: auth,
      ).sendPasswordResetEmail(' person@example.com ', locale: 'gu');
      expect(auth.resetEmail, 'person@example.com');
      expect(auth.language, 'gu');
    },
  );
  test(
    'unknown accounts remain private but provider failures are reported',
    () async {
      final auth = TestAuth()..errorCode = 'user-not-found';
      final service = AuthService(auth: auth);
      await service.sendPasswordResetEmail(
        'unknown@example.com',
        locale: 'invalid',
      );
      expect(auth.language, 'en');
      auth.errorCode = 'too-many-requests';
      await expectLater(
        service.sendPasswordResetEmail('person@example.com'),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
  );
  test('verification uses Firebase and skips verified users', () async {
    final auth = TestAuth();
    final service = AuthService(auth: auth);
    await service.sendEmailVerification(locale: 'hi');
    expect(auth.language, 'hi');
    expect(auth.user.sends, 1);
    auth.user.verified = true;
    await service.sendEmailVerification();
    expect(auth.user.sends, 1);
  });
}
