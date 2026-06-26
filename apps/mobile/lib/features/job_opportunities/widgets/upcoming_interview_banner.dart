import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/job_opportunities_repository.dart';
import 'job_interview_call.dart';

class UpcomingInterviewBanner extends StatelessWidget {
  const UpcomingInterviewBanner({
    super.key,
    required this.interviews,
    required this.role,
  });

  final List<JobInterviewModel> interviews;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final soon = interviewsStartingSoon(interviews);
    if (soon.isEmpty) return const SizedBox.shrink();

    final interview = soon.first;
    final time = DateFormat.jm().format(interview.scheduledAt.toLocal());
    final title = role == UserRole.agency
        ? 'Interview with ${interview.therapistName} at $time'
        : 'Interview with ${interview.agencyName} at $time';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.video_call_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Interview starting soon',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(interview.jobTitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              GlossyButton(
                label: interviewJoinWindowOpen(interview)
                    ? 'Join now'
                    : 'View interview',
                size: GlossyButtonSize.small,
                onPressed: () {
                  if (role == UserRole.agency) {
                    context.push(AppRoutes.agencyInterviews);
                  } else {
                    context.push(AppRoutes.therapistJobApplications);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
