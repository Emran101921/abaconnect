import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';

final sessionHistoryProvider =
    FutureProvider<List<SessionHistoryModel>>((ref) {
  return ref.watch(parentBookingRepositoryProvider).fetchSessionHistory();
});

class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sessionHistoryProvider);

    return AppScaffold(
      title: 'Session History',
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No completed sessions yet'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sessionHistoryProvider);
              await ref.read(sessionHistoryProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final s = list[index];
                return Card(
                  child: ListTile(
                    title: Text('${s.therapyType} · ${s.childName}'),
                    subtitle: Text(
                      '${s.therapistName}\n'
                      '${s.completedAt != null ? DateFormat.yMMMd().add_jm().format(s.completedAt!) : 'In progress'}\n'
                      '${s.status}${s.durationMinutes != null ? ' · ${s.durationMinutes} min' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(label: Text(s.status)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
