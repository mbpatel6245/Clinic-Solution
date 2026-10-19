import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/locale_provider.dart';
import '../../../main.dart';
import '../../../services/auth_services.dart';
import '../../../core/auth/login_portal.dart';
import '../../../core/design/revamp_labels.dart';
import '../../../services/local/secure_data_viewmodel.dart';
import '../../themes/text_styles.dart';
import '../../widgets/common_text.dart';

class LoginViewModel with ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final SecureDataViewModel _secureDataViewModel;

  LoginViewModel(this._secureDataViewModel);

  bool _signingIn = false;
  bool _disposed = false;
  bool get signingIn => _signingIn;

  Future<void> signIn(
    Function(User?) signInCallback, {
    bool staffPortal = false,
  }) async {
    if (_signingIn) return;
    _signingIn = true;
    notifyListeners();
    var localeProvider = Provider.of<LocaleProvider>(
      navigatorKey.currentContext!,
      listen: false,
    );
    try {
      UserCredential userCredential = await _authService.login(
        emailController.text.trim(),
        passwordController.text,
      );
      // await _secureDataViewModel.saveData(jsonEncode(userCredential.user));
      // signInCallback(userCredential.user);

      // Extract necessary fields from the user object
      final user = userCredential.user;
      if (user != null) {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!profile.exists) {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'profile-missing',
            message:
                'Your sign-in account exists, but its clinic profile is missing. Contact the Product Owner to restore access.',
          );
        }
        if ((profile.data()?['status'] ?? 'approved') != 'approved') {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'approval-pending',
            message: 'Your account is waiting for platform owner approval.',
          );
        }
        if (staffPortal && !acceptsStaffProfile(profile.data()!)) {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'wrong-portal',
            message:
                'Use the clinic login for this account. Staff access is assigned by your clinic administrator.',
          );
        }
        if (user.email != null && profile.data()?['email'] != user.email) {
          await profile.reference.update({
            'email': user.email,
            'email_normalized': user.email!.trim().toLowerCase(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        // Save user data securely
        await _secureDataViewModel.saveData(
          user.uid,
          user.email ?? '',
          user.displayName ?? '',
          user.photoURL ?? '',
          user.phoneNumber ?? '',
        );

        // Notify UI of successful login
        signInCallback(user);
      }
    } catch (e, stacktrace) {
      debugPrint(stacktrace.toString());
      await FirebaseAuth.instance.signOut();
      await _secureDataViewModel.clearData();
      if (_disposed || navigatorKey.currentContext?.mounted != true) return;

      final message =
          e is FirebaseAuthException &&
              [
                'approval-pending',
                'profile-missing',
                'wrong-portal',
              ].contains(e.code)
          ? RevampLabels.of(navigatorKey.currentContext!).text(switch (e.code) {
              'wrong-portal' => 'wrongPortal',
              'profile-missing' => 'profileMissing',
              _ => 'approvalPending',
            })
          : AppLocalizations.of(
              navigatorKey.currentContext!,
            )!.userAuthenticationFailed;
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(
            navigatorKey.currentContext!,
          ).colorScheme.error,
          content: CommonText(
            text: message,
            style:
                AppTextStyles.getRegularTextStyle(
                  localeProvider.locale,
                  fontSize: 15,
                ).copyWith(
                  color: Theme.of(
                    navigatorKey.currentContext!,
                  ).colorScheme.onError,
                ),
          ),
        ),
      );
    } finally {
      _signingIn = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool validateForm(GlobalKey<FormState> formKey) {
    return formKey.currentState?.validate() ?? false;
  }

  @override
  void dispose() {
    _disposed = true;
    emailController.dispose();
    passwordController.dispose();
    //_errorController.close();
    super.dispose();
  }
}
