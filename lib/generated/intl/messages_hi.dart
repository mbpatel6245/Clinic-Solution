// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a hi locale. All the
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
  String get localeName => 'hi';

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "appTitle": MessageLookupByLibrary.simpleMessage("My Flutter App"),
        "email": MessageLookupByLibrary.simpleMessage("ईमेल"),
        "emailRequired":
            MessageLookupByLibrary.simpleMessage("ईमेल की जरूरत है"),
        "errorMessage":
            MessageLookupByLibrary.simpleMessage("एक त्रुटि पाई गई।"),
        "forgotPassword":
            MessageLookupByLibrary.simpleMessage("पासवर्ड भूल गए?"),
        "login": MessageLookupByLibrary.simpleMessage("लॉग इन करें"),
        "logout": MessageLookupByLibrary.simpleMessage("लॉग आउट"),
        "name": MessageLookupByLibrary.simpleMessage("नाम"),
        "nameRequired": MessageLookupByLibrary.simpleMessage("नाम आवश्यक"),
        "newUserRegister":
            MessageLookupByLibrary.simpleMessage("नया उपयोगकर्ता रजिस्टर"),
        "password": MessageLookupByLibrary.simpleMessage("पासवर्ड"),
        "passwordRequired":
            MessageLookupByLibrary.simpleMessage("पासवर्ड आवश्यक है"),
        "phone": MessageLookupByLibrary.simpleMessage("फ़ोन"),
        "phoneRequired":
            MessageLookupByLibrary.simpleMessage("फ़ोन नंबर आवश्यक है"),
        "register": MessageLookupByLibrary.simpleMessage("पंजीकरण करवाना"),
        "registerSuccessfully":
            MessageLookupByLibrary.simpleMessage("सफलतापूर्वक पंजीकृत!"),
        "role": MessageLookupByLibrary.simpleMessage("भूमिका"),
        "roleRequired":
            MessageLookupByLibrary.simpleMessage("भूमिका आवश्यक है"),
        "userAuthenticationFailed": MessageLookupByLibrary.simpleMessage(
            "उपयोगकर्ता प्रमाणीकरण विफल हुआ। कृपया पुनः प्रयास करें!"),
        "validEmail":
            MessageLookupByLibrary.simpleMessage("एक वैध ईमेल दर्ज करें"),
        "validPassword": MessageLookupByLibrary.simpleMessage(
            "पासवर्ड कम से कम ६ अंकों का होना चाहिए"),
        "validPhone": MessageLookupByLibrary.simpleMessage(
            "मान्य १०-अंकीय फ़ोन नंबर दर्ज करें"),
        "welcomeMessage":
            MessageLookupByLibrary.simpleMessage("ऐप में आपका स्वागत है!")
      };
}
