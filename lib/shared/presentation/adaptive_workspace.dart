import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/design/uvilo_theme.dart';

final class WorkspaceDestination {
  const WorkspaceDestination({
    required this.id,
    required this.label,
    required this.icon,
  });
  final String id, label;
  final IconData icon;
}

class UviloIdentity extends StatelessWidget {
  const UviloIdentity({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 3.5556,
            vertical: 3.1111,
          ),
          child: SvgPicture.asset(
            'assets/brand/uvilo-mark.svg',
            semanticsLabel: 'Uvilo logo',
          ),
        ),
      ),
      const SizedBox(width: 8),
      const Text(
        'Uvilo',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: UviloTheme.ink,
        ),
      ),
    ],
  );
}

/// The caller supplies only permitted destinations; server access is independent.
class AdaptiveWorkspace extends StatelessWidget {
  const AdaptiveWorkspace({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
    required this.title,
    required this.child,
    this.clinicLabel = '',
    this.actions = const [],
    this.figmaNavigation = false,
    this.navigationIconBuilder,
    this.workspaceLabel = '',
    this.footer,
  });
  final List<WorkspaceDestination> destinations;
  final String selectedId, title, clinicLabel;
  final ValueChanged<String> onSelect;
  final Widget child;
  final List<Widget> actions;
  final bool figmaNavigation;
  final Widget Function(String id)? navigationIconBuilder;
  final String workspaceLabel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty || !destinations.any((d) => d.id == selectedId)) {
      return const Scaffold(
        body: Center(child: Text('No authorized workspace.')),
      );
    }
    return LayoutBuilder(
      builder: (context, size) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final expanded = size.maxWidth >= 1200 && scale < 1.6;
        final rail =
            destinations.length > 1 &&
            size.maxWidth >= 600 &&
            !expanded &&
            size.maxHeight >= 600 &&
            scale < 1.6;
        final compact = !expanded && !rail;
        final selected = destinations.indexWhere((d) => d.id == selectedId);
        Widget menu(bool close) => SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: UviloIdentity(),
              ),
              if (clinicLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: figmaNavigation
                        ? BoxDecoration(
                            color: UviloTheme.canvas,
                            border: Border.all(color: UviloTheme.border),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: Text(
                      clinicLabel,
                      style: figmaNavigation
                          ? const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )
                          : null,
                    ),
                  ),
                ),
              if (workspaceLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Text(
                    workspaceLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: UviloTheme.muted,
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    for (final destination in destinations)
                      Padding(
                        padding: figmaNavigation
                            ? const EdgeInsets.fromLTRB(16, 0, 16, 6)
                            : EdgeInsets.zero,
                        child: ListTile(
                          minTileHeight: figmaNavigation ? 44 : null,
                          minLeadingWidth: figmaNavigation ? 18 : null,
                          titleTextStyle: figmaNavigation
                              ? TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: destination.id == selectedId
                                      ? Colors.white
                                      : UviloTheme.ink,
                                )
                              : null,
                          tileColor: figmaNavigation ? Colors.white : null,
                          shape: figmaNavigation
                              ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: destination.id == selectedId
                                        ? UviloTheme.primary
                                        : UviloTheme.border,
                                  ),
                                )
                              : null,
                          selected: destination.id == selectedId,
                          selectedTileColor: figmaNavigation
                              ? UviloTheme.primary
                              : UviloTheme.soft,
                          selectedColor: figmaNavigation
                              ? Colors.white
                              : UviloTheme.primary,
                          leading:
                              navigationIconBuilder?.call(destination.id) ??
                              Icon(destination.icon),
                          title: Text(destination.label),
                          onTap: () {
                            if (close) Navigator.of(context).pop();
                            onSelect(destination.id);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              if (footer != null)
                Padding(padding: const EdgeInsets.all(16), child: footer),
            ],
          ),
        );
        return Scaffold(
          drawer: compact
              ? Drawer(
                  child: Builder(
                    builder: (drawerContext) => SafeArea(
                      child: ListView(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: UviloIdentity(),
                          ),
                          for (final destination in destinations)
                            ListTile(
                              leading: Icon(destination.icon),
                              title: Text(destination.label),
                              selected: destination.id == selectedId,
                              onTap: () {
                                Navigator.pop(drawerContext);
                                onSelect(destination.id);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (expanded)
                  SizedBox(
                    width: 216,
                    child: Material(
                      color: figmaNavigation
                          ? const Color(0xFFEAF7F8)
                          : Colors.white,
                      child: menu(false),
                    ),
                  ),
                if (rail)
                  NavigationRail(
                    selectedIndex: selected,
                    onDestinationSelected: (index) =>
                        onSelect(destinations[index].id),
                    labelType: NavigationRailLabelType.none,
                    leading: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.local_hospital_outlined),
                    ),
                    destinations: destinations
                        .map(
                          (d) => NavigationRailDestination(
                            icon: Tooltip(
                              message: d.label,
                              child: Icon(d.icon),
                            ),
                            label: Text(d.label),
                          ),
                        )
                        .toList(),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: UviloTheme.border),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 24,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            if (compact)
                              Builder(
                                builder: (c) => IconButton(
                                  tooltip: 'Open navigation',
                                  onPressed: () => Scaffold.of(c).openDrawer(),
                                  icon: const Icon(Icons.menu),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (!compact) ...actions,
                          ],
                        ),
                      ),
                      if (compact && actions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: actions,
                          ),
                        ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar:
              compact &&
                  destinations.length > 1 &&
                  scale < 1.6 &&
                  MediaQuery.viewInsetsOf(context).bottom == 0
              ? Builder(
                  builder: (c) {
                    final visible = destinations.take(4).toList();
                    final extra = destinations.length > 4;
                    final index = visible.indexWhere((d) => d.id == selectedId);
                    return NavigationBar(
                      selectedIndex: index < 0 ? visible.length : index,
                      onDestinationSelected: (i) {
                        if (i == visible.length) {
                          Scaffold.of(c).openDrawer();
                        } else {
                          onSelect(visible[i].id);
                        }
                      },
                      destinations: [
                        for (final d in visible)
                          NavigationDestination(
                            icon: Icon(d.icon),
                            label: d.label,
                          ),
                        if (extra)
                          const NavigationDestination(
                            icon: Icon(Icons.more_horiz),
                            label: 'More',
                          ),
                      ],
                    );
                  },
                )
              : null,
        );
      },
    );
  }
}

class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({super.key, required this.primary, this.aside});
  final Widget primary;
  final Widget? aside;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final wide =
          size.maxWidth >= 1000 &&
          MediaQuery.textScalerOf(context).scale(14) < 23;
      return SingleChildScrollView(
        padding: EdgeInsets.all(size.maxWidth < 600 ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: wide && aside != null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: primary),
                      const SizedBox(width: 24),
                      Expanded(child: aside!),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primary,
                      if (aside != null) ...[
                        const SizedBox(height: 24),
                        aside!,
                      ],
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
