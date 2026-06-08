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
  router.push(AppRoutes.notifications);
}
