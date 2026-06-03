import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/graphql_client.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/parent/data/parent_booking_repository.dart';
import '../../features/therapist/data/therapist_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final graphqlClientProvider = Provider<GraphqlClient>((ref) => GraphqlClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final parentBookingRepositoryProvider = Provider<ParentBookingRepository>((ref) {
  return ParentBookingRepository(ref.watch(graphqlClientProvider));
});

final therapistRepositoryProvider = Provider<TherapistRepository>((ref) {
  return TherapistRepository(ref.watch(graphqlClientProvider));
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(graphqlClientProvider));
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AuthSession?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
