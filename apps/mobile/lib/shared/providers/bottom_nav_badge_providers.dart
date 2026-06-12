import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/messaging/messaging_providers.dart';
import '../../features/parent/presentation/parent_home_screen.dart';
import '../../features/therapist/therapist_providers.dart';

int? _positiveBadge(int count) => count > 0 ? count : null;

/// Parent Home — today's sessions first, then other upcoming appointments.
final parentHomeNavBadgeProvider = Provider<int?>((ref) {
  return ref.watch(parentDashboardProvider).maybeWhen(
    data: (d) {
      if (d.appointmentsToday > 0) return d.appointmentsToday;
      if (d.upcomingAppointments > 0) return d.upcomingAppointments;
      return null;
    },
    orElse: () => null,
  );
});

/// Parent Messages — unread threads, then today's schedule, then pending visits.
final parentMessagesNavBadgeProvider = Provider<int?>((ref) {
  final unread = ref.watch(unreadMessageThreadsProvider).valueOrNull ?? 0;
  final dashboard = ref.watch(parentDashboardProvider).valueOrNull;
  if (unread > 0) return unread;
  final today = dashboard?.appointmentsToday ?? 0;
  if (today > 0) return today;
  final upcoming = dashboard?.upcomingAppointments ?? 0;
  return _positiveBadge(upcoming);
});

/// Therapist Schedule — today's visits + pending booking requests.
final therapistScheduleNavBadgeProvider = Provider<int?>((ref) {
  return ref.watch(therapistDashboardProvider).maybeWhen(
    data: (d) => _positiveBadge(d.appointmentsToday + d.pendingRequests),
    orElse: () => null,
  );
});

/// Therapist Sessions — notes due + in-progress visits.
final therapistSessionsNavBadgeProvider = Provider<int?>((ref) {
  return ref.watch(therapistDashboardProvider).maybeWhen(
    data: (d) =>
        _positiveBadge(d.pendingDocumentation + d.inProgressSessions),
    orElse: () => null,
  );
});

/// Therapist Messages — unread threads, then schedule, then pending sessions.
final therapistMessagesNavBadgeProvider = Provider<int?>((ref) {
  final unread = ref.watch(unreadMessageThreadsProvider).valueOrNull ?? 0;
  final dashboard = ref.watch(therapistDashboardProvider).valueOrNull;
  if (unread > 0) return unread;
  if (dashboard == null) return null;
  final schedule = dashboard.appointmentsToday + dashboard.pendingRequests;
  if (schedule > 0) return schedule;
  final sessions =
      dashboard.pendingDocumentation + dashboard.inProgressSessions;
  return _positiveBadge(sessions);
});
