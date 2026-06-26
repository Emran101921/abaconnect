import 'package:flutter/material.dart';

import '../../../shared/widgets/app_scaffold.dart';

/// Reusable tabbed profile shell for client and provider management.
class ProfileTabScaffold extends StatelessWidget {
  const ProfileTabScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.tabLabels,
    required this.tabViews,
    this.actions,
    this.header,
  });

  final String title;
  final String? subtitle;
  final List<String>? tabLabels;
  final List<Widget> tabViews;
  final List<Widget>? actions;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final labels = tabLabels ?? const [];
    return DefaultTabController(
      length: tabViews.length,
      child: AppScaffold(
        title: title,
        subtitle: subtitle,
        showPageBreadcrumbs: true,
        actions: actions,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: header!,
              ),
            ],
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final label in labels) Tab(text: label),
              ],
            ),
            Expanded(
              child: TabBarView(children: tabViews),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder content for tabs not yet fully implemented.
class ProfileTabPlaceholder extends StatelessWidget {
  const ProfileTabPlaceholder({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.construction_outlined,
  });

  final String title;
  final String? description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(icon, size: 40, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          description ??
              'This section is part of the BloomOra agency platform. '
                  'Detailed workflows will be enabled as your agency modules are configured.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
