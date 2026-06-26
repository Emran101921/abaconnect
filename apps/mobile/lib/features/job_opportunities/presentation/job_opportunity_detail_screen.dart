import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/application_status_badge.dart';
import '../widgets/job_offer_response.dart';
import '../widgets/job_offer_summary.dart';
import '../widgets/phi_warning_banner.dart';

class JobOpportunityDetailScreen extends ConsumerStatefulWidget {
  const JobOpportunityDetailScreen({super.key, required this.jobOpportunityId});

  final String jobOpportunityId;

  @override
  ConsumerState<JobOpportunityDetailScreen> createState() =>
      _JobOpportunityDetailScreenState();
}

class _JobOpportunityDetailScreenState
    extends ConsumerState<JobOpportunityDetailScreen> {
  final _messageController = TextEditingController();
  bool _applying = false;
  bool _saving = false;
  bool _respondingToOffer = false;
  bool? _isSaved;
  String? _appliedStatus;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      final application = await ref
          .read(jobOpportunitiesRepositoryProvider)
          .applyToJobOpportunity(
            jobOpportunityId: widget.jobOpportunityId,
            message: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
          );
      if (mounted) {
        setState(() => _appliedStatus = application.status);
      }
      ref.invalidate(therapistJobOpportunityProvider(widget.jobOpportunityId));
      ref.invalidate(therapistMyJobApplicationsProvider);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Application submitted');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _respondToOffer(JobOpportunityModel job, {required bool accept}) async {
    final applicationId = job.myApplicationId;
    if (applicationId == null || applicationId.isEmpty) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Application not found. Open My applications to respond.',
        );
      }
      return;
    }

    setState(() => _respondingToOffer = true);
    final nextStatus = await respondToJobOfferWithFeedback(
      ref: ref,
      context: context,
      applicationId: applicationId,
      accept: accept,
    );
    if (mounted) {
      setState(() {
        _respondingToOffer = false;
        if (nextStatus != null) _appliedStatus = nextStatus;
      });
      ref.invalidate(therapistJobOpportunityProvider(widget.jobOpportunityId));
    }
  }

  Future<void> _toggleSaved(bool currentlySaved) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(jobOpportunitiesRepositoryProvider);
      if (currentlySaved) {
        await repo.unsaveJobOpportunity(widget.jobOpportunityId);
        if (mounted) {
          setState(() => _isSaved = false);
          AppSnackBar.showSuccess(context, 'Removed from saved jobs');
        }
      } else {
        await repo.saveJobOpportunity(widget.jobOpportunityId);
        if (mounted) {
          setState(() => _isSaved = true);
          AppSnackBar.showSuccess(context, 'Saved job');
        }
      }
      ref.invalidate(therapistSavedJobsProvider);
      ref.invalidate(therapistJobOpportunityProvider(widget.jobOpportunityId));
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _applicationStatus(JobOpportunityModel job) {
    return _appliedStatus ?? job.myApplicationStatus;
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync =
        ref.watch(therapistJobOpportunityProvider(widget.jobOpportunityId));
    final invitesAsync = ref.watch(therapistJobInvitesProvider);
    final myApplicationsAsync = ref.watch(therapistMyJobApplicationsProvider);

    return jobAsync.when(
      loading: () => const AppScaffold(
        title: 'Job opportunity',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Job opportunity',
        body: Center(child: Text(AppSnackBar.messageFromError(e))),
      ),
      data: (job) {
        if (job == null) {
          return const AppScaffold(
            title: 'Job opportunity',
            body: Center(child: Text('Opportunity not found')),
          );
        }

        final isSaved = _isSaved ?? job.isSaved ?? false;
        final invite = invitesAsync.maybeWhen(
          data: (invites) {
            try {
              return invites.firstWhere(
                (item) => item.jobOpportunityId == widget.jobOpportunityId,
              );
            } catch (_) {
              return null;
            }
          },
          orElse: () => null,
        );
        final applicationStatus = _applicationStatus(job);
        final myApplication = myApplicationsAsync.maybeWhen(
          data: (apps) {
            try {
              return apps.firstWhere(
                (app) => app.jobOpportunityId == widget.jobOpportunityId,
              );
            } catch (_) {
              return null;
            }
          },
          orElse: () => null,
        );
        final hasActiveApplication =
            applicationStatus != null && applicationStatus != 'WITHDRAWN';
        final canApply = job.status == 'PUBLISHED' && !hasActiveApplication;

        return AppScaffold(
          title: job.title,
          subtitle: job.agencyName ?? job.locationAreaLabel,
          actions: [
            IconButton(
              tooltip: isSaved ? 'Remove from saved' : 'Save job',
              onPressed: _saving ? null : () => _toggleSaved(isSaved),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                    ),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (invite != null) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('Agency invited you to apply'),
                    subtitle: Text(
                      '${invite.agencyName} invited you on '
                      '${invite.invitedAt.toLocal().toString().split('.').first}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              PhiWarningBanner(message: job.disclaimer),
              const SizedBox(height: 16),
              Text(
                job.serviceTypeLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (job.payRateDisplay != null) ...[
                const SizedBox(height: 8),
                Text('Pay: ${job.payRateDisplay}'),
              ],
              if (job.publicDescription != null) ...[
                const SizedBox(height: 16),
                Text(job.publicDescription!),
              ],
              if (hasActiveApplication) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Your application'),
                    const SizedBox(width: 8),
                    ApplicationStatusBadge(status: applicationStatus),
                  ],
                ),
                if (applicationStatus == 'OFFER_SENT') ...[
                  const SizedBox(height: 12),
                  myApplicationsAsync.when(
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (_, _) => JobOfferSummaryCard(
                      history: myApplication?.recentStatusHistory ?? const [],
                      jobTitle: job.title,
                      agencyName: job.agencyName,
                    ),
                    data: (_) => JobOfferSummaryCard(
                      history: myApplication?.recentStatusHistory ?? const [],
                      jobTitle: job.title,
                      agencyName: job.agencyName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GlossyButton(
                        label: _respondingToOffer ? 'Accepting…' : 'Accept offer',
                        onPressed: _respondingToOffer
                            ? null
                            : () => _respondToOffer(job, accept: true),
                      ),
                      GlossyButton(
                        label: 'Decline',
                        variant: GlossyButtonVariant.secondary,
                        onPressed: _respondingToOffer
                            ? null
                            : () => _respondToOffer(job, accept: false),
                      ),
                    ],
                  ),
                ] else if (applicationStatus == 'APPROVED') ...[
                  const SizedBox(height: 12),
                  Text(
                    'Offer accepted. The agency will finalize hiring.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                GlossyButton(
                  label: 'View my applications',
                  variant: GlossyButtonVariant.secondary,
                  onPressed: () => context.push(AppRoutes.therapistJobApplications),
                ),
              ] else if (canApply) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Application message (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  label: _applying ? 'Submitting…' : 'Apply',
                  onPressed: _applying ? null : _apply,
                ),
              ] else ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      job.status == 'PUBLISHED'
                          ? 'Unable to apply to this posting right now.'
                          : 'This job is no longer accepting applications.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
