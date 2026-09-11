import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/locale_provider.dart';
import '../../../main.dart';
import '../../../services/auth_services.dart';
import '../../../services/local/secure_data_viewmodel.dart';
import '../../themes/text_styles.dart';
import '../../widgets/common_text.dart';

class LoginViewModel with ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final SecureDataViewModel _secureDataViewModel;

  LoginViewModel(this._secureDataViewModel);

  Future<void> signIn(Function(User?) signInCallback) async {
    var localeProvider = Provider.of<LocaleProvider>(
      navigatorKey.currentContext!,
      listen: false,
    );
    try {
      UserCredential userCredential = await _authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
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
        if (profile.data()?['status'] == 'pending') {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'approval-pending',
            message: 'Your account is waiting for platform owner approval.',
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

      final message = e is FirebaseAuthException && e.code == 'approval-pending'
          ? e.message!
          : AppLocalizations.of(
              navigatorKey.currentContext!,
            )!.userAuthenticationFailed;
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: CommonText(
            text: message,
            style: AppTextStyles.getRegularTextStyle(
              localeProvider.locale,
            ).copyWith(color: Colors.white),
          ),
        ),
      );
    }
  }

  bool validateForm(GlobalKey<FormState> formKey) {
    return formKey.currentState?.validate() ?? false;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    //_errorController.close();
    super.dispose();
  }
}
