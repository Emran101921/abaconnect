import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_snackbar.dart';
import '../data/job_opportunities_repository.dart';
import 'applicant_decision_dialogs.dart';

Future<String?> respondToJobOfferWithFeedback({
  required WidgetRef ref,
  required BuildContext context,
  required String applicationId,
  required bool accept,
}) async {
  String? note;
  if (!accept) {
    note = await showApplicantDecisionNoteDialog(
      context,
      title: 'Decline offer?',
      confirmLabel: 'Decline offer',
      hint: 'Optional message to the agency',
    );
    if (note == null || !context.mounted) return null;
  } else {
    note = await showApplicantDecisionNoteDialog(
      context,
      title: 'Accept this offer?',
      confirmLabel: 'Accept offer',
      hint: 'Optional message to the agency',
    );
    if (note == null || !context.mounted) return null;
  }

  try {
    final application = await ref
        .read(jobOpportunitiesRepositoryProvider)
        .respondToJobOffer(
          applicationId: applicationId,
          accept: accept,
          note: note.isEmpty ? null : note,
        );
    ref.invalidate(therapistMyJobApplicationsProvider);
    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        accept ? 'Offer accepted' : 'Offer declined',
      );
    }
    return application.status;
  } catch (e) {
    if (context.mounted) AppSnackBar.showError(context, e);
    return null;
  }
}

String applicationStatusWithOverride({
  required String applicationId,
  required String apiStatus,
  required Map<String, String> overrides,
}) {
  return overrides[applicationId] ?? apiStatus;
}
