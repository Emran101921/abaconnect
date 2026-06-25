import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../data/job_opportunities_repository.dart';

class AdminMarketplaceAdminScreen extends ConsumerStatefulWidget {
  const AdminMarketplaceAdminScreen({super.key, this.initialSearchQuery});

  final String? initialSearchQuery;

  @override
  ConsumerState<AdminMarketplaceAdminScreen> createState() =>
      _AdminMarketplaceAdminScreenState();
}

class _AdminMarketplaceAdminScreenState
    extends ConsumerState<AdminMarketplaceAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pause(String jobId) async {
    try {
      await ref
          .read(jobOpportunitiesRepositoryProvider)
          .adminPauseJob(jobId, reason: 'Paused by admin');
      ref.invalidate(adminJobOpportunitiesProvider);
      if (mounted) AppSnackBar.showSuccess(context, 'Posting paused');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _remove(String jobId) async {
    try {
      await ref.read(jobOpportunitiesRepositoryProvider).adminRemoveJob(
            jobId,
            'Removed by platform admin',
          );
      ref.invalidate(adminJobOpportunitiesProvider);
      if (mounted) AppSnackBar.showSuccess(context, 'Posting removed');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(adminJobOpportunitiesProvider);
    final audit = ref.watch(adminJobMarketplaceAuditProvider);
    final dateFmt = DateFormat.yMMMd().add_jm();

    return AppScaffold(
      title: 'Marketplace Admin',
      subtitle: 'Job opportunity moderation & audit',
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Job postings'),
              Tab(text: 'Audit log'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                jobs.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (rows) => RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(adminJobOpportunitiesProvider),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        AppDataTable<JobOpportunityModel>(
                          rows: rows,
                          initialSearchQuery: widget.initialSearchQuery,
                          searchPredicate: (job, q) {
                            final needle = q.toLowerCase();
                            return job.title.toLowerCase().contains(needle) ||
                                (job.agencyName ?? '')
                                    .toLowerCase()
                                    .contains(needle) ||
                                job.status.toLowerCase().contains(needle) ||
                                job.serviceTypeLabel
                                    .toLowerCase()
                                    .contains(needle);
                          },
                          columns: [
                            AppDataColumn(
                              label: 'Title',
                              mobilePriority: true,
                              cellBuilder: (context, job) => Text(job.title),
                            ),
                            AppDataColumn(
                              label: 'Agency',
                              cellBuilder: (context, job) =>
                                  Text(job.agencyName ?? '—'),
                            ),
                            AppDataColumn(
                              label: 'Status',
                              mobilePriority: true,
                              cellBuilder: (context, job) => AppStatusBadge(
                                label: job.status.replaceAll('_', ' '),
                              ),
                            ),
                            AppDataColumn(
                              label: 'Apps',
                              cellBuilder: (context, job) =>
                                  Text('${job.applicationCount ?? 0}'),
                            ),
                          ],
                          actionsBuilder: (context, job) => Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _pause(job.id),
                                child: const Text('Pause'),
                              ),
                              TextButton(
                                onPressed: () => _remove(job.id),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                audit.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (rows) => RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(adminJobMarketplaceAuditProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final log = rows[index];
                        return ListTile(
                          title: Text(log.eventType),
                          subtitle: Text(
                            '${log.entityType} · ${log.actorName ?? 'System'} · '
                            '${dateFmt.format(log.createdAt.toLocal())}',
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
