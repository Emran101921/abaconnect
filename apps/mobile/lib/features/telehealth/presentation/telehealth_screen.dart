import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../parent/presentation/parent_home_screen.dart';
import '../../platform/data/platform_repository.dart';

final telehealthSessionsProvider =
    FutureProvider<List<TelehealthSessionModel>>((ref) {
  return ref.watch(platformRepositoryProvider).fetchTelehealthSessions();
});

class TelehealthScreen extends ConsumerWidget {
  const TelehealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(telehealthSessionsProvider);
    final appointments = ref.watch(parentAppointmentsProvider);

    return AppScaffold(
      title: 'Telehealth',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(telehealthSessionsProvider);
          ref.invalidate(parentAppointmentsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Virtual sessions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create or open a video room. Set TELEHEALTH_VENDOR=daily or twilio '
              'on the API for vendor-hosted rooms; otherwise demo links are used.',
            ),
            const SizedBox(height: 16),
            sessions.when(
              data: (list) {
                if (list.isNotEmpty) {
                  return Column(
                    children: list.map((s) {
                      return Card(
                        child: ListTile(
                          title: Text(s.appointmentLabel ?? s.roomId),
                          subtitle: Text(
                            [
                              if (s.vendor != null) 'Vendor: ${s.vendor}',
                              s.joinUrl ?? 'Room ready',
                            ].join('\n'),
                          ),
                          isThreeLine: s.vendor != null,
                          trailing: FilledButton(
                            onPressed: s.joinUrl != null
                                ? () => _showRoomLink(context, s.joinUrl!)
                                : null,
                            child: const Text('Open'),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }
                return appointments.when(
                  data: (apts) {
                    if (apts.isEmpty) {
                      return const Text('No appointments to join.');
                    }
                    return Column(
                      children: apts.map((a) {
                        return Card(
                          child: ListTile(
                            title: Text(a.therapyType),
                            subtitle: Text('${a.childName} · ${a.status}'),
                            trailing: FilledButton(
                              onPressed: () => _join(context, ref, a.id),
                              child: const Text('Join'),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('$e'),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _join(
    BuildContext context,
    WidgetRef ref,
    String appointmentId,
  ) async {
    try {
      final room =
          await ref.read(platformRepositoryProvider).joinTelehealth(appointmentId);
      ref.invalidate(telehealthSessionsProvider);
      if (room.joinUrl != null && context.mounted) {
        _showRoomLink(context, room.joinUrl!);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Join failed: $e')),
        );
      }
    }
  }

  void _showRoomLink(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session link'),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied')),
              );
            },
            child: const Text('Copy link'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
