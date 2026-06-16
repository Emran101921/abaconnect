import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'sc_providers.dart';

class ScFollowUpsScreen extends ConsumerWidget {
  const ScFollowUpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followUps = ref.watch(scFollowUpsProvider);

    return AppScaffold(
      title: 'Follow-up reminders',
      body: followUps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No follow-ups scheduled.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final f = list[index];
              return Card(
                color: f.overdue
                    ? Theme.of(context).colorScheme.errorContainer
                    : null,
                child: ListTile(
                  leading: Icon(
                    f.overdue ? Icons.warning_amber : Icons.event,
                    color: f.overdue ? Colors.red : null,
                  ),
                  title: Text(f.childName),
                  subtitle: Text('${f.type} · ${DateFormat.yMMMd().format(f.dueDate)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '${AppRoutes.serviceCoordinatorHome}/cases/${f.childId}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
