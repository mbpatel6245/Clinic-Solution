import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'encryption_service.dart';

class SecureDataViewModel extends ChangeNotifier {
  //final EncryptionService _encryptionService = EncryptionService();
  //String _storedData = '';

  //String get storedData => _storedData;
  static const String PREF_UID_KEY = "UID";
  static const String PREF_EMAIL_KEY = "EMAIL";
  static const String PREF_DISPLAYNAME_KEY = "DISPLAY_NAME";
  static const String PREF_PHOTOURL_KEY = "PHOTO_URL";
  static const String PREF_PHONE_NUMBER_KEY = "PHONE_NUMBER";

  // Save encrypted data
  Future<void> saveData(String uid, String email, String displayName,
      String photoURL, String phoneNumber) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    //String encryptedData = _encryptionService.encryptData(data);
    await prefs.setString(PREF_UID_KEY, uid);
    await prefs.setString(PREF_EMAIL_KEY, email);
    await prefs.setString(PREF_DISPLAYNAME_KEY, displayName);
    await prefs.setString(PREF_PHOTOURL_KEY, photoURL);
    await prefs.setString(PREF_PHONE_NUMBER_KEY, phoneNumber);

    notifyListeners(); // Notify UI to update the stored data
  }

  Future<String?> getUID() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
   return prefs.getString(PREF_UID_KEY);
  }

  Future<String?> getEmail() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(PREF_EMAIL_KEY);
  }

  Future<String?> getDisplayName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(PREF_DISPLAYNAME_KEY);
  }

  Future<String?> getPhotoUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(PREF_PHOTOURL_KEY);
  }

  Future<String?> getPhoneNumber() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(PREF_PHONE_NUMBER_KEY);
  }

  // Clear stored data
  Future<void> clearData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(PREF_UID_KEY);
    await prefs.remove(PREF_EMAIL_KEY);
    await prefs.remove(PREF_DISPLAYNAME_KEY);
    await prefs.remove(PREF_PHOTOURL_KEY);
    await prefs.remove(PREF_PHONE_NUMBER_KEY);
  }
}
