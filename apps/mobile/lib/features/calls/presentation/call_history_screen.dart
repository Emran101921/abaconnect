import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../call_providers.dart';
import '../data/call_models.dart';
import '../widgets/call_disclaimer.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key, this.childId, this.title = 'Call history'});

  final String? childId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(
      callHistoryProvider(CallHistoryParams(childId: childId, limit: 50)),
    );

    return AppScaffold(
      title: title,
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.calls),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
            callHistoryProvider(CallHistoryParams(childId: childId, limit: 50)),
          );
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const CallEmergencyDisclaimer(),
            const SizedBox(height: 8),
            history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(AppSnackBar.messageFromError(e)),
              data: (calls) {
                if (calls.isEmpty) {
                  return const Text('No calls yet.');
                }
                return Column(
                  children: calls.map((c) => _CallHistoryTile(call: c)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CallHistoryTile extends StatelessWidget {
  const _CallHistoryTile({required this.call});

  final CallSessionModel call;

  @override
  Widget build(BuildContext context) {
    final other = call.recipientName ?? call.initiatedByName;
    final statusLabel = call.isMissed
        ? 'Missed'
        : call.status.name.replaceAll('_', ' ').toLowerCase();
    final duration = call.durationSeconds != null
        ? '${call.durationSeconds}s'
        : null;
    final icon = call.callType == CallType.VIDEO
        ? Icons.videocam_outlined
        : Icons.call_outlined;

    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: call.isMissed
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(other),
        subtitle: Text(
          [
            statusLabel,
            DateFormat.yMMMd().add_jm().format(call.createdAt),
            if (duration != null) duration,
          ].join(' · '),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class AgencyCallAuditScreen extends ConsumerStatefulWidget {
  const AgencyCallAuditScreen({super.key});

  @override
  ConsumerState<AgencyCallAuditScreen> createState() =>
      _AgencyCallAuditScreenState();
}

class _AgencyCallAuditScreenState extends ConsumerState<AgencyCallAuditScreen> {
  String? _statusFilter;
  String? _callTypeFilter;

  @override
  Widget build(BuildContext context) {
    final params = AgencyAuditParams(
      status: _statusFilter,
      callType: _callTypeFilter,
      limit: 100,
    );
    final logs = ref.watch(agencyCallAuditProvider(params));

    return AppScaffold(
      title: 'Call audit log',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(agencyCallAuditProvider(params)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Metadata only — no call content is stored.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Missed'),
                  selected: _statusFilter == 'MISSED',
                  onSelected: (v) => setState(
                    () => _statusFilter = v ? 'MISSED' : null,
                  ),
                ),
                FilterChip(
                  label: const Text('Ended'),
                  selected: _statusFilter == 'ENDED',
                  onSelected: (v) => setState(
                    () => _statusFilter = v ? 'ENDED' : null,
                  ),
                ),
                FilterChip(
                  label: const Text('Audio'),
                  selected: _callTypeFilter == 'AUDIO',
                  onSelected: (v) => setState(
                    () => _callTypeFilter = v ? 'AUDIO' : null,
                  ),
                ),
                FilterChip(
                  label: const Text('Video'),
                  selected: _callTypeFilter == 'VIDEO',
                  onSelected: (v) => setState(
                    () => _callTypeFilter = v ? 'VIDEO' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            logs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(AppSnackBar.messageFromError(e)),
              data: (items) {
                if (items.isEmpty) return const Text('No audit events.');
                return Column(
                  children: items
                      .map(
                        (log) => Card(
                          child: ListTile(
                            title: Text(log.eventType.replaceAll('_', ' ')),
                            subtitle: Text(
                              [
                                log.actorRole,
                                if (log.reason != null) log.reason!,
                                DateFormat.yMMMd()
                                    .add_jm()
                                    .format(log.createdAt),
                              ].join(' · '),
                            ),
                            isThreeLine: log.reason != null,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
