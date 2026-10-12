// Run: flutter test tool/export_brand_test.dart
// All platform icons are rendered from the same vector painter as the app.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/core/design/clinic_brand.dart';
import 'package:clinic_solution/core/design/app_theme.dart';

Future<Uint8List> render(
  int size, {
  bool opaque = false,
  bool maskable = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (opaque || maskable) canvas.drawColor(AppColors.primary, BlendMode.src);
  final inset = maskable ? size * .16 : 0.0;
  canvas.translate(inset, inset);
  const ClinicLogoPainter().paint(canvas, Size.square(size - inset * 2));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

Future<void> save(
  String path,
  int size, {
  bool opaque = false,
  bool maskable = false,
}) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    await render(size, opaque: opaque, maskable: maskable),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export app brand assets from the shared vector', () async {
    await save('assets/brand/clinic-solution.png', 512);
    await save('web/favicon.png', 32);
    for (final size in [192, 512]) {
      await save('web/icons/Icon-$size.png', size);
      await save('web/icons/Icon-maskable-$size.png', size, maskable: true);
    }
    for (final platform in ['ios', 'macos']) {
      final dir = '$platform/Runner/Assets.xcassets/AppIcon.appiconset';
      final manifest = jsonDecode(
        await File('$dir/Contents.json').readAsString(),
      );
      for (final item in manifest['images']) {
        if (item['filename'] == null) continue;
        final points = double.parse((item['size'] as String).split('x').first);
        final scale = double.parse(
          (item['scale'] as String).replaceAll('x', ''),
        );
        await save(
          '$dir/${item['filename']}',
          (points * scale).round(),
          opaque: platform == 'ios',
        );
      }
    }
    for (final entry in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await save(
        'android/app/src/main/res/mipmap-${entry.key}/clinic_logo.png',
        entry.value,
      );
    }
    final png = await render(256);
    final header = ByteData(22)
      ..setUint16(2, 1, Endian.little)
      ..setUint16(4, 1, Endian.little)
      ..setUint16(10, 1, Endian.little)
      ..setUint16(12, 32, Endian.little)
      ..setUint32(14, png.length, Endian.little)
      ..setUint32(18, 22, Endian.little);
    await File(
      'windows/runner/resources/app_icon.ico',
    ).writeAsBytes([...header.buffer.asUint8List(), ...png]);
  });
}
