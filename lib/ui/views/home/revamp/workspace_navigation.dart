import 'package:flutter/material.dart';
import '../../../../core/auth/app_role.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../core/design/clinic_brand.dart';
import '../../../../core/design/revamp_labels.dart';

class WorkspaceLink {
  const WorkspaceLink(this.feature, this.label, this.icon);
  final AppFeature feature;
  final String label;
  final IconData icon;
}

class WorkspaceSidebar extends StatefulWidget {
  const WorkspaceSidebar({
    super.key,
    required this.links,
    required this.selected,
    required this.onSelected,
    required this.clinicName,
  });
  final List<WorkspaceLink> links;
  final AppFeature selected;
  final ValueChanged<AppFeature> onSelected;
  final String clinicName;
  @override
  State<WorkspaceSidebar> createState() => _WorkspaceSidebarState();
}

class _WorkspaceSidebarState extends State<WorkspaceSidebar> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final l = RevampLabels.of(context);
    final groups = <String, Set<AppFeature>>{
      'practice': {
        AppFeature.dashboard,
        AppFeature.patients,
        AppFeature.reception,
        AppFeature.appointments,
        AppFeature.createPrescription,
        AppFeature.prescriptionList,
        AppFeature.prescriptionTemplates,
        AppFeature.treatmentPlans,
      },
      'operations': {
        AppFeature.inventory,
        AppFeature.vaccination,
        AppFeature.reminders,
        AppFeature.billing,
        AppFeature.finance,
        AppFeature.reports,
        AppFeature.laboratory,
        AppFeature.staffMessages,
      },
      'manage': {
        AppFeature.dataExchange,
        AppFeature.team,
        AppFeature.clinicSetup,
      },
    };
    return SizedBox(
      width: 256,
      child: Material(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const ClinicLogo(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'orByteza',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          ClinicBrand.name,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l.text('findTool'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final group in groups.entries) ...[
                    if (widget.links.any(
                      (e) =>
                          group.value.contains(e.feature) &&
                          e.label.toLowerCase().contains(_query),
                    ))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                        child: Text(
                          l.text(group.key),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.inkMuted,
                                letterSpacing: .6,
                              ),
                        ),
                      ),
                    for (final link in widget.links.where(
                      (e) =>
                          group.value.contains(e.feature) &&
                          e.label.toLowerCase().contains(_query),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          selected: widget.selected == link.feature,
                          selectedTileColor: AppColors.soft,
                          selectedColor: AppColors.primary,
                          leading: Icon(link.icon, size: 22),
                          title: Text(
                            link.label,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () => widget.onSelected(link.feature),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_hospital_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.clinicName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Only builds screens after first use, retaining forms when switching tools.
/// A clinic-scoped key at the call site drops all state on clinic change.
class LazyWorkspacePages extends StatefulWidget {
  const LazyWorkspacePages({
    super.key,
    required this.features,
    required this.selected,
    required this.pages,
  });
  final List<AppFeature> features;
  final AppFeature selected;
  final List<Widget> pages;
  @override
  State<LazyWorkspacePages> createState() => _LazyWorkspacePagesState();
}

class _LazyWorkspacePagesState extends State<LazyWorkspacePages> {
  final _visited = <AppFeature>{};
  @override
  Widget build(BuildContext context) {
    _visited.add(widget.selected);
    return IndexedStack(
      index: widget.features.indexOf(widget.selected),
      children: [
        for (var i = 0; i < widget.features.length; i++)
          KeyedSubtree(
            key: ValueKey(widget.features[i]),
            child: _visited.contains(widget.features[i])
                ? widget.pages[i]
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
