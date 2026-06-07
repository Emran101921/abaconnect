import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/agency_repository.dart';

final agencyDashboardProvider = FutureProvider<AgencyDashboardModel>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchDashboard();
});

final agencyTherapistsProvider = FutureProvider<List<AgencyTherapistModel>>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchTherapists();
});

final agencyInviteCandidatesProvider =
    FutureProvider<List<AgencyTherapistModel>>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchAvailableToInvite();
});

final agencyUpcomingAppointmentsProvider =
    FutureProvider<List<AgencyAppointmentModel>>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchUpcomingAppointments();
});

final agencyAnalyticsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchTenantAnalytics();
});

final agencyClaimsPipelineProvider =
    FutureProvider<AgencyClaimsPipelineModel>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchClaimsPipeline();
});

final agencyScreeningFunnelProvider =
    FutureProvider<AgencyScreeningFunnelModel>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchScreeningFunnel();
});

final agencyAnalyticsClaimDetailProvider =
    FutureProvider.family<AgencyClaimDetailModel, String>((ref, claimId) {
  return ref.watch(agencyRepositoryProvider).fetchAnalyticsClaimDetail(claimId);
});

final agencyAnalyticsScreeningDetailProvider =
    FutureProvider.family<AgencyScreeningDetailModel, String>(
        (ref, screeningId) {
  return ref
      .watch(agencyRepositoryProvider)
      .fetchAnalyticsScreeningDetail(screeningId);
});

final agencyAnalyticsClaimsListProvider =
    FutureProvider.family<List<AgencyClaimSummaryModel>, String>(
        (ref, statusFilter) {
  return ref
      .watch(agencyRepositoryProvider)
      .fetchAnalyticsClaimsList(statusFilter);
});

final agencyAnalyticsScreeningsListProvider =
    FutureProvider.family<List<AgencyScreeningSummaryModel>, String>(
        (ref, riskFilterKey) {
  final riskLevel = riskFilterKey == 'all' ? null : riskFilterKey;
  return ref
      .watch(agencyRepositoryProvider)
      .fetchAnalyticsScreeningsList(riskLevel: riskLevel);
});

Future<void> showInviteTherapist(BuildContext context, WidgetRef ref) async {
  final candidates = await ref.read(agencyInviteCandidatesProvider.future);
  if (!context.mounted) return;
  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All therapists are already on your roster')),
    );
    return;
  }
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Invite therapist'),
      children: candidates
          .map(
            (t) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t.id),
              child: Text(t.displayName),
            ),
          )
          .toList(),
    ),
  );
  if (selected == null) return;
  try {
    await ref.read(agencyRepositoryProvider).inviteTherapist(selected);
    ref.invalidate(agencyTherapistsProvider);
    ref.invalidate(agencyInviteCandidatesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist added to agency')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite failed: $e')),
      );
    }
  }
}
