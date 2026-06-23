import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/app_stat_card.dart';
import '../../../shared/widgets/glossy_button.dart';
import 'sc_providers.dart';

class ServiceCoordinatorDashboardScreen extends ConsumerWidget {
  const ServiceCoordinatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(scDashboardProvider);

    return AppScaffold(
      title: 'Service coordination',
      subtitle: 'Assigned cases and follow-ups',
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.home),
      actions: [
        IconButton(
          icon: const Icon(Icons.medical_information_outlined),
          tooltip: 'Charts',
          onPressed: () =>
              context.push('${AppRoutes.serviceCoordinatorHome}/charts'),
        ),
        IconButton(
          icon: const Icon(Icons.event_note_outlined),
          tooltip: 'Follow-ups',
          onPressed: () =>
              context.push('${AppRoutes.serviceCoordinatorHome}/follow-ups'),
        ),
        IconButton(
          icon: const Icon(Icons.message_outlined),
          tooltip: 'Messages',
          onPressed: () => context.push(AppRoutes.messages),
        ),
      ],
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(scDashboardProvider);
              await ref.read(scDashboardProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const AppTrustNotice(dense: true),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    AppStatCard(
                      label: 'Assigned cases',
                      value: '${data.totalCases}',
                      icon: Icons.folder_shared_outlined,
                    ),
                    AppStatCard(
                      label: 'Urgent',
                      value: '${data.urgentCases}',
                      icon: Icons.warning_amber_rounded,
                    ),
                    AppStatCard(
                      label: 'Screenings due',
                      value: '${data.screeningsDue}',
                      icon: Icons.assignment_outlined,
                    ),
                    AppStatCard(
                      label: 'Follow-ups due',
                      value: '${data.followUpsDue}',
                      icon: Icons.event_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                DashboardCard(
                  title: 'Assigned children',
                  child: data.cases.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No cases assigned yet.'),
                        )
                      : Column(
                          children: data.cases.map((c) {
                            final priorityColor = switch (c.priorityLevel) {
                              'HIGH' => Colors.red,
                              'MEDIUM' => Colors.orange,
                              _ => Colors.green,
                            };
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: c.isUrgent
                                  ? const Icon(
                                      Icons.priority_high,
                                      color: Colors.red,
                                    )
                                  : CircleAvatar(
                                      backgroundColor: priorityColor
                                          .withValues(alpha: 0.2),
                                      child: Text(
                                        c.priorityLevel.substring(0, 1),
                                        style:
                                            TextStyle(color: priorityColor),
                                      ),
                                    ),
                              title: Text(c.childName),
                              subtitle: Text(
                                '${c.parentName} · Screening: ${c.screeningStatus}'
                                '${c.nextFollowUpDate != null ? ' · Follow-up ${DateFormat.yMMMd().format(c.nextFollowUpDate!)}' : ''}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(
                                '${AppRoutes.serviceCoordinatorHome}/cases/${c.childId}',
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'View all cases',
                  icon: Icons.list_alt_rounded,
                  onPressed: () =>
                      context.push('${AppRoutes.serviceCoordinatorHome}/cases'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
