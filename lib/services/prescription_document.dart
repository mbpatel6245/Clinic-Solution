import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/design/clinic_brand.dart';
import '../data/datasources/clinical_models.dart';
import '../data/datasources/enterprise_models.dart';
import '../data/datasources/prescription_print_settings.dart';

/// Flutter shapes each paragraph, including Indic conjuncts, before embedding
/// high-resolution PNGs. This avoids PDF codepoint-to-glyph shaping defects.
/// Clinical text is intentionally not searchable/copyable in this first export.
/// No external font, analytics, storage or translation service is called.
class PrescriptionDocument {
  static Future<void>? _fonts;
  static Future<void> _loadFonts() => _fonts ??= Future.wait([
    for (final (name, path) in [
      ('Rx Latin', 'assets/fonts/NotoSansRegular.ttf'),
      ('Rx Hindi', 'assets/fonts/NotoSansDevanagari.ttf'),
      ('Rx Gujarati', 'assets/fonts/NotoSansGujarati.ttf'),
    ])
      (FontLoader(name)..addFont(rootBundle.load(path))).load(),
  ]).then((_) {});

  /// Explicit patient-facing whitelist. Private clinician notes and identifiers
  /// such as ABHA, account UID, email and internal record IDs never enter output.
  static List<(String, String)> sections(
    PrescriptionModel record,
    PrescriptionPrintSettings settings,
    String language,
  ) {
    String label(String key) => labels[language]?[key] ?? labels['en']![key]!;
    return [
      if (record.clinicalState == 'signed' && record.clinicalVersion > 0)
        (label('signedVersion'), '${record.clinicalVersion}'),
      if (record.complaints.trim().isNotEmpty)
        (label('complaints'), record.complaints),
      if (settings.showDiagnoses && record.diagnoses.isNotEmpty)
        (label('diagnoses'), record.diagnoses.join(', ')),
      if (settings.showVitals && record.vitals.trim().isNotEmpty)
        (label('vitals'), record.vitals),
      for (final entry in record.medicines.where((v) => !v.isEmpty).indexed)
        (
          entry.$1 == 0 ? label('medicines') : '',
          '${entry.$1 + 1}. ${entry.$2.name}\n${[entry.$2.dosage, entry.$2.frequency, entry.$2.duration, entry.$2.instructions].where((v) => v.trim().isNotEmpty).join(' | ')}',
        ),
      if (record.investigation.trim().isNotEmpty)
        (label('tests'), record.investigation),
      if (record.advice.trim().isNotEmpty) (label('advice'), record.advice),
      if (record.followUpDate != null)
        (
          label('followUp'),
          DateFormat.yMMMd(language).format(record.followUpDate!),
        ),
    ];
  }

