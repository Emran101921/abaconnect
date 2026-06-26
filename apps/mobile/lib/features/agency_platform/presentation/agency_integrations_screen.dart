import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'agency_platform_providers.dart';

class AgencyIntegrationsScreen extends ConsumerWidget {
  const AgencyIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(agencyIntegrationCatalogProvider);

    return AppScaffold(
      title: 'Integrations',
      subtitle: 'Clearinghouses, municipality systems, and payroll exports',
      showPageBreadcrumbs: true,
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DashboardCard(
                  title: item.label,
                  subtitle: item.category,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description),
                      const SizedBox(height: 8),
                      Text(
                        item.enabled ? 'Connected' : 'Available — configure in Admin settings',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
