import 'dart:convert';
import 'package:encrypt/encrypt.dart';

class EncryptionService {
  final String _keyString = '32characterslongpassphrase!!!';  // Must be 32 chars for AES-256

  String encryptData(String data) {
    final key = Key.fromUtf8(_keyString);
    final iv = IV.fromSecureRandom(16);  // Initialization vector for AES
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    final encrypted = encrypter.encrypt(data, iv: iv);

    // Return encrypted data and IV concatenated (you can store them separately too)
    final combined = jsonEncode({
      'iv': iv.base64,          // Encode IV in base64
      'data': encrypted.base64  // Encrypted data in base64
    });

    return combined;  // Return combined IV and encrypted data as a JSON string
  }

  String decryptData(String encryptedData) {
    final key = Key.fromUtf8(_keyString);  // Create key from the key string

    // Decode the JSON string to get IV and encrypted data
    final Map<String, dynamic> decoded = jsonDecode(encryptedData);

    final iv = IV.fromBase64(decoded['iv']);  // Extract IV from base64
    final encryptedText = decoded['data'];    // Extract encrypted data

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    // Decrypt and return the original data
    final decrypted = encrypter.decrypt64(encryptedText, iv: iv);

    return decrypted;
  }
}
