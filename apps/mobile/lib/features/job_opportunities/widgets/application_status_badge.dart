import 'package:flutter/material.dart';

import '../../../shared/widgets/app_status_badge.dart';

class ApplicationStatusBadge extends StatelessWidget {
  const ApplicationStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, kind) = _mapStatus(status);
    return AppStatusBadge.fromKind(kind, label: label);
  }

  (String, AppStatusKind) _mapStatus(String raw) {
    switch (raw) {
      case 'NEW_APPLICANT':
        return ('New applicant', AppStatusKind.pending);
      case 'UNDER_REVIEW':
        return ('Under review', AppStatusKind.inProgress);
      case 'INTERVIEW_REQUESTED':
        return ('Interview', AppStatusKind.pending);
      case 'CREDENTIAL_REVIEW':
        return ('Credential review', AppStatusKind.inProgress);
      case 'OFFER_SENT':
        return ('Offer sent', AppStatusKind.pending);
      case 'APPROVED':
        return ('Approved', AppStatusKind.approved);
      case 'REJECTED':
        return ('Rejected', AppStatusKind.rejected);
      case 'HIRED_CONTRACTED':
        return ('Hired', AppStatusKind.completed);
      case 'WITHDRAWN':
        return ('Withdrawn', AppStatusKind.cancelled);
      default:
        return (raw.replaceAll('_', ' '), AppStatusKind.draft);
    }
  }
}
