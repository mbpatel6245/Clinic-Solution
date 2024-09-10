import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/locale_provider.dart';
import '../../../main.dart';
import '../../themes/text_styles.dart';

class LoginViewModel with ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signIn(Function(User?) signInCallback) async {
    var localeProvider = Provider.of<LocaleProvider>(
        navigatorKey.currentContext!,
        listen: false);
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      signInCallback(userCredential.user);
    } catch (e, stacktrace) {
      print(stacktrace.toString());

      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(SnackBar(
        content: Text(
            AppLocalizations.of(navigatorKey.currentContext!)!
                .userAuthenticationFailed,
            style: AppTextStyles.getRegularTextStyle(localeProvider.locale)
                .copyWith(color: Colors.white)),
      ));
    }
  }

  bool validateForm(GlobalKey<FormState> formKey) {
    return formKey.currentState?.validate() ?? false;
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    //_errorController.close();
  }
}
