import 'package:clinic_solution/core/design/app_theme.dart';
import 'package:clinic_solution/core/utils/locale_provider.dart';
import 'package:clinic_solution/ui/widgets/common_button.dart';
import 'package:clinic_solution/ui/widgets/common_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final entry in {
    'hi': 'कृपया पुष्टि करें',
    'gu': 'કૃપા કરીને પુષ્ટિ કરો',
  }.entries) {
    testWidgets('${entry.key} fields grow for large text and validation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final family = entry.key == 'hi'
          ? 'Noto Sans Devanagari'
          : 'Noto Sans Gujarati';
      final asset = entry.key == 'hi'
          ? 'NotoSansDevanagari'
          : 'NotoSansGujarati';
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$asset.ttf'))).load();
      final provider = LocaleProvider()..setLocale(Locale(entry.key));
      final controller = TextEditingController(text: entry.value);
      addTearDown(controller.dispose);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.forLocale(Locale(entry.key)),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    children: [
                      CommonTextField(
                        controller: controller,
                        labelText: entry.value,
                        hintText: '',
                        validator: (_) => '${entry.value} ${entry.value}',
                      ),
                      CommonButton(text: entry.value, onPressed: () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byType(CommonTextField)).height;
      expect(before, greaterThan(55));
      form.currentState!.validate();
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(CommonTextField)).height,
        greaterThan(before),
      );
      expect(tester.getSize(find.byType(CommonButton)).height, greaterThan(55));
      expect(tester.takeException(), isNull);
      expect(
        Theme.of(
          tester.element(find.byType(CommonButton)),
        ).textTheme.bodyMedium!.fontFamily,
        family,
      );
    });
  }
}
