import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agency_platform_constants.dart';
import '../data/agency_platform_repository.dart';

final agencyPlatformOverviewProvider =
    FutureProvider<AgencyPlatformOverviewModel>((ref) async {
  return ref.watch(agencyPlatformRepositoryProvider).fetchOverview();
});

final agencyAuditLogsProvider = FutureProvider<List<AgencyAuditLogModel>>((
  ref,
) async {
  return ref.watch(agencyPlatformRepositoryProvider).fetchAuditLogs();
});

final agencyClientAuditLogsProvider =
    FutureProvider.family<List<AgencyAuditLogModel>, String>((
  ref,
  patientId,
) async {
  return ref
      .watch(agencyPlatformRepositoryProvider)
      .fetchAuditLogs(patientId: patientId);
});

/// Enabled module keys for the current agency (empty while loading = show defaults).
final agencyEnabledModulesProvider = Provider<Set<String>>((ref) {
  final overview = ref.watch(agencyPlatformOverviewProvider);
  return overview.maybeWhen(
    data: (o) => o.modules
        .where((m) => m.enabled)
        .map((m) => m.moduleKey)
        .toSet(),
    orElse: () => AgencyPlatformModules.all.toSet(),
  );
});

final agencyClientCoordinationProvider =
    FutureProvider.family<AgencyClientCoordinationModel?, String>((
  ref,
  childId,
) async {
  return ref
      .watch(agencyPlatformRepositoryProvider)
      .fetchClientCoordination(childId);
});

final agencyReferralsProvider =
    FutureProvider<List<AgencyReferralModel>>((ref) async {
  return ref.watch(agencyPlatformRepositoryProvider).fetchReferrals();
});

final agencyIntegrationCatalogProvider =
    FutureProvider<List<AgencyIntegrationModel>>((ref) async {
  return ref.watch(agencyPlatformRepositoryProvider).fetchIntegrationCatalog();
});

final agencyProviderPayRatesProvider =
    FutureProvider.family<List<ProviderPayRateModel>, String>((
  ref,
  therapistId,
) async {
  return ref
      .watch(agencyPlatformRepositoryProvider)
      .fetchProviderPayRates(therapistId: therapistId);
});

final agencyOperationalAlertsProvider =
    FutureProvider<List<AgencyOperationalAlertModel>>((ref) async {
  return ref.watch(agencyPlatformRepositoryProvider).fetchOperationalAlerts();
});
