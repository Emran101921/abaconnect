import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/application_status_history_sheet.dart';
import '../widgets/application_status_badge.dart';
import '../widgets/job_credential_documents_summary.dart';
import '../widgets/job_interview_call.dart';
import '../widgets/job_offer_response.dart';
import '../widgets/job_offer_summary.dart';
import '../widgets/upcoming_interview_banner.dart';

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
  final Map<String, String> _statusOverrides = {};
  String? _processingOfferId;

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

  Future<void> _refreshCredentials(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
  ) async {
    try {
      await ref
          .read(jobOpportunitiesRepositoryProvider)
          .refreshApplicationCredentials(applicationId);
      ref.invalidate(therapistMyJobApplicationsProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Credentials submitted to agency');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _respondToOffer(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
    String jobOpportunityId, {
    required bool accept,
  }) async {
    setState(() => _processingOfferId = applicationId);
    final nextStatus = await respondToJobOfferWithFeedback(
      ref: ref,
      context: context,
      applicationId: applicationId,
      accept: accept,
    );
    if (mounted && nextStatus != null) {
      setState(() {
        _statusOverrides[applicationId] = nextStatus;
        _processingOfferId = null;
      });
      if (jobOpportunityId.isNotEmpty) {
        ref.invalidate(therapistJobOpportunityProvider(jobOpportunityId));
      }
    } else if (mounted) {
      setState(() => _processingOfferId = null);
    }
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
    final interviews = ref.watch(therapistJobInterviewsProvider);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return TherapistTabScaffold(
      title: 'My applications',
      subtitle: 'Track agency job applications you have submitted',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(therapistMyJobApplicationsProvider);
          ref.invalidate(therapistJobInterviewsProvider);
        },
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

            final interviewRows = interviews.maybeWhen(
              data: (items) => items,
              orElse: () => const <JobInterviewModel>[],
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                UpcomingInterviewBanner(
                  interviews: interviewRows,
                  role: UserRole.therapist,
                ),
                interviews.maybeWhen(
                  data: (items) {
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scheduled interviews',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...items.map(
                          (interview) => _TherapistInterviewTile(
                            interview: interview,
                            dateFormat: dateFormat,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
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
                    (app) {
                      final status = applicationStatusWithOverride(
                        applicationId: app.id,
                        apiStatus: app.status,
                        overrides: _statusOverrides,
                      );
                      final processingOffer = _processingOfferId == app.id;
                      return Padding(
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
                                ApplicationStatusBadge(status: status),
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
                            if (status == 'CREDENTIAL_REVIEW') ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'The agency requested updated credentials. Upload documents, then submit them here.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              JobCredentialDocumentsSummary(
                                documents: app.credentialDocuments,
                                dense: true,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        context.push(AppRoutes.documents),
                                    child: const Text('Upload documents'),
                                  ),
                                  GlossyButton(
                                    label: 'Submit credentials',
                                    size: GlossyButtonSize.small,
                                    onPressed: () => _refreshCredentials(
                                      ref,
                                      context,
                                      app.id,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (status == 'OFFER_SENT') ...[
                              const SizedBox(height: AppSpacing.sm),
                              JobOfferSummaryCard(
                                history: app.recentStatusHistory,
                                jobTitle: app.jobTitle,
                                dense: true,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: 8,
                                children: [
                                  GlossyButton(
                                    label: processingOffer
                                        ? 'Accepting…'
                                        : 'Accept offer',
                                    size: GlossyButtonSize.small,
                                    onPressed: processingOffer
                                        ? null
                                        : () => _respondToOffer(
                                              ref,
                                              context,
                                              app.id,
                                              app.jobOpportunityId,
                                              accept: true,
                                            ),
                                  ),
                                  TextButton(
                                    onPressed: processingOffer
                                        ? null
                                        : () => _respondToOffer(
                                              ref,
                                              context,
                                              app.id,
                                              app.jobOpportunityId,
                                              accept: false,
                                            ),
                                    child: const Text('Decline'),
                                  ),
                                ],
                              ),
                            ],
                            if (status == 'APPROVED') ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Offer accepted. The agency will finalize hiring.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ],
                            if (status == 'HIRED_CONTRACTED') ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'You are hired for this role. Check appointments for your first session.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                            if (app.recentStatusHistory.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => showApplicationStatusHistorySheet(
                                    context,
                                    title: '${app.jobTitle} · status history',
                                    history: app.recentStatusHistory,
                                  ),
                                  child: const Text('View status history'),
                                ),
                              ),
                            ],
                            if (_canWithdrawApplication(status)) ...[
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
                    );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TherapistInterviewTile extends ConsumerStatefulWidget {
  const _TherapistInterviewTile({
    required this.interview,
    required this.dateFormat,
  });

  final JobInterviewModel interview;
  final DateFormat dateFormat;

  @override
  ConsumerState<_TherapistInterviewTile> createState() =>
      _TherapistInterviewTileState();
}

class _TherapistInterviewTileState extends ConsumerState<_TherapistInterviewTile> {
  bool _busy = false;

  Future<void> _consent(bool value) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(jobOpportunitiesRepositoryProvider)
          .grantInterviewRecordingConsent(
            interviewId: widget.interview.id,
            consent: value,
          );
      ref.invalidate(therapistJobInterviewsProvider);
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          value ? 'Recording consent granted' : 'Recording consent declined',
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final join = await ref
          .read(jobOpportunitiesRepositoryProvider)
          .joinJobInterview(widget.interview.id);
      if (!mounted) return;
      openInterviewCall(
        context,
        callSessionFromInterviewJoin(
          join,
          localUserName: widget.interview.therapistName,
        ),
      );
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interview = widget.interview;
    final canJoin = interviewJoinWindowOpen(interview);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(interview.jobTitle, style: Theme.of(context).textTheme.titleSmall),
            Text('${interview.agencyName} · ${widget.dateFormat.format(interview.scheduledAt.toLocal())}'),
            if (interview.status == 'COMPLETED')
              Text(
                'Interview completed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            if (interview.recordingRequested &&
                !interview.therapistRecordingConsent) ...[
              const SizedBox(height: 8),
              const Text(
                'This agency requested to record the interview. Do you consent?',
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _consent(true),
                    child: const Text('Consent'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _consent(false),
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ],
            if (canJoin)
              GlossyButton(
                label: 'Join video interview',
                size: GlossyButtonSize.small,
                loading: _busy,
                onPressed: _busy ? null : _join,
              ),
          ],
        ),
      ),
    );
  }
}
