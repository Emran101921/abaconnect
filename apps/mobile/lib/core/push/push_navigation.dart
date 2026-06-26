import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../../shared/models/user_role.dart';

/// Navigate from FCM data payload (matches API notification `data` keys).
void navigateFromPushPayload(
  GoRouter router, {
  required Map<String, dynamic> data,
  UserRole? role,
}) {
  final actionType = data['type'] as String? ?? data['actionType'] as String?;
  final threadId = data['threadId'] as String?;
  final appointmentId = data['appointmentId'] as String?;
  if (actionType == 'INCOMING_CALL') {
    final callSessionId = data['callSessionId'] as String?;
    if (callSessionId != null) {
      router.push('${AppRoutes.incomingCall}/$callSessionId');
    }
    return;
  }
  if (actionType == 'MESSAGE' && threadId != null) {
    router.push('${AppRoutes.messages}/$threadId');
    return;
  }
  if (actionType == 'SOAP_DUE' && role == UserRole.therapist) {
    router.push('${AppRoutes.therapistHome}/session-notes');
    return;
  }
  if (actionType != null &&
      actionType.startsWith('APPOINTMENT') &&
      appointmentId != null) {
    if (role == UserRole.therapist) {
      router.push('${AppRoutes.therapistHome}/appointments?id=$appointmentId');
    } else {
      router.push('${AppRoutes.parentHome}/appointments?id=$appointmentId');
    }
    return;
  }
  if (actionType == 'TELEHEALTH' && appointmentId != null) {
    router.push('${AppRoutes.parentHome}/appointments?id=$appointmentId');
    return;
  }
  if (actionType == 'SESSION_COMPLETED') {
    router.push('${AppRoutes.parentHome}/reviews');
    return;
  }

  final sessionId = data['sessionId'] as String?;
  if (actionType == 'PARENT_SESSION_SIGN_REQUESTED' &&
      sessionId != null &&
      role == UserRole.parent) {
    router.push(AppRoutes.parentSessionSign(sessionId));
    return;
  }

  final paymentId = data['paymentId'] as String?;
  if (actionType == 'SESSION_PAYMENT_DUE' &&
      paymentId != null &&
      role == UserRole.parent) {
    router.push('${AppRoutes.payments}?paymentId=$paymentId');
    return;
  }

  final marketplaceId =
      data['marketplaceRequestId'] as String? ?? data['requestId'] as String?;
  if (marketplaceId != null) {
    if (actionType == 'MARKETPLACE_INTEREST' && role == UserRole.parent) {
      router.push('${AppRoutes.parentMarketplace}/$marketplaceId/interests');
      return;
    }
    if (actionType == 'MARKETPLACE_CONSENT_GRANTED' &&
        role == UserRole.therapist) {
      router.push(
        '${AppRoutes.therapistMarketplace}/$marketplaceId/authorized-child',
      );
      return;
    }
    if (actionType == 'MARKETPLACE_CONSENT_GRANTED' &&
        role == UserRole.agency) {
      router.push(
        '${AppRoutes.agencyMarketplace}/$marketplaceId/authorized-child',
      );
      return;
    }
    if (actionType == 'MARKETPLACE_CONSENT_REVOKED' &&
        role == UserRole.therapist) {
      router.push(AppRoutes.therapistMarketplace);
      return;
    }
    if (actionType == 'MARKETPLACE_CONSENT_REVOKED' &&
        role == UserRole.agency) {
      router.push(AppRoutes.agencyMarketplace);
      return;
    }
    if (actionType == 'MARKETPLACE_SAVED_SEARCH_MATCH' &&
        role == UserRole.therapist) {
      router.push(AppRoutes.therapistMarketplace);
      return;
    }
    if (actionType == 'MARKETPLACE_SAVED_SEARCH_MATCH' &&
        role == UserRole.agency) {
      router.push(AppRoutes.agencyMarketplace);
      return;
    }
  }

  final jobId = data['jobOpportunityId'] as String?;
  if (jobId != null) {
    if (actionType == 'JOB_INVITE_TO_APPLY' && role == UserRole.therapist) {
      router.push('${AppRoutes.therapistJobOpportunities}/$jobId');
      return;
    }
    if (actionType == 'JOB_APPLICATION_SUBMITTED' && role == UserRole.agency) {
      router.push('${AppRoutes.agencyOpportunities}/$jobId/applicants');
      return;
    }
    if ((actionType == 'JOB_APPLICATION_CREDENTIALS_UPDATED' ||
            actionType == 'JOB_OFFER_ACCEPTED' ||
            actionType == 'JOB_OFFER_DECLINED') &&
        role == UserRole.agency) {
      router.push('${AppRoutes.agencyOpportunities}/$jobId/applicants');
      return;
    }
    if (actionType == 'JOB_APPLICATION_STATUS_CHANGED' &&
        role == UserRole.therapist) {
      router.push(AppRoutes.therapistJobApplications);
      return;
    }
    if (actionType == 'JOB_APPLICATION_CREDENTIALS_UPDATED' &&
        role == UserRole.therapist) {
      router.push(AppRoutes.therapistJobApplications);
      return;
    }
    if (actionType == 'JOB_OFFER_SENT' && role == UserRole.therapist) {
      router.push(AppRoutes.therapistJobApplications);
      return;
    }
    if (actionType == 'THERAPIST_HIRED_CONTRACTED' &&
        role == UserRole.therapist) {
      router.push(AppRoutes.therapistJobApplications);
      return;
    }
    if (actionType == 'JOB_INTERVIEW_COMPLETED' && role == UserRole.agency) {
      router.push('${AppRoutes.agencyOpportunities}/$jobId/applicants');
      return;
    }
    if ((actionType == 'JOB_INTERVIEW_SCHEDULED' ||
            actionType == 'JOB_INTERVIEW_RECORDING_CONSENT' ||
            actionType == 'JOB_INTERVIEW_CANCELLED' ||
            actionType == 'JOB_INTERVIEW_COMPLETED' ||
            actionType == 'JOB_INTERVIEW_STARTING_SOON' ||
            actionType == 'JOB_INTERVIEW_REMINDER') &&
        role == UserRole.therapist) {
      router.push(AppRoutes.therapistJobApplications);
      return;
    }
    if ((actionType == 'JOB_INTERVIEW_SCHEDULED' ||
            actionType == 'JOB_INTERVIEW_RECORDING_CONSENT' ||
            actionType == 'JOB_INTERVIEW_CANCELLED' ||
            actionType == 'JOB_INTERVIEW_COMPLETED' ||
            actionType == 'JOB_INTERVIEW_STARTING_SOON' ||
            actionType == 'JOB_INTERVIEW_REMINDER') &&
        role == UserRole.agency) {
      router.push(AppRoutes.agencyInterviews);
      return;
    }
  }

  router.push(AppRoutes.notifications);
}