  static Future<Uint8List> build({
    required PrescriptionModel record,
    required ClinicProfile clinic,
    PrescriptionPrintSettings settings = const PrescriptionPrintSettings(),
    String language = 'en',
    String? documentTitle,
    List<(String, String)>? documentSections,
  }) async {
    if (record.clinicalState == 'signed' &&
        record.clinicalPrintContext.isNotEmpty) {
      final frozen = record.clinicalPrintContext;
      clinic = clinic.copyWith(
        name: frozen['name']?.toString() ?? clinic.name,
        phone: frozen['phone']?.toString() ?? '',
        address: frozen['address']?.toString() ?? '',
      );
      settings = PrescriptionPrintSettings.fromMap(frozen);
    }
    await _loadFonts();
    final locale = labels.containsKey(language) ? language : 'en';
    final content = documentSections ?? sections(record, settings, locale);
    // Refuse excessive data; never silently drop a medicine or clinical text.
    final totalCharacters =
        content.fold<int>(0, (total, entry) => total + entry.$2.length) +
        clinic.name.length +
        clinic.address.length +
        record.patient.fullName.length +
        clinic.phone.length +
        record.patient.phone.length +
        record.patient.gender.length +
        record.patient.allergies.join(', ').length +
        settings.clinicianName.length +
        settings.qualifications.length +
        settings.registration.length +
        settings.footerNote.length;
    if (totalCharacters > 50000 || record.medicines.length > 100) {
      throw StateError('Document is too large.');
    }
    final margin = settings.marginMm * PdfPageFormat.mm;
    final width = PdfPageFormat.a4.width - margin * 2;
    double renderedHeight = 0;
    Future<List<pw.Widget>> text(
      String value, {
      double? size,
      bool heading = false,
    }) async {
      final blocks = await _paragraphs(
        value,
        width,
        size ?? settings.fontSize,
        locale,
        heading,
      );
      renderedHeight += blocks.fold<double>(0, (sum, block) => sum + block.$2);
      if (renderedHeight > 8000) {
        throw StateError('Document is too large.');
      }
      return [
        for (final block in blocks)
          pw.Image(
            pw.MemoryImage(block.$1),
            width: width,
            height: block.$2,
            fit: pw.BoxFit.fill,
          ),
      ];
    }

    final header = await text(
      [
        clinic.name,
        if (settings.clinicianName.isNotEmpty) settings.clinicianName,
        if (settings.qualifications.isNotEmpty) settings.qualifications,
        if (settings.registration.isNotEmpty)
          '${labels[locale]!['registration']}: ${settings.registration}',
        if (clinic.phone.isNotEmpty) clinic.phone,
        if (clinic.address.isNotEmpty) clinic.address,
        '${labels[locale]!['patient']}: ${record.patient.fullName} | ${record.visitDate == null && record.createdAt == null ? '-' : DateFormat.yMMMd(locale).format(record.visitDate ?? record.createdAt!)}',
      ].join('\n'),
      size: 11,
    );
    if (header.length > 1 ||
        header.first is! pw.Image ||
        (header.first as pw.Image).height! > 145) {
      throw StateError('Letterhead is too tall. Shorten the header.');
    }
    final patient = await text(
      [
        '${labels[locale]!['patient']}: ${record.patient.fullName}',
        [
          if (record.patient.age != null)
            '${record.patient.age} ${ageUnits[locale]?[record.patient.ageUnit] ?? record.patient.ageUnit}',
          if (record.patient.gender.isNotEmpty) record.patient.gender,
          if (settings.showPhone && record.patient.phone.isNotEmpty)
            record.patient.phone,
        ].join(' | '),
        '${labels[locale]!['date']}: ${record.visitDate == null && record.createdAt == null ? '—' : DateFormat.yMMMd(locale).format(record.visitDate ?? record.createdAt!)}',
        if (record.patient.allergies.isNotEmpty)
          '${labels[locale]!['allergies']}: ${record.patient.allergies.join(', ')}',
      ].where((v) => v.isNotEmpty).join('\n'),
    );
    final body = <pw.Widget>[
      ...await text(
        documentTitle ?? labels[locale]!['title']!,
        size: 17,
        heading: true,
      ),
      pw.SizedBox(height: 12),
      ...patient,
      pw.SizedBox(height: 14),
    ];
    for (final entry in content) {
      final blocks = await text(
        '${entry.$1.isEmpty ? '' : '${entry.$1}\n'}${entry.$2}',
      );
      body.addAll([...blocks, pw.SizedBox(height: 14)]);
    }
    if (settings.footerNote.trim().isNotEmpty) {
      body.addAll(await text(settings.footerNote, size: 10));
    }
    final brandFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansRegular.ttf'),
    );
    final logo = await _logo();
    final pdf = pw.Document(
      title: documentTitle ?? 'Prescription',
      author: clinic.name,
      creator: 'orByteza Clinic Solution',
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(margin),
        maxPages: 40,
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 16),
          padding: const pw.EdgeInsets.all(8),
          decoration: settings.layout == PrescriptionLayout.minimal
              ? null
              : pw.BoxDecoration(
                  border: settings.layout == PrescriptionLayout.bordered
                      ? pw.Border.all(color: const PdfColor.fromInt(0xff087f83))
                      : const pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColor.fromInt(0xff087f83),
                            width: 2,
                          ),
                        ),
                ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (settings.layout != PrescriptionLayout.minimal) ...[
                pw.Image(pw.MemoryImage(logo), width: 36, height: 36),
                pw.SizedBox(width: 10),
              ],
              pw.Expanded(
                child: pw.Column(
                  children: [
                    for (final image in header) pw.FittedBox(child: image),
                  ],
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                ClinicBrand.copyright,
                style: pw.TextStyle(font: brandFont, fontSize: 7),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(font: brandFont, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => body,
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> _logo() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(3);
    const ClinicLogoPainter().paint(canvas, const ui.Size(40, 40));
    final picture = recorder.endRecording();
    final image = await picture.toImage(120, 120);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  static Future<List<(Uint8List, double)>> _paragraphs(
    String text,
    double width,
    double size,
    String language,
    bool heading,
  ) async {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontFamily: switch (language) {
                'hi' => 'Rx Hindi',
                'gu' => 'Rx Gujarati',
                _ => 'Rx Latin',
              },
              fontSize: size,
              height: 1.45,
              textDirection: ui.TextDirection.ltr,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              fontFamily: switch (language) {
                'hi' => 'Rx Hindi',
                'gu' => 'Rx Gujarati',
                _ => 'Rx Latin',
              },
              fontFamilyFallback: ['Rx Latin', 'Rx Hindi', 'Rx Gujarati'],
              color: heading
                  ? const ui.Color(0xff087f83)
                  : const ui.Color(0xff17383d),
            ),
          )
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    final lines = paragraph.computeLineMetrics();
    if (lines.length > 800) {
      paragraph.dispose();
      throw StateError('Paragraph is too long.');
    }
    final result = <(Uint8List, double)>[];
    double top = 0;
    while (top < paragraph.height) {
      // Split only between shaped lines, leaving descenders and vowel marks intact.
      final boundaries = lines
          .map((line) => line.baseline + line.descent + 2)
          .where((y) => y > top && y <= top + 420)
          .toList();
      final bottom = boundaries.isEmpty
          ? paragraph.height
          : (boundaries.last >= paragraph.height - 3
                ? paragraph.height
                : boundaries.last);
      final height = bottom - top;
      if (height <= 0 || height > 440) {
        paragraph.dispose();
        throw StateError('Paragraph cannot fit.');
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..scale(3)
        ..clipRect(ui.Rect.fromLTWH(0, 0, width, height));
      canvas.drawParagraph(paragraph, ui.Offset(0, -top));
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (width * 3).ceil(),
        (height * 3).ceil(),
      );
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      result.add((bytes!.buffer.asUint8List(), height));
      top = bottom;
    }
    paragraph.dispose();
    return result;
  }

  static const labels = {
    'en': {
      'title': 'Prescription',
      'patient': 'Patient',
      'date': 'Visit date',
      'allergies': 'Allergies',
      'registration': 'Registration',
      'signedVersion': 'Signed clinical version',
      'complaints': 'Presenting complaints',
      'diagnoses': 'Diagnosis',
      'vitals': 'Vitals',
      'medicines': 'Medicines',
      'tests': 'Investigations',
      'advice': 'Advice',
      'followUp': 'Follow-up',
    },
    'hi': {
      'title': 'प्रिस्क्रिप्शन',
      'patient': 'मरीज़',
      'date': 'मुलाकात की तारीख',
      'allergies': 'एलर्जी',
      'registration': 'पंजीकरण',
      'signedVersion': 'हस्ताक्षरित क्लिनिकल संस्करण',
      'complaints': 'मुख्य शिकायतें',
      'diagnoses': 'निदान',
      'vitals': 'शारीरिक माप',
      'medicines': 'दवाइयाँ',
      'tests': 'जाँच',
      'advice': 'सलाह',
      'followUp': 'अगली मुलाकात',
    },
    'gu': {
      'title': 'પ્રિસ્ક્રિપ્શન',
      'patient': 'દર્દી',
      'date': 'મુલાકાતની તારીખ',
      'allergies': 'એલર્જી',
      'registration': 'નોંધણી',
      'signedVersion': 'સહી કરેલ ક્લિનિકલ આવૃત્તિ',
      'complaints': 'મુખ્ય ફરિયાદો',
      'diagnoses': 'નિદાન',
      'vitals': 'શારીરિક માપ',
      'medicines': 'દવાઓ',
      'tests': 'તપાસ',
      'advice': 'સલાહ',
      'followUp': 'આગામી મુલાકાત',
    },
  };
  static const ageUnits = {
    'en': {
      'years': 'years',
      'months': 'months',
      'weeks': 'weeks',
      'days': 'days',
    },
    'hi': {
      'years': 'वर्ष',
      'months': 'महीने',
      'weeks': 'सप्ताह',
      'days': 'दिन',
    },
    'gu': {
      'years': 'વર્ષ',
      'months': 'મહિના',
      'weeks': 'અઠવાડિયા',
      'days': 'દિવસ',
    },
  };
}
