import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:clinic_solution/core/utils/locale_provider.dart';
import 'package:clinic_solution/ui/widgets/common_text.dart';

void main() {
  for (final height in <double?>[null, 40]) {
    testWidgets(
      'error text preserves explicit foreground with height $height',
      (tester) async {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => LocaleProvider(),
            child: MaterialApp(
              home: Scaffold(
                body: ColoredBox(
                  color: Colors.red.shade900,
                  child: CommonText(
                    text: 'Error',
                    height: height,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.widget<Text>(find.text('Error')).style?.color,
          Colors.white,
        );
      },
    );
  }
  testWidgets('explicit widget colour takes precedence over style colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: const MaterialApp(
          home: CommonText(
            text: 'Error',
            color: Colors.yellow,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('Error')).style?.color, Colors.yellow);
  });
}
