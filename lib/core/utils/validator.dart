import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../main.dart';

class Validator {
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
      return AppLocalizations.of(navigatorKey.currentContext!)!
          .passwordRequired;
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

  String? validateName(String? value){
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(navigatorKey.currentContext!)!.nameRequired;
    }
    return null;
  }
}
