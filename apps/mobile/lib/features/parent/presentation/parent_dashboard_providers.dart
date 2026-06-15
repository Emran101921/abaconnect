import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/parent_booking_repository.dart';

final parentDashboardProvider =
    FutureProvider.autoDispose<ParentDashboardModel>((ref) async {
  return ref.watch(parentBookingRepositoryProvider).fetchDashboard();
});

final parentAppointmentsProvider = FutureProvider<List<AppointmentModel>>((
  ref,
) async {
  return ref.watch(parentBookingRepositoryProvider).fetchAppointments();
});

final parentPendingReviewsProvider = FutureProvider<List<TherapistModel>>((
  ref,
) async {
  return ref
      .watch(parentBookingRepositoryProvider)
      .fetchPendingReviewTherapists();
});

final parentChildrenProvider = FutureProvider<List<ChildModel>>((ref) async {
  return ref.watch(parentBookingRepositoryProvider).fetchChildren();
});

final parentShowsPaymentsProvider = FutureProvider<bool>((ref) async {
  final children = await ref.watch(parentChildrenProvider.future);
  if (children.isEmpty) return true;
  return children.every((child) {
    final type = child.insuranceType;
    return type == null || type == 'Self-pay';
  });
});
