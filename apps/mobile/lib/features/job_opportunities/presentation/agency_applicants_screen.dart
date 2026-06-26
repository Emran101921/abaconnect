import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/application_status_badge.dart';
import '../widgets/application_status_history_sheet.dart';
import '../widgets/applicant_decision_dialogs.dart';
import '../widgets/invite_therapist_sheet.dart';
import '../widgets/job_credential_documents_summary.dart';
import '../widgets/job_interview_call.dart';
import '../widgets/schedule_first_session_sheet.dart';
import '../widgets/schedule_interview_sheet.dart';

class AgencyApplicantsScreen extends ConsumerWidget {
  const AgencyApplicantsScreen({super.key, required this.jobOpportunityId});

  final String jobOpportunityId;

  Future<void> _updateStatus(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
    String status,
  ) async {
    try {
      await ref.read(jobOpportunitiesRepositoryProvider).updateApplicationStatus(
            applicationId: applicationId,
            status: status,
          );
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      ref.invalidate(agencyHiringPipelineSummaryProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Status updated');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _scheduleInterview(
    WidgetRef ref,
    BuildContext context,
    JobApplicationModel app,
  ) async {
    final result = await showScheduleInterviewSheet(
      context,
      therapistName: app.therapistName,
    );
    if (result == null) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).scheduleJobInterview(
            applicationId: app.id,
            scheduledAt: result.scheduledAt,
            durationMinutes: result.durationMinutes,
            recordingRequested: result.recordingRequested,
            agencyRecordingConsent: result.agencyRecordingConsent,
            notes: result.notes,
          );
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      ref.invalidate(agencyHiringPipelineSummaryProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);
      ref.invalidate(agencyJobInterviewsProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Interview scheduled');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _requestCredentials(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
  ) async {
    final note = await showApplicantDecisionNoteDialog(
      context,
      title: 'Request credentials?',
      confirmLabel: 'Request',
      hint: 'What documents or licenses do you need?',
    );
    if (note == null || !context.mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).requestApplicationDocuments(
            applicationId: applicationId,
            note: note.isEmpty ? null : note,
          );
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      ref.invalidate(agencyHiringPipelineSummaryProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Credential review requested');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _approveCredentials(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
  ) async {
    final note = await showApplicantDecisionNoteDialog(
      context,
      title: 'Approve credentials?',
      confirmLabel: 'Approve',
      hint: 'Optional note for the applicant',
    );
    if (note == null || !context.mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).approveApplicationCredentials(
            applicationId: applicationId,
            note: note.isEmpty ? null : note,
          );
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      ref.invalidate(agencyHiringPipelineSummaryProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Credentials approved');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _rejectApplicant(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
  ) async {
    final note = await showApplicantDecisionNoteDialog(
      context,
      title: 'Reject applicant?',
      confirmLabel: 'Reject',
      hint: 'Optional reason shared with the therapist',
    );
    if (note == null || !context.mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).updateApplicationStatus(
            applicationId: applicationId,
            status: 'REJECTED',
            note: note.isEmpty ? 'Application not selected' : note,
          );
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      ref.invalidate(agencyHiringPipelineSummaryProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Applicant rejected');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _saveInterviewNotes(
    WidgetRef ref,
    BuildContext context,
    JobInterviewModel interview,
  ) async {
    final notes = await showInterviewNotesDialog(
      context,
      initialNotes: interview.notes,
      title: 'Interview notes',
    );
    if (notes == null || notes.isEmpty || !context.mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).updateInterviewNotes(
            interviewId: interview.id,
            notes: notes,
          );
      ref.invalidate(agencyJobInterviewsProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Interview notes saved');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _joinInterview(
    WidgetRef ref,
    BuildContext context,
    JobInterviewModel interview,
  ) async {
    try {
      final join = await ref
          .read(jobOpportunitiesRepositoryProvider)
          .joinJobInterview(interview.id);
      if (!context.mounted) return;
      openInterviewCall(
        context,
        callSessionFromInterviewJoin(
          join,
          localUserName: interview.agencyName,
        ),
      );
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _sendOffer(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
  ) async {
    final jobs = ref.read(agencyJobOpportunitiesProvider).valueOrNull ?? [];
    JobOpportunityModel? job;
    for (final row in jobs) {
      if (row.id == jobOpportunityId) {
        job = row;
        break;
      }
    }
    final offer = await showSendJobOfferDialog(
      context,
      suggestedCompensation: job?.payRateDisplay,
    );
    if (offer == null || !context.mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).sendJobOffer(
            applicationId: applicationId,
            compensationRate: offer.compensationRate,
            startDate: offer.startDate,
            message: offer.message,
          );
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      ref.invalidate(agencyHiringPipelineSummaryProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Offer sent');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _hireAndRoster(
    WidgetRef ref,
    BuildContext context,
    JobApplicationModel app,
  ) async {
    try {
      await ref
          .read(jobOpportunitiesRepositoryProvider)
          .markHiredAndAddToRoster(app.id);
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      ref.invalidate(agencyHiringPipelineSummaryProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);

      if (!context.mounted) return;
      AppSnackBar.showSuccess(context, 'Therapist hired and posting closed');

      final session = await showScheduleFirstSessionSheet(
        context,
        therapistName: app.therapistName,
      );
      if (session == null || !context.mounted) return;

      await ref.read(jobOpportunitiesRepositoryProvider).scheduleFirstSessionFromHire(
            applicationId: app.id,
            scheduledStart: session.scheduledStart,
            durationMinutes: session.durationMinutes,
            notes: session.notes,
          );
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'First session scheduled');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _inviteTherapist(WidgetRef ref, BuildContext context) async {
    final selected = await showInviteTherapistSheet(
      context,
      ref,
      title: 'Invite therapist to apply',
    );
    if (selected == null || !context.mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).inviteTherapistToApply(
            jobOpportunityId: jobOpportunityId,
            therapistId: selected.id,
          );
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Invite sent to ${selected.displayName}');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _rescheduleInterview(
    WidgetRef ref,
    BuildContext context,
    JobInterviewModel interview,
    String therapistName,
  ) async {
    final result = await showScheduleInterviewSheet(
      context,
      therapistName: therapistName,
    );
    if (result == null || !context.mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).rescheduleJobInterview(
            interviewId: interview.id,
            scheduledAt: result.scheduledAt,
            durationMinutes: result.durationMinutes,
            notes: result.notes,
          );
      ref.invalidate(agencyJobInterviewsProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Interview rescheduled');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _completeInterview(
    WidgetRef ref,
    BuildContext context,
    JobInterviewModel interview,
  ) async {
    final note = await showApplicantDecisionNoteDialog(
      context,
      title: 'Mark interview complete?',
      confirmLabel: 'Complete',
      hint: 'Optional note (e.g. phone interview completed)',
    );
    if (note == null || !context.mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).completeJobInterviewManually(
            interviewId: interview.id,
            note: note.isEmpty ? null : note,
          );
      ref.invalidate(agencyJobInterviewsProvider);
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Interview marked complete');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Map<String, JobInterviewModel> _interviewsForJob(
    List<JobInterviewModel> interviews,
  ) {
    return {
      for (final interview in interviews)
        if (interview.jobOpportunityId == jobOpportunityId &&
            interview.status != 'CANCELLED')
          interview.applicationId: interview,
    };
  }

  Future<void> _cancelInterview(
    WidgetRef ref,
    BuildContext context,
    JobInterviewModel interview,
  ) async {
    final reason = await showCancelInterviewDialog(context);
    if (reason == null || !context.mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).cancelJobInterview(
            interviewId: interview.id,
            reason: reason.isEmpty ? null : reason,
          );
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      ref.invalidate(agencyHiringPipelineSummaryProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);
      ref.invalidate(agencyJobInterviewsProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Interview cancelled');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  List<Widget> _applicantActions({
    required WidgetRef ref,
    required BuildContext context,
    required JobApplicationModel app,
    required JobInterviewModel? interview,
  }) {
    return [
      if (app.status == 'NEW_APPLICANT')
        TextButton(
          onPressed: () => _updateStatus(ref, context, app.id, 'UNDER_REVIEW'),
          child: const Text('Review'),
        ),
      if (interview == null &&
          (app.status == 'UNDER_REVIEW' || app.status == 'NEW_APPLICANT'))
        TextButton(
          onPressed: () => _scheduleInterview(ref, context, app),
          child: const Text('Schedule interview'),
        ),
      if (interview != null) ...[
        Text(
          interview.status == 'COMPLETED'
              ? 'Interview completed'
              : interview.scheduledAt.toLocal().toString().split('.').first,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (interviewJoinWindowOpen(interview))
          GlossyButton(
            label: 'Join call',
            size: GlossyButtonSize.small,
            onPressed: () => _joinInterview(ref, context, interview),
          ),
        if (interviewIsActive(interview)) ...[
          TextButton(
            onPressed: () => _rescheduleInterview(
              ref,
              context,
              interview,
              app.therapistName,
            ),
            child: const Text('Reschedule'),
          ),
          TextButton(
            onPressed: () => _cancelInterview(ref, context, interview),
            child: const Text('Cancel interview'),
          ),
          TextButton(
            onPressed: () => _completeInterview(ref, context, interview),
            child: const Text('Mark complete'),
          ),
        ],
      ],
      if ((interview?.status == 'COMPLETED' ||
              app.status == 'CREDENTIAL_REVIEW') &&
          (app.status == 'INTERVIEW_REQUESTED' ||
              app.status == 'UNDER_REVIEW' ||
              app.status == 'CREDENTIAL_REVIEW'))
        GlossyButton(
          label: 'Send offer',
          size: GlossyButtonSize.small,
          onPressed: () => _sendOffer(ref, context, app.id),
        ),
      if (interview != null && interview.status == 'COMPLETED')
        TextButton(
          onPressed: () => _saveInterviewNotes(ref, context, interview),
          child: Text(
            interview.notes == null || interview.notes!.isEmpty
                ? 'Add notes'
                : 'Edit notes',
          ),
        ),
      if (interview != null &&
          interview.status == 'COMPLETED' &&
          interview.callSessionId != null)
        TextButton(
          onPressed: () => context.push(
            '${AppRoutes.agencyHome}/call-audit?callSessionId=${interview.callSessionId}',
          ),
          child: const Text('View call audit'),
        ),
      if (app.status == 'CREDENTIAL_REVIEW' &&
          app.credentialDocuments.isNotEmpty)
        GlossyButton(
          label: 'Approve credentials',
          size: GlossyButtonSize.small,
          onPressed: () => _approveCredentials(ref, context, app.id),
        ),
      if (app.credentialDocuments.isNotEmpty ||
          app.status == 'CREDENTIAL_REVIEW')
        TextButton(
          onPressed: () => showApplicantCredentialsSheet(
            context,
            therapistName: app.therapistName,
            documents: app.credentialDocuments,
            applicationId: app.id,
          ),
          child: Text(
            app.credentialDocuments.isEmpty
                ? 'View credentials'
                : 'View credentials (${app.credentialDocuments.length})',
          ),
        ),
      if (app.recentStatusHistory.isNotEmpty)
        TextButton(
          onPressed: () => showApplicationStatusHistorySheet(
            context,
            title: '${app.therapistName} · status history',
            history: app.recentStatusHistory,
          ),
          child: const Text('Status history'),
        ),
      if (!applicationStatusIsTerminal(app.status) &&
          (app.status == 'UNDER_REVIEW' ||
              app.status == 'INTERVIEW_REQUESTED' ||
              interview?.status == 'COMPLETED'))
        TextButton(
          onPressed: () => _requestCredentials(ref, context, app.id),
          child: const Text('Request credentials'),
        ),
      if (!applicationStatusIsTerminal(app.status))
        TextButton(
          onPressed: () => _rejectApplicant(ref, context, app.id),
          child: const Text('Reject'),
        ),
      if (app.status == 'OFFER_SENT' || app.status == 'APPROVED')
        GlossyButton(
          label: 'Hire + roster',
          size: GlossyButtonSize.small,
          onPressed: () => _hireAndRoster(ref, context, app),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications =
        ref.watch(agencyJobApplicationsProvider(jobOpportunityId));
    final interviews = ref.watch(agencyJobInterviewsProvider);
    final filter = ref.watch(agencyApplicantFilterProvider(jobOpportunityId));

    return AppScaffold(
      title: 'Applicants',
      subtitle: 'Review therapist applications',
      actions: [
        IconButton(
          tooltip: 'Interview calendar',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => context.push(AppRoutes.agencyInterviews),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      ref.invalidate(agencyHiringPipelineSummaryProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);
          ref.invalidate(agencyJobInterviewsProvider);
        },
        child: applications.when(
          loading: () => const _ScrollableStatus(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ScrollableStatus(
            child: Center(child: Text(AppSnackBar.messageFromError(e))),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return _ScrollableStatus(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No applications yet.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _inviteTherapist(ref, context),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Invite therapist to apply'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final interviewByAppId = interviews.maybeWhen(
              data: _interviewsForJob,
              orElse: () => const <String, JobInterviewModel>{},
            );
            final filtered = rows
                .where((app) => matchesAgencyApplicantFilter(app, filter))
                .toList();

            if (filtered.isEmpty) {
              return _ScrollableStatus(
                child: Center(
                  child: Text(
                    filter == AgencyApplicantFilter.all
                        ? 'No applications yet.'
                        : 'No applicants match this filter.',
                  ),
                ),
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final option in AgencyApplicantFilter.values)
                          FilterChip(
                            label: Text(switch (option) {
                              AgencyApplicantFilter.all => 'All',
                              AgencyApplicantFilter.needsAction => 'Needs action',
                              AgencyApplicantFilter.offerSent => 'Offer sent',
                              AgencyApplicantFilter.hired => 'Hired',
                            }),
                            selected: filter == option,
                            onSelected: (selected) {
                              if (!selected) return;
                              ref
                                  .read(
                                    agencyApplicantFilterProvider(jobOpportunityId)
                                        .notifier,
                                  )
                                  .state = option;
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final app = filtered[index];
                      final interview = interviewByAppId[app.id];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      app.therapistName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  ApplicationStatusBadge(status: app.status),
                                ],
                              ),
                              if (app.therapistEmail != null &&
                                  app.therapistEmail!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  app.therapistEmail!,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Applied ${app.createdAt.toLocal().toString().split('.').first}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (app.message != null &&
                                  app.message!.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(app.message!),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _applicantActions(
                                  ref: ref,
                                  context: context,
                                  app: app,
                                  interview: interview,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

class _ScrollableStatus extends StatelessWidget {
  const _ScrollableStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: child,
        ),
      ],
    );
  }
}
