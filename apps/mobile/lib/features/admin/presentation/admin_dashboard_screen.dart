import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../payments/data/billing_repository.dart';
import '../data/admin_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';

final adminDashboardProvider =
    FutureProvider<AdminDashboardModel>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchDashboard();
});

final adminUsersProvider = FutureProvider<List<AdminUserModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchUsers();
});

final pendingTherapistsProvider =
    FutureProvider<List<PendingTherapistModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchPendingTherapists();
});

final adminAuditLogsProvider = FutureProvider<List<AuditLogModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchAuditLogs();
});

final adminComplaintsProvider =
    FutureProvider<List<AdminComplaintModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchComplaints();
});

final adminPaymentDisputesProvider =
    FutureProvider<List<DisputeModel>>((ref) async {
  return ref.watch(billingRepositoryProvider).fetchAdminDisputes();
});

final adminPayoutsProvider = FutureProvider<List<PayoutModel>>((ref) async {
  return ref.watch(billingRepositoryProvider).fetchAdminPayouts();
});

final adminReviewsProvider =
    FutureProvider<List<AdminReviewModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchReviews();
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDashboardProvider);
    final pending = ref.watch(pendingTherapistsProvider);
    final users = ref.watch(adminUsersProvider);
    final audits = ref.watch(adminAuditLogsProvider);
    final complaints = ref.watch(adminComplaintsProvider);
    final paymentDisputes = ref.watch(adminPaymentDisputesProvider);
    final payouts = ref.watch(adminPayoutsProvider);
    final reviews = ref.watch(adminReviewsProvider);

    return AppScaffold(
      title: 'Admin Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await ref.read(authStateProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminDashboardProvider);
          ref.invalidate(pendingTherapistsProvider);
          ref.invalidate(adminUsersProvider);
          ref.invalidate(adminAuditLogsProvider);
          ref.invalidate(adminComplaintsProvider);
          ref.invalidate(adminPaymentDisputesProvider);
          ref.invalidate(adminPayoutsProvider);
          ref.invalidate(adminReviewsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            dashboard.when(
              data: (d) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(label: 'Users', value: d.userCount),
                  _StatCard(label: 'Parents', value: d.parentCount),
                  _StatCard(label: 'Therapists', value: d.therapistCount),
                  _StatCard(label: 'Appointments', value: d.appointmentCount),
                  _StatCard(
                    label: 'Pending verify',
                    value: d.pendingTherapists,
                    highlight: d.pendingTherapists > 0,
                  ),
                  _StatCard(label: 'Open complaints', value: d.openComplaints),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Dashboard error: $e'),
            ),
            const SizedBox(height: 24),
            Text(
              'Pending therapist verification',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            pending.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Card(
                    child: ListTile(title: Text('No pending verifications')),
                  );
                }
                return Column(
                  children: list.map((t) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(t.displayName),
                        subtitle: Text(
                          '${t.email}\n'
                          'License: ${t.licenseNumber ?? '—'} (${t.licenseState ?? '—'})',
                        ),
                        isThreeLine: true,
                        trailing: FilledButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(adminRepositoryProvider)
                                  .verifyTherapist(t.id);
                              ref.invalidate(pendingTherapistsProvider);
                              ref.invalidate(adminDashboardProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Verified ${t.displayName}'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Verify'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 24),
            Text(
              'Open complaints',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            complaints.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Card(
                    child: ListTile(title: Text('No open complaints')),
                  );
                }
                return Column(
                  children: list.map((c) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(c.subject),
                        subtitle: Text(
                          '${c.category} · ${c.reporterName ?? ''}\n${c.description}',
                        ),
                        isThreeLine: true,
                        trailing: TextButton(
                          onPressed: () async {
                            await ref.read(adminRepositoryProvider).resolveComplaint(
                                  c.id,
                                  'Resolved by admin',
                                );
                            ref.invalidate(adminComplaintsProvider);
                            ref.invalidate(adminDashboardProvider);
                          },
                          child: const Text('Resolve'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment disputes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            paymentDisputes.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Card(
                    child: ListTile(title: Text('No open payment disputes')),
                  );
                }
                return Column(
                  children: list.map((d) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(d.reason),
                        subtitle: Text('${d.status} · ${d.paymentId ?? ''}'),
                        trailing: TextButton(
                          onPressed: () async {
                            await ref
                                .read(billingRepositoryProvider)
                                .resolveDispute(d.id, 'Refunded per policy');
                            ref.invalidate(adminPaymentDisputesProvider);
                          },
                          child: const Text('Resolve'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 24),
            Text(
              'Therapist payouts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            payouts.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Card(
                    child: ListTile(title: Text('No payouts')),
                  );
                }
                return Column(
                  children: list.map((p) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('\$${p.amount.toStringAsFixed(2)}'),
                        subtitle: Text(p.status),
                        trailing: p.status != 'SUCCEEDED'
                            ? TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(billingRepositoryProvider)
                                      .markPayoutPaid(p.id);
                                  ref.invalidate(adminPayoutsProvider);
                                },
                                child: const Text('Mark paid'),
                              )
                            : const Icon(Icons.check, color: Colors.green),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 24),
            Text(
              'Review moderation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            reviews.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Card(
                    child: ListTile(title: Text('No reviews yet')),
                  );
                }
                return Column(
                  children: list.take(8).map((r) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${r.therapistName ?? 'Therapist'} · ${List.filled(r.rating.clamp(1, 5), '★').join()}',
                        ),
                        subtitle: Text(
                          '${r.authorEmail ?? ''}\n${r.comment ?? r.title ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: r.isPublished
                            ? TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(adminRepositoryProvider)
                                      .moderateReview(r.id, false);
                                  ref.invalidate(adminReviewsProvider);
                                },
                                child: const Text('Hide'),
                              )
                            : TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(adminRepositoryProvider)
                                      .moderateReview(r.id, true);
                                  ref.invalidate(adminReviewsProvider);
                                },
                                child: const Text('Publish'),
                              ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 24),
            Text(
              'Users',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            users.when(
              data: (list) => Column(
                children: list.take(10).map((u) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(u.fullName),
                      subtitle: Text('${u.email} · ${u.role}'),
                      trailing: Icon(
                        u.isActive ? Icons.check_circle_outline : Icons.block,
                      ),
                    ),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent audit logs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            audits.when(
              data: (list) => Column(
                children: list.map((log) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${log.action} · ${log.entityType}'),
                      subtitle: Text(
                        '${log.actorEmail ?? 'system'}\n'
                        '${DateFormat.yMMMd().add_jm().format(log.createdAt)}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        color: highlight
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
