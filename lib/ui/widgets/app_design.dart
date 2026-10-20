import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.child, this.maxWidth = 1440});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding:
            AppBreakpoints.pagePadding(constraints.maxWidth) +
            const EdgeInsets.only(bottom: 96),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    ),
  );
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: AppColors.soft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              if (caption != null)
                Text(
                  caption!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Horizontally scrollable sections retain their labels on small screens and
/// with large Hindi/Gujarati text instead of squeezing or clipping them.
class WorkspaceTabs extends StatelessWidget {
  const WorkspaceTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.icons,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final List<IconData>? icons;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final (index, label) in labels.indexed)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Semantics(
              selected: index == selected,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: index == selected
                      ? AppColors.primary
                      : AppColors.inkMuted,
                  backgroundColor: index == selected
                      ? AppColors.soft
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                onPressed: () => onSelected(index),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icons != null) ...[
                      Icon(icons![index], size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(label),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minimumItemWidth = 230,
    this.spacing = AppSpacing.md,
  });

  final List<Widget> children;
  final double minimumItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count =
          ((constraints.maxWidth + spacing) / (minimumItemWidth + spacing))
              .floor()
              .clamp(1, children.length);
      final width = (constraints.maxWidth - spacing * (count - 1)) / count;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}
