import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/graphql_client.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/agency/data/agency_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/messaging/data/messaging_repository.dart';
import '../../features/parent/data/parent_booking_repository.dart';
import '../../features/payments/data/billing_repository.dart';
import '../../features/payments/data/payments_repository.dart';
import '../../features/clinical/data/clinical_repository.dart';
import '../../features/compliance/data/privacy_repository.dart';
import '../../features/platform/data/platform_repository.dart';
import '../../features/therapist/data/therapist_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final graphqlClientProvider = Provider<GraphqlClient>((ref) => GraphqlClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final parentBookingRepositoryProvider = Provider<ParentBookingRepository>((
  ref,
) {
  return ParentBookingRepository(
    ref.watch(graphqlClientProvider),
    ref.watch(apiClientProvider),
  );
});

final therapistRepositoryProvider = Provider<TherapistRepository>((ref) {
  return TherapistRepository(
    ref.watch(graphqlClientProvider),
    ref.watch(apiClientProvider),
  );
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(graphqlClientProvider));
});

final agencyRepositoryProvider = Provider<AgencyRepository>((ref) {
  return AgencyRepository(ref.watch(graphqlClientProvider));
});

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(ref.watch(graphqlClientProvider));
});

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref.watch(graphqlClientProvider));
});

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(ref.watch(graphqlClientProvider));
});

final platformRepositoryProvider = Provider<PlatformRepository>((ref) {
  return PlatformRepository(
    ref.watch(graphqlClientProvider),
    ref.watch(apiClientProvider),
  );
});

final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  return PrivacyRepository(ref.watch(apiClientProvider));
});

final clinicalRepositoryProvider = Provider<ClinicalRepository>((ref) {
  return ClinicalRepository(ref.watch(graphqlClientProvider));
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AuthSession?>>((ref) {
      return AuthNotifier(ref.watch(authRepositoryProvider), ref);
    });
