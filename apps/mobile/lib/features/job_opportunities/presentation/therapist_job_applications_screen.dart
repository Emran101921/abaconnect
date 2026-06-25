import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/application_status_badge.dart';

bool _canWithdrawApplication(String status) {
  return status != 'WITHDRAWN' &&
      status != 'REJECTED' &&
      status != 'HIRED_CONTRACTED';
}

class TherapistJobApplicationsScreen extends ConsumerStatefulWidget {
  const TherapistJobApplicationsScreen({super.key, this.initialSearchQuery});

  final String? initialSearchQuery;

  @override
  ConsumerState<TherapistJobApplicationsScreen> createState() =>
      _TherapistJobApplicationsScreenState();
}

class _TherapistJobApplicationsScreenState
    extends ConsumerState<TherapistJobApplicationsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<JobApplicationModel> _filterRows(List<JobApplicationModel> rows) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((app) {
      final haystack = [
        app.jobTitle,
        app.status,
        app.message,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _withdraw(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw application?'),
        content: const Text(
          'The agency will no longer see you as an active applicant for this role.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(jobOpportunitiesRepositoryProvider)
          .withdrawJobApplication(applicationId);
      ref.invalidate(therapistMyJobApplicationsProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Application withdrawn');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final applications = ref.watch(therapistMyJobApplicationsProvider);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return TherapistTabScaffold(
      title: 'My applications',
      subtitle: 'Track agency job applications you have submitted',
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(therapistMyJobApplicationsProvider),
        child: applications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              Center(child: Text('$e')),
            ],
          ),
          data: (rows) {
            final filtered = _filterRows(rows);
            if (rows.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 48),
                  Icon(
                    Icons.work_off_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No applications yet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse agency job opportunities and apply to roles that match your credentials.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: GlossyButton(
                      label: 'Browse opportunities',
                      onPressed: () =>
                          context.push(AppRoutes.therapistJobOpportunities),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search applications',
                    hintText: 'Job title or status…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  const Center(child: Text('No applications match your search.'))
                else
                  ...filtered.map(
                    (app) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DashboardCard(
                        onTap: app.jobOpportunityId.isNotEmpty
                            ? () => context.push(
                                  '${AppRoutes.therapistJobOpportunities}/${app.jobOpportunityId}',
                                )
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.jobTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Applied ${dateFormat.format(app.createdAt.toLocal())}',
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                ApplicationStatusBadge(status: app.status),
                              ],
                            ),
                            if (app.message != null &&
                                app.message!.trim().isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                app.message!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (_canWithdrawApplication(app.status)) ...[
                              const SizedBox(height: AppSpacing.md),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GlossyButton(
                                  label: 'Withdraw',
                                  size: GlossyButtonSize.small,
                                  variant: GlossyButtonVariant.secondary,
                                  onPressed: () =>
                                      _withdraw(ref, context, app.id),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
