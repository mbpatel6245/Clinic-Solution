import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/data/datasources/prescription_print_settings.dart';
import 'package:clinic_solution/services/prescription_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting());
  const patient = PatientModel(
    firstName: 'DEMO ONLY Patient',
    age: 35,
    email: 'private@example.invalid',
    abhaId: 'PRIVATE-IDENTIFIER',
    userId: 'private-user',
    allergies: ['DEMO ONLY allergy'],
  );
  test('print settings survive storage and malformed geometry is bounded', () {
    const settings = PrescriptionPrintSettings(
      layout: PrescriptionLayout.bordered,
      showVitals: false,
      clinicianName: 'Demo Doctor',
      marginMm: 20,
    );
    final restored = PrescriptionPrintSettings.fromMap(settings.toMap());
    expect(restored.layout, PrescriptionLayout.bordered);
    expect(restored.showVitals, false);
    expect(restored.marginMm, 20);
    final malformed = PrescriptionPrintSettings.fromMap({
      'font_size': double.nan,
      'margin_mm': -20,
      'layout': 'unknown',
    });
    expect(malformed.fontSize, 12);
    expect(malformed.marginMm, 12);
    expect(malformed.layout, PrescriptionLayout.classic);
  });
  test(
    'patient facing document whitelists fields and respects section switches',
    () {
      const record = PrescriptionModel(
        patient: patient,
        diagnoses: ['Demo diagnosis'],
        vitals: 'DEMO VITALS',
        advice: 'Visible advice',
        medicines: [
          MedicineLine(
            name: 'DEMO ONLY - not medication',
            instructions: 'Synthetic text',
          ),
        ],
      );
      final sections = PrescriptionDocument.sections(
        record,
        const PrescriptionPrintSettings(
          showDiagnoses: false,
          showVitals: false,
        ),
        'en',
      );
      final text = sections.map((v) => '${v.$1} ${v.$2}').join('\n');
      expect(text, contains('Visible advice'));
      expect(text, contains('DEMO ONLY - not medication'));
      for (final excluded in [
        'Demo diagnosis',
        'DEMO VITALS',
        'private@example.invalid',
        'PRIVATE-IDENTIFIER',
        'private-user',
      ]) {
        expect(text, isNot(contains(excluded)));
      }
    },
  );
  test(
    'real renderer creates paginated English Hindi Gujarati PDFs with complete content',
    () async {
      const texts = {
        'en':
            'DEMO ONLY. This is a synthetic document for layout review. No clinical treatment.',
        'hi':
            'केवल डेमो। यह कृत्रिम दस्तावेज़ प्रिंट की जाँच के लिए है। कोई चिकित्सीय उपचार नहीं।',
        'gu':
            'માત્ર ડેમો. આ કૃત્રિમ દસ્તાવેજ પ્રિન્ટની તપાસ માટે છે. કોઈ ચિકિત્સકીય સારવાર નથી.',
      };
      for (final (i, entry) in texts.entries.indexed) {
        final record = PrescriptionModel(
          patient: patient,
          visitDate: DateTime(2026, 10, 19),
          complaints: entry.value,
          diagnoses: ['DEMO ONLY - no diagnosis'],
          medicines: [
            for (var n = 0; n < 18; n++)
              MedicineLine(
                name: 'DEMO ONLY ${n + 1} - Not a medicine',
                instructions: entry.value,
              ),
          ],
          advice: '${entry.value}\nEND OF SYNTHETIC CONTENT',
          followUpDate: DateTime(2026, 10, 26),
        );
        final bytes = await PrescriptionDocument.build(
          record: record,
          clinic: const ClinicProfile(
            id: 'demo',
            name: 'DEMO ONLY Clinic',
            phone: '',
            address: 'Synthetic clinic for software review',
          ),
          settings: PrescriptionPrintSettings(
            layout: PrescriptionLayout.values[i],
            clinicianName: 'Demo clinician',
            footerNote: 'DEMO ONLY - Not valid for clinical use',
          ),
          language: entry.key,
        );
        expect(ascii.decode(bytes.take(4).toList()), '%PDF');
        expect(bytes.length, greaterThan(10000));
        if (Platform.environment['EXPORT_RX_SAMPLES'] == 'true') {
          final folder = Directory('build/revamp-review/pdfs');
          await folder.create(recursive: true);
          await File(
            '${folder.path}/prescription-${entry.key}.pdf',
          ).writeAsBytes(bytes);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
