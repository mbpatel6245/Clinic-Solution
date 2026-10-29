import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/features/clinical/presentation/prescription_review.dart';
import '../../tool/phase3_preview.dart';

void main() {
  for (final language in ['en', 'hi', 'gu']) {
    for (final width in [320.0, 768.0, 1512.0]) {
      for (final screen in [
        'record',
        'consultation',
        'review',
        'final-review',
        'signed',
      ]) {
        testWidgets('$screen $language at $width with 200 percent text', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            Phase3Preview(screen: screen, language: language, scale: 2),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (screen == 'review' || screen == 'final-review') {
            expect(find.byType(PrescriptionReview), findsOneWidget);
            final confirm = tester.widget<FilledButton>(
              find.byKey(const ValueKey('clinical-review-confirm')),
            );
            expect(confirm.onPressed, isNull);
            for (var i = 0; i < (screen == 'final-review' ? 4 : 3); i++) {
              final check = find.byKey(ValueKey('clinical-review-$i'));
              await tester.ensureVisible(check);
              await tester.tap(check);
              await tester.pumpAndSettle();
            }
            expect(
              tester
                  .widget<FilledButton>(
                    find.byKey(const ValueKey('clinical-review-confirm')),
                  )
                  .onPressed,
              isNotNull,
            );
            final first = find.byKey(const ValueKey('clinical-review-0'));
            await tester.ensureVisible(first);
            await tester.tap(first);
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<FilledButton>(
                    find.byKey(const ValueKey('clinical-review-confirm')),
                  )
                  .onPressed,
              isNull,
            );
          } else {
            // Exercise the full scrollable editor/record, not just the header.
            final scroller = find.byType(SingleChildScrollView).first;
            await tester.drag(scroller, const Offset(0, -2000));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
