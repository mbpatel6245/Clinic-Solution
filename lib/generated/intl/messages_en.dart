// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "appTitle": MessageLookupByLibrary.simpleMessage("My Flutter App"),
        "appointments": MessageLookupByLibrary.simpleMessage("Appointments"),
        "email": MessageLookupByLibrary.simpleMessage("Email"),
        "emailRequired":
            MessageLookupByLibrary.simpleMessage("Email is required"),
        "errorMessage":
            MessageLookupByLibrary.simpleMessage("An error occurred."),
        "forgotPassword":
            MessageLookupByLibrary.simpleMessage("Forgot Password?"),
        "forgotPasswordLabel":
            MessageLookupByLibrary.simpleMessage("Forgot Password"),
        "login": MessageLookupByLibrary.simpleMessage("Login"),
        "logout": MessageLookupByLibrary.simpleMessage("Logout"),
        "name": MessageLookupByLibrary.simpleMessage("Name"),
        "nameRequired": MessageLookupByLibrary.simpleMessage("Name required"),
        "newPrescription":
            MessageLookupByLibrary.simpleMessage("New Prescription"),
        "newUserRegister":
            MessageLookupByLibrary.simpleMessage("New User Register"),
        "password": MessageLookupByLibrary.simpleMessage("Password"),
        "passwordRequired":
            MessageLookupByLibrary.simpleMessage("Password is required"),
        "phone": MessageLookupByLibrary.simpleMessage("Phone"),
        "phoneRequired":
            MessageLookupByLibrary.simpleMessage("Phone number is required"),
        "prescriptionList":
            MessageLookupByLibrary.simpleMessage("Prescription list"),
        "register": MessageLookupByLibrary.simpleMessage("Register"),
        "registerSuccessfully":
            MessageLookupByLibrary.simpleMessage("Registered successfully!"),
        "role": MessageLookupByLibrary.simpleMessage("Role"),
        "roleRequired":
            MessageLookupByLibrary.simpleMessage("Role is required"),
        "sendResetEmail":
            MessageLookupByLibrary.simpleMessage("Send Reset email"),
        "stockInward": MessageLookupByLibrary.simpleMessage("Stock Inward"),
        "userAuthenticationFailed": MessageLookupByLibrary.simpleMessage(
            "User authentication failed. Please try again!"),
        "validEmail":
            MessageLookupByLibrary.simpleMessage("Enter a valid email"),
        "validPassword": MessageLookupByLibrary.simpleMessage(
            "Password must be at least 6 characters"),
        "validPhone": MessageLookupByLibrary.simpleMessage(
            "Enter a valid 10-digit phone number"),
        "welcomeMessage":
            MessageLookupByLibrary.simpleMessage("Welcome to the app!")
      };
}
