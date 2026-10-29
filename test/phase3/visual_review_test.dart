import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/phase3_preview.dart';

void main() {
  testWidgets(
    'capture the synthetic clinical workspace for visual comparison',
    (tester) async {
      if (!const bool.fromEnvironment('PHASE3_SCREENSHOTS')) return;
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await tester.runAsync(font.load);
      await tester.runAsync(icons.load);
      for (final width in [390.0, 1512.0]) {
        tester.view.physicalSize = Size(width, 1244);
        tester.view.devicePixelRatio = 1;
        for (final screen in [
          'record',
          'consultation',
          'final-review',
          'signed',
        ]) {
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: Phase3Preview(screen: screen),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('build/phase3-review');
            await directory.create(recursive: true);
            await File(
              '${directory.path}/$screen-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      tester.view.reset();
    },
  );
}
