import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../agency/data/agency_repository.dart';
import '../../agency/presentation/agency_providers.dart';
import '../../therapist/presentation/staff_session_notes_screen.dart';
import '../agency_platform_constants.dart';
import '../presentation/agency_platform_providers.dart';
import '../data/agency_platform_repository.dart';
import '../widgets/profile_tab_scaffold.dart';

class AgencyProviderProfileScreen extends ConsumerWidget {
  const AgencyProviderProfileScreen({
    super.key,
    required this.therapistId,
  });

  final String therapistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final therapists = ref.watch(agencyTherapistsProvider);

    return therapists.when(
      loading: () => const AppScaffold(
        title: 'Provider profile',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Provider profile',
        body: Center(child: Text(AppSnackBar.messageFromError(e))),
      ),
      data: (list) {
        AgencyTherapistModel? therapist;
        for (final t in list) {
          if (t.id == therapistId) {
            therapist = t;
            break;
          }
        }
        if (therapist == null) {
          return const AppScaffold(
            title: 'Provider profile',
            body: Center(child: Text('Provider not found')),
          );
        }
        final t = therapist;
        return ProfileTabScaffold(
          title: t.displayName,
          subtitle: t.email,
          tabLabels: ProviderProfileTabs.all,
          tabViews: [
            _ProviderOverviewTab(therapist: t),
            _CredentialsTab(therapist: t),
            _ComplianceTab(therapist: t),
            _ProviderCaseloadTab(therapist: t),
            const ProfileTabPlaceholder(
              title: ProviderProfileTabs.services,
              icon: Icons.handshake_outlined,
            ),
            const ProfileTabPlaceholder(
              title: ProviderProfileTabs.availability,
              icon: Icons.calendar_today_outlined,
            ),
            _ProviderPayrollTab(therapistId: t.id),
            const ProfileTabPlaceholder(
              title: ProviderProfileTabs.documents,
              icon: Icons.folder_open_outlined,
            ),
            ProfileTabPlaceholder(
              title: ProviderProfileTabs.portalAccess,
              icon: Icons.login_outlined,
              description: t.isVerified && t.rosterStatus != 'PENDING'
                  ? 'Portal access is active for this provider.'
                  : 'Portal access pending verification or roster approval.',
            ),
            const ProfileTabPlaceholder(
              title: ProviderProfileTabs.auditLog,
              icon: Icons.history,
            ),
          ],
        );
      },
    );
  }
}

class _ProviderOverviewTab extends StatelessWidget {
  const _ProviderOverviewTab({required this.therapist});

  final AgencyTherapistModel therapist;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DashboardCard(
          title: 'Contact & employment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${therapist.email ?? '—'}'),
              Text('Roster status: ${therapist.rosterStatus ?? 'Unknown'}'),
              if (therapist.onboardingStatus != null)
                Text('Onboarding: ${therapist.onboardingStatus}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _CredentialsTab extends StatelessWidget {
  const _CredentialsTab({required this.therapist});

  final AgencyTherapistModel therapist;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DashboardCard(
          title: 'License & verification',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('License #: ${therapist.licenseNumber ?? '—'}'),
              const SizedBox(height: 8),
              AppStatusBadge.fromKind(
                therapist.isVerified
                    ? AppStatusKind.active
                    : AppStatusKind.pending,
                label: therapist.isVerified ? 'Verified' : 'Pending verification',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComplianceTab extends StatelessWidget {
  const _ComplianceTab({required this.therapist});

  final AgencyTherapistModel therapist;

  @override
  Widget build(BuildContext context) {
    final alerts = <String>[];
    if (!therapist.isVerified) {
      alerts.add('Provider verification pending');
    }
    if (therapist.rosterStatus == 'PENDING' || therapist.isPendingRoster) {
      alerts.add('Roster approval pending');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DashboardCard(
          title: 'Compliance alerts',
          child: alerts.isEmpty
              ? Row(
                  children: [
                    AppStatusBadge.fromKind(
                      AppStatusKind.active,
                      label: 'No critical alerts',
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final alert in alerts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppStatusBadge.fromKind(
                          AppStatusKind.pending,
                          label: alert,
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        const ProfileTabPlaceholder(
          title: 'Credential tracking',
          icon: Icons.verified_user_outlined,
          description:
              'Expiring licenses, missing insurance, training certificates, '
              'and background-check deadlines will surface here.',
        ),
      ],
    );
  }
}

class _ProviderCaseloadTab extends ConsumerWidget {
  const _ProviderCaseloadTab({required this.therapist});

  final AgencyTherapistModel therapist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(agencySessionNotesProvider);
    return notes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(AppSnackBar.messageFromError(e))),
      data: (list) {
        final providerNotes = list
            .where((n) => n.therapistId == therapist.id)
            .toList();
        final children = <String, StaffSessionNoteSummaryModel>{};
        for (final note in providerNotes) {
          final key = note.childId ?? note.childName;
          children.putIfAbsent(key, () => note);
        }
        if (children.isEmpty) {
          return const ProfileTabPlaceholder(
            title: ProviderProfileTabs.caseload,
            icon: Icons.people_outline,
            description:
                'No documented sessions yet. Caseload appears from session notes.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DashboardCard(
              title: 'Active clients (${children.length})',
              child: Column(
                children: [
                  for (final note in children.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.child_care_outlined),
                      title: Text(note.childName),
                      subtitle: Text(
                        note.sessionDate != null
                            ? 'Last session ${note.sessionDate}'
                            : 'Recent session documented',
                      ),
                      trailing: note.childId != null
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: note.childId == null
                          ? null
                          : () => context.push(
                                '${AppRoutes.agencyHome}/children/${note.childId}',
                              ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProviderPayrollTab extends ConsumerWidget {
  const _ProviderPayrollTab({required this.therapistId});

  final String therapistId;

  Future<void> _showAddPayRate(BuildContext context, WidgetRef ref) async {
    final rateCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add pay rate'),
        content: TextField(
          controller: rateCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Hourly rate (USD)',
            prefixText: r'$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final dollars = double.tryParse(rateCtrl.text.trim());
    if (dollars == null) return;
    try {
      await ref.read(agencyPlatformRepositoryProvider).upsertProviderPayRate(
            therapistId: therapistId,
            rateCents: (dollars * 100).round(),
          );
      ref.invalidate(agencyProviderPayRatesProvider(therapistId));
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Pay rate saved.');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, AppSnackBar.messageFromError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(agencyProviderPayRatesProvider(therapistId));
    final dateFmt = DateFormat.yMMMd();
    return rates.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(AppSnackBar.messageFromError(e))),
      data: (list) {
        if (list.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const ProfileTabPlaceholder(
                title: ProviderProfileTabs.payroll,
                icon: Icons.payments_outlined,
                description: 'No pay rates configured for this provider yet.',
              ),
              const SizedBox(height: 16),
              GlossyButton(
                title: 'Add pay rate',
                icon: Icons.add,
                onPressed: () => _showAddPayRate(context, ref),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GlossyButton(
                title: 'Add pay rate',
                icon: Icons.add,
                size: GlossyButtonSize.small,
                fullWidth: false,
                onPressed: () => _showAddPayRate(context, ref),
              ),
            ),
            const SizedBox(height: 12),
            DashboardCard(
              title: 'Pay rates',
              child: Column(
                children: [
                  for (final rate in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(rate.serviceType ?? 'All services'),
                      subtitle: Text(
                        'Effective ${dateFmt.format(rate.effectiveFrom)}',
                      ),
                      trailing: Text(
                        rate.displayRate,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
