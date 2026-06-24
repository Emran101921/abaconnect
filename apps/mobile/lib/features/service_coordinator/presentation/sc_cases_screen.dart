import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'sc_providers.dart';

class ScCasesScreen extends ConsumerWidget {
  const ScCasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(scDashboardProvider);

    return AppScaffold(
      title: 'My cases',
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: data.cases.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final c = data.cases[index];
            return Card(
              child: ListTile(
                title: Text(c.childName),
                subtitle: Text(c.parentName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '${AppRoutes.serviceCoordinatorHome}/cases/${c.childId}',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
