import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:clinic_solution/core/design/app_theme.dart';
import 'package:clinic_solution/core/design/revamp_labels.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:clinic_solution/ui/views/home/revamp/practice_dashboard.dart';
import 'package:clinic_solution/ui/views/home/revamp/queue_workspace.dart';
import 'package:clinic_solution/ui/views/home/revamp/workspace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {String language = 'en', double scale = 1}) =>
    MaterialApp(
      theme: AppTheme.forLocale(Locale(language)),
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    );

void main() {
  for (final language in ['en', 'hi', 'gu']) {
    for (final width in [320.0, 768.0, 1440.0]) {
      testWidgets('$language dashboard at $width with large text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            PracticeDashboardView(
              available: AppFeature.values.toSet(),
              onOpen: (_) {},
              now: DateTime(2026, 10, 19),
            ),
            language: language,
            scale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final label = RevampLabels(language).text('hide');
        await tester.ensureVisible(find.byTooltip(label));
        await tester.tap(find.byTooltip(label));
        await tester.pumpAndSettle();
        expect(find.text('••••'), findsNWidgets(6));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('quick actions only expose available features', (tester) async {
    AppFeature? opened;
    await tester.pumpWidget(
      app(
        PracticeDashboardView(
          available: const {AppFeature.dashboard, AppFeature.appointments},
          onOpen: (f) => opened = f,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Registered patients'), findsNothing);
    expect(find.text('Payments'), findsNothing);
    await tester.ensureVisible(find.text('Book appointment'));
    await tester.tap(find.text('Book appointment'));
    expect(opened, AppFeature.appointments);
  });
  testWidgets('queue actions operate on selected real record', (tester) async {
    String? action;
    final now = DateTime(2026, 10, 19);
    await tester.pumpWidget(
      app(
        QueueWorkspace(
          items: [
            AppointmentModel(
              id: 'one',
              patientName: 'Sample Patient',
              phone: '',
              scheduledAt: now,
              status: 'confirmed',
            ),
          ],
          now: now,
          canPrescribe: true,
          onAction: (item, value) async {
            expect(item.id, 'one');
            action = value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start consultation'));
    await tester.tap(find.text('Start consultation'));
    await tester.pumpAndSettle();
    expect(action, 'prescribe');
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('Sample Patient'), findsNothing);
    expect(find.text('No patients in this queue.'), findsOneWidget);
  });
  testWidgets('workspace delays unused pages and keeps a visited form alive', (
    tester,
  ) async {
    var builds = 0;
    Widget pages(AppFeature selected) => app(
      LazyWorkspacePages(
        features: const [AppFeature.dashboard, AppFeature.patients],
        selected: selected,
        pages: [
          const TextField(),
          Builder(
            builder: (_) {
              builds++;
              return const Text('Directory');
            },
          ),
        ],
      ),
    );
    await tester.pumpWidget(pages(AppFeature.dashboard));
    expect(builds, 0);
    await tester.enterText(find.byType(TextField), 'Unsaved draft');
    await tester.pumpWidget(pages(AppFeature.patients));
    expect(builds, 1);
    await tester.pumpWidget(pages(AppFeature.dashboard));
    expect(find.text('Unsaved draft'), findsOneWidget);
  });
}
