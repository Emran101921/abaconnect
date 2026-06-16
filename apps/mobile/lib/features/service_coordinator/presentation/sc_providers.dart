import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

final scDashboardProvider = FutureProvider((ref) {
  return ref.watch(serviceCoordinatorRepositoryProvider).fetchDashboard();
});

final scFollowUpsProvider = FutureProvider((ref) {
  return ref.watch(serviceCoordinatorRepositoryProvider).fetchFollowUps();
});

final scCaseDetailProvider = FutureProvider.family((ref, String childId) {
  return ref.watch(serviceCoordinatorRepositoryProvider).fetchCaseDetail(childId);
});

final agencyRosterMembersProvider = FutureProvider((ref) {
  return ref.watch(serviceCoordinatorRepositoryProvider).fetchAgencyRosterMembers();
});

final agencyCasesProvider = FutureProvider((ref) {
  return ref.watch(serviceCoordinatorRepositoryProvider).fetchAgencyCases();
});
