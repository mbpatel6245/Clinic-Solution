import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:clinic_solution/core/design/app_theme.dart';
import 'package:clinic_solution/core/design/revamp_labels.dart';
import 'package:clinic_solution/data/datasources/clinical_models.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_workspace.dart';
import 'package:clinic_solution/ui/views/home/revamp/patient_registry.dart';
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
      home: child,
    );

void main() {
  final patient = PatientModel(
    id: 'one',
    firstName: 'Demo',
    phone: 'shared',
    age: 35,
    gender: 'other',
  );
  testWidgets(
    'timeline isolates patient IDs and opens the selected saved record',
    (tester) async {
      PrescriptionModel? selected;
      final visit = PrescriptionModel(
        id: 'own',
        patient: patient,
        visitDate: DateTime(2026, 10, 20),
        complaints: 'Own visit',
      );
      await tester.pumpWidget(
        app(
          PatientWorkspaceView(
            patient: patient,
            visits: [
              visit,
              PrescriptionModel(
                id: 'other',
                patient: PatientModel(
                  id: 'two',
                  firstName: 'Family',
                  phone: 'shared',
                ),
                complaints: 'Other person secret',
              ),
            ],
            onPreview: (v) => selected = v,
          ),
        ),
      );
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      expect(find.text('Own visit'), findsOneWidget);
      expect(find.text('Other person secret'), findsNothing);
      await tester.tap(find.byIcon(Icons.print_outlined));
      expect(selected?.id, 'own');
    },
  );
  testWidgets('switching patient tabs preserves consultation drafts', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        PatientWorkspaceView(
          patient: patient,
          consultation: const TextField(
            decoration: InputDecoration(labelText: 'Draft'),
          ),
          treatment: const Text('Treatment content'),
        ),
      ),
    );
    await tester.tap(find.text('Consultation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unfinished clinical draft');
    await tester.tap(find.text('Treatment plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consultation'));
    await tester.pumpAndSettle();
    expect(find.text('Unfinished clinical draft'), findsOneWidget);
  });
  testWidgets(
    'front desk presentation does not expose clinical tabs or visits',
    (tester) async {
      await tester.pumpWidget(
        app(
          PatientWorkspaceView(
            patient: patient,
            canReadHistory: false,
            visits: [
              PrescriptionModel(
                patient: patient,
                complaints: 'Restricted history',
              ),
            ],
          ),
        ),
      );
      expect(find.text('Timeline'), findsNothing);
      expect(find.text('Consultation'), findsNothing);
      expect(find.text('Restricted history'), findsNothing);
    },
  );
  for (final language in ['en', 'hi', 'gu']) {
    for (final width in [320.0, 768.0, 1440.0]) {
      testWidgets('$language patient workspace and navigation at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            PatientWorkspaceView(
              patient: patient,
              consultation: const Text('Consultation editor'),
              treatment: const Text('Plan editor'),
            ),
            language: language,
            scale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          app(
            Scaffold(
              body: PatientDirectoryList(
                patients: [patient],
                visits: const [],
                onOpen: (_) {},
              ),
            ),
            language: language,
            scale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Demo'), findsOneWidget);
        expect(tester.takeException(), isNull);
        AppFeature? selected;
        final l = RevampLabels(language);
        await tester.pumpWidget(
          app(
            Scaffold(
              bottomNavigationBar: PracticeNavigation(
                links: [
                  WorkspaceLink(
                    AppFeature.dashboard,
                    l.text('home'),
                    Icons.home_outlined,
                  ),
                  WorkspaceLink(
                    AppFeature.reception,
                    l.text('todayNav'),
                    Icons.list_alt_outlined,
                  ),
                  WorkspaceLink(
                    AppFeature.appointments,
                    l.text('bookNav'),
                    Icons.event_outlined,
                  ),
                  WorkspaceLink(
                    AppFeature.patients,
                    l.text('patients'),
                    Icons.people_outline,
                  ),
                ],
                selected: AppFeature.dashboard,
                onSelected: (f) => selected = f,
              ),
            ),
            language: language,
            scale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.text('patients')));
        expect(selected, AppFeature.patients);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
