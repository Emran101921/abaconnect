import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../calls/data/call_models.dart';
import '../data/job_opportunities_repository.dart';

CallSessionModel callSessionFromInterviewJoin(
  JobInterviewJoinModel join, {
  required String localUserName,
}) {
  return CallSessionModel(
    id: join.callSessionId,
    callType: CallType.VIDEO,
    status: CallSessionStatus.IN_PROGRESS,
    initiatedByUserId: '',
    initiatedByName: localUserName,
    recipientName: join.therapistName,
    createdAt: DateTime.now(),
    joinUrl: join.joinUrl,
    token: join.token,
    tokenExpiresAt: join.tokenExpiresAt,
    jobInterviewId: join.interviewId,
  );
}

void openInterviewCall(BuildContext context, CallSessionModel session) {
  context.push('${AppRoutes.activeCall}/${session.id}', extra: session);
}

bool interviewJoinWindowOpen(JobInterviewModel interview) {
  final now = DateTime.now();
  final start = interview.scheduledAt.subtract(const Duration(minutes: 15));
  final end = interview.scheduledAt.add(
    Duration(minutes: interview.durationMinutes + 15),
  );
  return !now.isBefore(start) &&
      !now.isAfter(end) &&
      interview.status != 'CANCELLED' &&
      interview.status != 'COMPLETED';
}

bool interviewIsActive(JobInterviewModel interview) {
  return interview.status != 'CANCELLED' && interview.status != 'COMPLETED';
}

bool interviewStartingSoon(
  JobInterviewModel interview, {
  Duration within = const Duration(hours: 1),
}) {
  if (!interviewIsActive(interview)) return false;
  final now = DateTime.now();
  if (!interview.scheduledAt.isAfter(now)) return false;
  return interview.scheduledAt.difference(now) <= within;
}

List<JobInterviewModel> interviewsStartingSoon(
  List<JobInterviewModel> interviews, {
  Duration within = const Duration(hours: 1),
}) {
  final rows = interviews.where((i) => interviewStartingSoon(i, within: within)).toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return rows;
}

int countTherapistJobPendingActions({
  required List<JobApplicationModel> applications,
  required List<JobInterviewModel> interviews,
}) {
  var count = 0;
  for (final app in applications) {
    if (app.status == 'OFFER_SENT' || app.status == 'CREDENTIAL_REVIEW') {
      count++;
    }
  }
  for (final interview in interviews) {
    if (!interviewIsActive(interview)) continue;
    if (interview.recordingEnabled && !interview.therapistRecordingConsent) {
      count++;
    }
  }
  return count;
}

Future<String?> showCancelInterviewDialog(BuildContext context) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel interview?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The therapist will be notified. You can schedule a new interview later.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep interview'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cancel interview'),
        ),
      ],
    ),
  );
  final reason = controller.text.trim();
  controller.dispose();
  if (confirmed != true) return null;
  return reason;
}
