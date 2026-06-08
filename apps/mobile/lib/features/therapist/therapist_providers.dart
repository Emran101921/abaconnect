import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import 'data/therapist_repository.dart';

final therapistDashboardProvider = FutureProvider<TherapistDashboardModel>((
  ref,
) async {
  return ref.watch(therapistRepositoryProvider).fetchDashboard();
});
