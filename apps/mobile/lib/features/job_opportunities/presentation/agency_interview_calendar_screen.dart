import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/applicant_decision_dialogs.dart';
import '../widgets/job_interview_call.dart';
import '../widgets/schedule_interview_sheet.dart';

class AgencyInterviewCalendarScreen extends ConsumerWidget {
  const AgencyInterviewCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interviews = ref.watch(agencyJobInterviewsProvider);

    return AppScaffold(
      title: 'Interview calendar',
      subtitle: 'Scheduled video interviews with applicants',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(agencyJobInterviewsProvider),
        child: interviews.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 240),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              Center(child: Text(AppSnackBar.messageFromError(e))),
            ],
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 48),
                  Center(child: Text('No interviews scheduled yet.')),
                ],
              );
            }

            final grouped = <String, List<JobInterviewModel>>{};
            for (final interview in rows) {
              final key = DateFormat.yMMMEd().format(interview.scheduledAt.toLocal());
              grouped.putIfAbsent(key, () => []).add(interview);
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 8),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ...entry.value.map(
                    (interview) => _InterviewCard(interview: interview),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InterviewCard extends ConsumerStatefulWidget {
  const _InterviewCard({required this.interview});

  final JobInterviewModel interview;

  @override
  ConsumerState<_InterviewCard> createState() => _InterviewCardState();
}

class _InterviewCardState extends ConsumerState<_InterviewCard> {
  bool _joining = false;
  bool _cancelling = false;

  Future<void> _cancel() async {
    final reason = await showCancelInterviewDialog(context);
    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(jobOpportunitiesRepositoryProvider).cancelJobInterview(
            interviewId: widget.interview.id,
            reason: reason.isEmpty ? null : reason,
          );
      ref.invalidate(agencyJobInterviewsProvider);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Interview cancelled');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _editNotes(JobInterviewModel interview) async {
    final notes = await showInterviewNotesDialog(
      context,
      initialNotes: interview.notes,
    );
    if (notes == null || notes.isEmpty || !mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).updateInterviewNotes(
            interviewId: interview.id,
            notes: notes,
          );
      ref.invalidate(agencyJobInterviewsProvider);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Interview notes saved');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _reschedule() async {
    final result = await showScheduleInterviewSheet(
      context,
      therapistName: widget.interview.therapistName,
    );
    if (result == null || !mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).rescheduleJobInterview(
            interviewId: widget.interview.id,
            scheduledAt: result.scheduledAt,
            durationMinutes: result.durationMinutes,
            notes: result.notes,
          );
      ref.invalidate(agencyJobInterviewsProvider);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Interview rescheduled');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _complete() async {
    final note = await showApplicantDecisionNoteDialog(
      context,
      title: 'Mark interview complete?',
      confirmLabel: 'Complete',
      hint: 'Optional note (e.g. phone interview completed)',
    );
    if (note == null || !mounted) return;

    try {
      await ref.read(jobOpportunitiesRepositoryProvider).completeJobInterviewManually(
            interviewId: widget.interview.id,
            note: note.isEmpty ? null : note,
          );
      ref.invalidate(agencyJobInterviewsProvider);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Interview marked complete');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final join = await ref
          .read(jobOpportunitiesRepositoryProvider)
          .joinJobInterview(widget.interview.id);
      if (!mounted) return;
      final session = callSessionFromInterviewJoin(
        join,
        localUserName: widget.interview.agencyName,
      );
      openInterviewCall(context, session);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interview = widget.interview;
    final time = DateFormat.jm().format(interview.scheduledAt.toLocal());
    final canJoin = interviewJoinWindowOpen(interview);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(interview.jobTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$time · ${interview.durationMinutes} min · ${interview.therapistName}'),
            const SizedBox(height: 4),
            Text(
              interview.status == 'COMPLETED'
                  ? 'Completed'
                  : interview.status.replaceAll('_', ' '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (interview.recordingRequested) ...[
              const SizedBox(height: 8),
              Text(
                interview.recordingEnabled
                    ? 'Recording enabled (both parties consented)'
                    : 'Recording requested — '
                        'Agency: ${interview.agencyRecordingConsent ? 'yes' : 'pending'} · '
                        'Therapist: ${interview.therapistRecordingConsent ? 'yes' : 'pending'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (interview.notes != null && interview.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                interview.notes!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                GlossyButton(
                  label: canJoin ? 'Join video call' : 'Join (opens 15 min early)',
                  size: GlossyButtonSize.small,
                  loading: _joining,
                  onPressed: canJoin && !_joining ? _join : null,
                ),
                if (interviewIsActive(interview)) ...[
                  TextButton(
                    onPressed: _cancelling || _joining ? null : _cancel,
                    child: _cancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: _reschedule,
                    child: const Text('Reschedule'),
                  ),
                  TextButton(
                    onPressed: _complete,
                    child: const Text('Mark complete'),
                  ),
                ],
                if (interview.status == 'COMPLETED') ...[
                  TextButton(
                    onPressed: () => _editNotes(interview),
                    child: Text(
                      interview.notes == null || interview.notes!.isEmpty
                          ? 'Add notes'
                          : 'Edit notes',
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(
                      '${AppRoutes.agencyOpportunities}/${interview.jobOpportunityId}/applicants',
                    ),
                    child: const Text('Send offer'),
                  ),
                  if (interview.callSessionId != null)
                    TextButton(
                      onPressed: () => context.push(
                        '${AppRoutes.agencyHome}/call-audit?callSessionId=${interview.callSessionId}',
                      ),
                      child: const Text('Call audit'),
                    ),
                ],
                TextButton(
                  onPressed: () => context.push(
                    '${AppRoutes.agencyOpportunities}/${interview.jobOpportunityId}/applicants',
                  ),
                  child: const Text('Applicants'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
