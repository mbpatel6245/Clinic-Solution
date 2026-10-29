import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/phase2_preview.dart';

void main() {
  testWidgets('render the synthetic operational workspace for visual review', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('PHASE2_SCREENSHOTS')) return;
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(font.load);
    await tester.runAsync(icons.load);
    for (final width in [390.0, 1512.0]) {
      tester.view.physicalSize = Size(width, 1244);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: const Phase2Preview()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Future<void> capture(String screen) async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/phase2-review');
          await directory.create(recursive: true);
          await File(
            '${directory.path}/$screen-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('directory');
      await tester.tap(find.text('Arjun Nair'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('profile');
      await tester.tap(find.text('Appointments').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('schedule');
      await tester.tap(find.text('Front desk').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('front-desk');
      await tester.tap(find.text('Check-in and queue').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('queue');
    }
    tester.view.reset();
  });
}
