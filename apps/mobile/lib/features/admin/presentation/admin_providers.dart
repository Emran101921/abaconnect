import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/models/analytics_date_range.dart';
import '../../payments/data/billing_repository.dart';
import '../data/admin_repository.dart';

final adminDashboardProvider =
    FutureProvider<AdminDashboardModel>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchDashboard();
});

final adminUsersProvider = FutureProvider<List<AdminUserModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchUsers();
});

final pendingTherapistsProvider =
    FutureProvider<List<PendingTherapistModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchPendingTherapists();
});

final adminAuditLogsProvider = FutureProvider<List<AuditLogModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchAuditLogs();
});

final adminComplaintsProvider =
    FutureProvider<List<AdminComplaintModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchComplaints();
});

final adminPaymentDisputesProvider =
    FutureProvider<List<DisputeModel>>((ref) async {
  return ref.watch(billingRepositoryProvider).fetchAdminDisputes();
});

final adminPayoutsProvider = FutureProvider<List<PayoutModel>>((ref) async {
  return ref.watch(billingRepositoryProvider).fetchAdminPayouts();
});

final adminReviewsProvider =
    FutureProvider<List<AdminReviewModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchReviews();
});

final adminAnalyticsDateRangeProvider =
    StateProvider<AnalyticsDateRange>((ref) => const AnalyticsDateRange());

final adminAnalyticsProvider =
    FutureProvider<List<AnalyticsMetricModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchAnalytics();
});

final adminClaimsPipelineProvider =
    FutureProvider<ClaimsPipelineDashboardModel>((ref) async {
  final range = ref.watch(adminAnalyticsDateRangeProvider);
  return ref.watch(adminRepositoryProvider).fetchClaimsPipeline(
        fromDate: range.graphqlFrom,
        toDate: range.graphqlTo,
      );
});

final adminScreeningFunnelProvider =
    FutureProvider<ScreeningFunnelDashboardModel>((ref) async {
  final range = ref.watch(adminAnalyticsDateRangeProvider);
  return ref.watch(adminRepositoryProvider).fetchScreeningFunnel(
        fromDate: range.graphqlFrom,
        toDate: range.graphqlTo,
      );
});

final adminInsuranceClaimsProvider =
    FutureProvider<List<AdminInsuranceClaimModel>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchInsuranceClaims();
});

final adminAnalyticsClaimDetailProvider =
    FutureProvider.family<AdminInsuranceClaimModel, String>((ref, claimId) {
  return ref.watch(adminRepositoryProvider).fetchAnalyticsClaimDetail(claimId);
});

final adminAnalyticsScreeningDetailProvider =
    FutureProvider.family<AnalyticsScreeningDetailModel, String>(
        (ref, screeningId) {
  return ref
      .watch(adminRepositoryProvider)
      .fetchAnalyticsScreeningDetail(screeningId);
});

final adminAnalyticsClaimsListProvider =
    FutureProvider.family<List<AnalyticsClaimSummaryModel>, String>(
        (ref, statusFilter) {
  final range = ref.watch(adminAnalyticsDateRangeProvider);
  return ref.watch(adminRepositoryProvider).fetchAnalyticsClaimsList(
        statusFilter,
        fromDate: range.graphqlFrom,
        toDate: range.graphqlTo,
      );
});

final adminAnalyticsScreeningsListProvider =
    FutureProvider.family<List<AnalyticsScreeningSummaryModel>, String>(
        (ref, riskFilterKey) {
  final riskLevel = riskFilterKey == 'all' ? null : riskFilterKey;
  final range = ref.watch(adminAnalyticsDateRangeProvider);
  return ref.watch(adminRepositoryProvider).fetchAnalyticsScreeningsList(
        riskLevel: riskLevel,
        fromDate: range.graphqlFrom,
        toDate: range.graphqlTo,
      );
});
