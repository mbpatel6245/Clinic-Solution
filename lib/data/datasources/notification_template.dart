import 'dart:convert';
import 'package:flutter/services.dart';

class NotificationTemplateDefinition {
  NotificationTemplateDefinition(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get label => data['label'] as String;
  String get category => data['category'] as String;
  List<String> get variables => List<String>.from(data['variables'] as List);
  List<String> get requiredVariables =>
      List<String>.from(data['required'] as List);
  Map<String, dynamic> defaults(String channel, String locale) => {
    'event': id,
    'channel': channel,
    'locale': locale,
    'enabled': true,
    'subject': channel == 'email' ? data['email']['subject'] : '',
    'body': data[channel]['body'],
    'msg91_template_id': '',
    'twilio_template_id': '',
  };
  static Future<List<NotificationTemplateDefinition>> load() async {
    final json =
        jsonDecode(
              await rootBundle.loadString(
                'functions/src/template_catalog.json',
              ),
            )
            as List;
    return json
        .map(
          (item) => NotificationTemplateDefinition(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  String? validateContent(String text, {bool body = false}) {
    if (text.trim().isEmpty) {
      return 'Enter ${body ? 'a message' : 'a subject'}.';
    }
    final pattern = RegExp(r'\{\{\s*([a-z_]+)\s*\}\}');
    final names = pattern.allMatches(text).map((m) => m.group(1)!).toSet();
    if (names.any((name) => !variables.contains(name)) ||
        RegExp(r'[{}]').hasMatch(text.replaceAll(pattern, ''))) {
      return 'Use only the listed placeholders, with double braces.';
    }
    if (body && requiredVariables.any((name) => !names.contains(name))) {
      return 'Keep these required placeholders: ${requiredVariables.join(', ')}.';
    }
    return null;
  }
}

const templateSamples = {
  'patient_name': 'Priya Patel',
  'clinic_name': 'Green Care Clinic',
  'action_url': 'https://example.com/secure-link',
  'roles': 'Doctor',
  'approval_status': 'pending',
  'appointment_at': '24 Sep 2026, 10:30 am IST',
  'appointment_id': 'APT-1024',
  'message': 'Your next visit is tomorrow at 10:30 am.',
  'invoice_id': 'INV-1024',
  'amount': 'INR 500.00',
  'balance': 'INR 0.00',
};

String templatePreview(String text) => text.replaceAllMapped(
  RegExp(r'\{\{\s*([a-z_]+)\s*\}\}'),
  (match) => templateSamples[match.group(1)] ?? match.group(0)!,
);
