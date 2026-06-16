import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../parent/presentation/parent_dashboard_providers.dart';
import '../data/payments_repository.dart';

final parentPaymentsProvider = FutureProvider<List<PaymentModel>>((ref) {
  return ref.watch(paymentsRepositoryProvider).fetchPayments();
});

final paymentsConfigProvider = FutureProvider<bool>((ref) {
  return ref.watch(paymentsRepositoryProvider).fetchStripeConfigured();
});

/// Refetch payments, appointments, and dashboard after a payment status change.
Future<void> refreshParentBillingState(WidgetRef ref) async {
  ref.invalidate(parentPaymentsProvider);
  ref.invalidate(parentAppointmentsProvider);
  ref.invalidate(parentDashboardProvider);
  await Future.wait([
    ref.read(parentPaymentsProvider.future),
    ref.read(parentAppointmentsProvider.future),
    ref.read(parentDashboardProvider.future),
  ]);
}
