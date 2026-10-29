import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/core/design/uvilo_theme.dart';
import 'package:clinic_solution/shared/presentation/adaptive_workspace.dart';

const destinations = [
  WorkspaceDestination(
    id: 'patients',
    label: 'Patients',
    icon: Icons.people_outline,
  ),
  WorkspaceDestination(
    id: 'schedule',
    label: 'Schedule',
    icon: Icons.calendar_month_outlined,
  ),
  WorkspaceDestination(
    id: 'queue',
    label: 'Queue',
    icon: Icons.groups_outlined,
  ),
  WorkspaceDestination(
    id: 'reports',
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
  ),
  WorkspaceDestination(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
  ),
];

Widget preview({
  double scale = 1,
  List<WorkspaceDestination> items = destinations,
  String selected = 'patients',
  ValueChanged<String>? select,
  Key? capture,
}) => MaterialApp(
  theme: UviloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: RepaintBoundary(
    key: capture,
    child: AdaptiveWorkspace(
      destinations: items,
      selectedId: selected,
      onSelect: select ?? (_) {},
      title: 'Patient directory',
      clinicLabel: 'Demo clinic',
      actions: [
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add patient'),
        ),
      ],
      child: AdaptiveContent(
        primary: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Patients',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text('Manage your clinic’s patient directory.'),
                const SizedBox(height: 24),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Search patients',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 24),
                for (var i = 1; i <= 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Demo patient $i · Saved on this device'),
                  ),
              ],
            ),
          ),
        ),
        aside: const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_outlined),
                SizedBox(height: 16),
                Text('Offline'),
                SizedBox(height: 8),
                Text(
                  'Changes will synchronize when a connection is available.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final width in [320.0, 390.0, 600.0, 768.0, 960.0, 1200.0, 1512.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('layout $width at text scale $scale has no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(preview(scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byType(NavigationRail),
          scale == 1 && width >= 600 && width < 1200
              ? findsOneWidget
              : findsNothing,
        );
        expect(
          find.byType(NavigationBar),
          scale == 1 && width < 600 ? findsOneWidget : findsNothing,
        );
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'mobile More opens all allowed destinations and selects hidden route',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      await tester.pumpWidget(
        preview(selected: 'settings', select: (id) => selected = id),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Settings'));
      await tester.pumpAndSettle();
      expect(selected, 'settings');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('single allowed destination and empty access are safe', (
    tester,
  ) async {
    await tester.pumpWidget(preview(items: destinations.take(1).toList()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(preview(items: []));
    expect(find.text('No authorized workspace.'), findsOneWidget);
    expect(find.text('Add patient'), findsNothing);
  });

  testWidgets('short landscape viewport and keyboard inset remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 150);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(preview());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // Opt-in review artifacts; not brittle pixel-equality assertions.
  testWidgets('render foundation review artifacts', (tester) async {
    const render = bool.fromEnvironment('FOUNDATION_SCREENSHOTS');
    if (!render) return;
    final fonts = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await tester.runAsync(fonts.load);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    for (final width in [390.0, 768.0, 1512.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(preview(capture: key));
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final folder = Directory('build/foundation-review');
        await folder.create(recursive: true);
        await File(
          '${folder.path}/${width.toInt()}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    tester.view.reset();
  });
}
