import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/dashboard_action_model.dart';
import '../../../shared/layout/action_button.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/layout/app_page_header.dart';
import '../../../shared/layout/user_role_badge.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_stat_card.dart';
import '../../../shared/widgets/app_wellness_action_menu.dart';
import '../../../shared/widgets/app_wellness_journey_card.dart';
import '../../../shared/widgets/dashboard_action_inbox.dart';
import '../../job_opportunities/data/job_opportunities_repository.dart';
import '../../job_opportunities/widgets/job_interview_call.dart';
import '../../job_opportunities/widgets/upcoming_interview_banner.dart';
import '../../messaging/messaging_providers.dart';
import '../../notifications/notification_providers.dart';
import '../../service_coordinator/presentation/sc_providers.dart';
import '../../agency_platform/widgets/bloomora_compliance_disclaimer.dart';
import '../../agency_platform/widgets/agency_operational_alerts_banner.dart';
import 'agency_providers.dart';

class AgencyHomeScreen extends ConsumerWidget {
  const AgencyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(agencyDashboardProvider);
    final upcoming = ref.watch(agencyUpcomingAppointmentsProvider);
    final unreadMessages = ref.watch(unreadMessageThreadsProvider);
    final unreadMessageCount = unreadMessages.maybeWhen(
      data: (c) => c,
      orElse: () => 0,
    );
    final jobApplicantCount = ref.watch(agencyJobOpportunitiesProvider).maybeWhen(
          data: (jobs) => jobs.fold<int>(
            0,
            (sum, job) => sum + (job.applicationCount ?? 0),
          ),
          orElse: () => 0,
        );
    final upcomingInterviewCount =
        ref.watch(agencyJobInterviewsProvider).maybeWhen(
              data: (interviews) => interviews
                  .where(
                    (interview) =>
                        interviewIsActive(interview) &&
                        interview.scheduledAt.isAfter(DateTime.now()),
                  )
                  .length,
              orElse: () => 0,
            );
    final upcomingInterviews = ref.watch(agencyJobInterviewsProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <JobInterviewModel>[],
        );
    final hiringPipeline = ref.watch(agencyHiringPipelineSummaryProvider);
    final hiringPendingCount = hiringPipeline.maybeWhen(
      data: (summary) => summary.totalPendingActions,
      orElse: () => 0,
    );
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final greetingName =
        user?.fullName?.split(' ').first ?? user?.email.split('@').first ?? 'there';

    return AppScaffold(
      title: 'Agency dashboard',
      subtitle: 'Provider network operations',
      constrainBodyOnWide: false,
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.home),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(agencyDashboardProvider);
          ref.invalidate(agencyTherapistsProvider);
          ref.invalidate(agencyRosterMembersProvider);
          ref.invalidate(agencyCasesProvider);
          ref.invalidate(agencyAnalyticsProvider);
          ref.invalidate(agencyUpcomingAppointmentsProvider);
          ref.invalidate(unreadNotificationsProvider);
          ref.invalidate(agencyJobOpportunitiesProvider);
          ref.invalidate(agencyJobInterviewsProvider);
          ref.invalidate(agencyHiringPipelineSummaryProvider);
        },
        child: AppContentContainer(
          padding: EdgeInsets.zero,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppPageHeader(
                  title: 'Welcome back, $greetingName',
                  description:
                      'Manage your provider roster, referrals, appointments, and agency reports.',
                  showBreadcrumbs: false,
                  badge: user != null
                      ? UserRoleBadge(role: user.role, compact: true)
                      : null,
                  actions: [
                    ActionButton(
                      label: 'Agency profile',
                      icon: Icons.business_outlined,
                      onPressed: () => context.push(AppRoutes.agencyProfile),
                      fullWidth: false,
                      size: GlossyButtonSize.medium,
                    ),
                    ActionButton(
                      label: 'Medical charts',
                      icon: Icons.medical_information_outlined,
                      onPressed: () =>
                          context.push('${AppRoutes.agencyHome}/charts'),
                      variant: GlossyButtonVariant.secondary,
                      fullWidth: false,
                      size: GlossyButtonSize.medium,
                    ),
                    ActionButton(
                      label: 'Parent referrals',
                      icon: Icons.storefront_outlined,
                      onPressed: () => context.push(AppRoutes.agencyMarketplace),
                      variant: GlossyButtonVariant.secondary,
                      fullWidth: false,
                      size: GlossyButtonSize.medium,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppTrustNotice(dense: true),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: BloomoraComplianceDisclaimer(dense: true),
              ),
              const AgencyOperationalAlertsBanner(),
              UpcomingInterviewBanner(
                interviews: upcomingInterviews,
                role: UserRole.agency,
              ),
              if (hiringPendingCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Card(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.45),
                    child: ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text(
                        '$hiringPendingCount hiring action${hiringPendingCount == 1 ? '' : 's'} pending',
                      ),
                      subtitle: hiringPipeline.maybeWhen(
                        data: (summary) {
                          final parts = <String>[];
                          if (summary.newApplicants > 0) {
                            parts.add('${summary.newApplicants} new');
                          }
                          if (summary.credentialsSubmitted > 0) {
                            parts.add(
                              '${summary.credentialsSubmitted} credentials',
                            );
                          }
                          if (summary.offersPending > 0) {
                            parts.add('${summary.offersPending} offers out');
                          }
                          if (summary.readyToHire > 0) {
                            parts.add('${summary.readyToHire} ready to hire');
                          }
                          return Text(parts.join(' · '));
                        },
                        orElse: () => const Text(
                          'Review applicants across job postings',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.agencyOpportunities),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: dashboard.when(
                  data: (d) {
                    final opsLoad = (d.missingEvvCount + d.draftClaimsCount) > 0
                        ? 0.55
                        : 0.9;
                    return AppWellnessJourneyCard(
                      title: 'Agency Operations',
                      subtitle: d.pendingTherapists > 0
                          ? '${d.pendingTherapists} provider(s) awaiting approval'
                          : 'Roster and billing on track',
                      progress: opsLoad,
                      icon: Icons.business_outlined,
                    );
                  },
                  loading: () => const AppWellnessJourneyCard(
                    title: 'Agency Operations',
                    subtitle: 'Loading…',
                    progress: 0,
                  ),
                  error: (_, _) => const AppWellnessJourneyCard(
                    title: 'Agency Operations',
                    subtitle: 'Agency operations at a glance',
                    progress: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppWellnessActionMenu(
                  items: [
                    AppWellnessActionItem(
                      label: 'Therapist Roster',
                      icon: Icons.groups_outlined,
                      variant: AppGlossyButtonVariant.primary,
                      onTap: () =>
                          context.push('${AppRoutes.agencyHome}/roster'),
                    ),
                    AppWellnessActionItem(
                      label: 'Case assignments',
                      icon: Icons.folder_shared_outlined,
                      variant: AppGlossyButtonVariant.secondary,
                      onTap: () => context.push('${AppRoutes.agencyHome}/cases'),
                    ),
                    AppWellnessActionItem(
                      label: 'Appointments',
                      icon: Icons.event_outlined,
                      variant: AppGlossyButtonVariant.secondary,
                      onTap: () => context.push(
                        '${AppRoutes.agencyHome}/appointments',
                      ),
                    ),
                    AppWellnessActionItem(
                      label: 'Session Notes',
                      icon: Icons.description_outlined,
                      variant: AppGlossyButtonVariant.tertiary,
                      onTap: () => context.push(
                        '${AppRoutes.agencyHome}/session-notes',
                      ),
                    ),
                    AppWellnessActionItem(
                      label: 'Analytics',
                      icon: Icons.analytics_outlined,
                      variant: AppGlossyButtonVariant.warning,
                      onTap: () =>
                          context.push('${AppRoutes.agencyHome}/analytics'),
                    ),
                    AppWellnessActionItem(
                      label: 'Call audit',
                      icon: Icons.call_outlined,
                      variant: AppGlossyButtonVariant.neutral,
                      onTap: () =>
                          context.push('${AppRoutes.agencyHome}/call-audit'),
                    ),
                    AppWellnessActionItem(
                      label: hiringPendingCount > 0
                          ? 'Job opportunities ($hiringPendingCount hiring actions)'
                          : jobApplicantCount > 0
                              ? 'Job opportunities ($jobApplicantCount applicants)'
                              : 'Job opportunities',
                      icon: Icons.work_outline,
                      variant: AppGlossyButtonVariant.secondary,
                      onTap: () => context.push(AppRoutes.agencyOpportunities),
                    ),
                    AppWellnessActionItem(
                      label: upcomingInterviewCount > 0
                          ? 'Interview calendar ($upcomingInterviewCount upcoming)'
                          : 'Interview calendar',
                      icon: Icons.video_call_outlined,
                      variant: AppGlossyButtonVariant.secondary,
                      onTap: () => context.push(AppRoutes.agencyInterviews),
                    ),
                    AppWellnessActionItem(
                      label: 'Service needs',
                      icon: Icons.medical_services_outlined,
                      variant: AppGlossyButtonVariant.secondary,
                      onTap: () => context.push(AppRoutes.agencyServiceNeeds),
                    ),
                    AppWellnessActionItem(
                      label: 'Marketplace',
                      icon: Icons.storefront_outlined,
                      variant: AppGlossyButtonVariant.primary,
                      onTap: () =>
                          context.push(AppRoutes.agencyMarketplace),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppSectionHeader(
                  title: 'Overview',
                  subtitle: 'Agency operations at a glance',
                ),
              ),
              const SizedBox(height: 12),
              dashboard.when(
                data: (d) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AppStatCard(
                          label: 'Therapists',
                          value: '${d.therapistCount}',
                          icon: Icons.groups_outlined,
                          onTap: () =>
                              context.push('${AppRoutes.agencyHome}/roster'),
                        ),
                        AppStatCard(
                          label: 'Active clients',
                          value: '${d.activeClients}',
                          icon: Icons.people_outline,
                          onTap: () =>
                              context.push('${AppRoutes.agencyHome}/analytics'),
                        ),
                        AppStatCard(
                          label: 'Sessions today',
                          value: '${d.appointmentsToday}',
                          icon: Icons.event_outlined,
                          accent: d.appointmentsToday > 0,
                          onTap: () => context.push(
                            '${AppRoutes.agencyHome}/appointments',
                          ),
                        ),
                        AppStatCard(
                          label: 'Pending verify',
                          value: '${d.pendingTherapists}',
                          highlight: d.pendingTherapists > 0,
                          icon: Icons.verified_user_outlined,
                          onTap: () =>
                              context.push('${AppRoutes.agencyHome}/roster'),
                        ),
                        AppStatCard(
                          label: 'Service coordinators',
                          value: '${d.serviceCoordinatorCount}',
                          icon: Icons.support_agent_outlined,
                          onTap: () =>
                              context.push('${AppRoutes.agencyHome}/roster'),
                        ),
                        AppStatCard(
                          label: 'SC caseload',
                          value: '${d.activeScCaseload}',
                          icon: Icons.folder_shared_outlined,
                          onTap: () =>
                              context.push('${AppRoutes.agencyHome}/cases'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const AppSectionHeader(title: 'Operations board'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AppStatCard(
                          label: 'Missing EVV',
                          value: '${d.missingEvvCount}',
                          highlight: d.missingEvvCount > 0,
                          icon: Icons.location_off_outlined,
                          onTap: () => context.push(
                            '${AppRoutes.agencyHome}/appointments',
                          ),
                        ),
                        AppStatCard(
                          label: 'Draft claims',
                          value: '${d.draftClaimsCount}',
                          highlight: d.draftClaimsCount > 0,
                          icon: Icons.receipt_long_outlined,
                          onTap: () =>
                              context.push('${AppRoutes.agencyHome}/analytics'),
                        ),
                        AppStatCard(
                          label: 'Cancels today',
                          value: '${d.cancellationsToday}',
                          icon: Icons.event_busy_outlined,
                          onTap: () => context.push(
                            '${AppRoutes.agencyHome}/appointments',
                          ),
                        ),
                        AppStatCard(
                          label: 'Urgent SC cases',
                          value: '${d.urgentScCases}',
                          highlight: d.urgentScCases > 0,
                          icon: Icons.priority_high,
                          onTap: () =>
                              context.push('${AppRoutes.agencyHome}/cases'),
                        ),
                        AppStatCard(
                          label: 'SC follow-ups due',
                          value: '${d.scFollowUpsDue}',
                          highlight: d.scFollowUpsDue > 0,
                          icon: Icons.event_repeat_outlined,
                          onTap: () =>
                              context.push('${AppRoutes.agencyHome}/cases'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DashboardActionInbox(
                      items: d.actionItems
                          .map((e) => DashboardActionModel.fromJson(e))
                          .toList(),
                    ),
                  ],
                ),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Overview error: $e'),
                ),
              ),
              const SizedBox(height: 12),
              upcoming.when(
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Upcoming sessions',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.push(
                              '${AppRoutes.agencyHome}/appointments',
                            ),
                            child: const Text('All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...list
                          .take(3)
                          .map(
                            (a) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  '${a.childName} · ${a.therapyType}',
                                ),
                                subtitle: Text(
                                  '${a.therapistName}\n'
                                  '${DateFormat.yMMMd().add_jm().format(a.scheduledStart)} · ${a.locationType}',
                                ),
                                isThreeLine: true,
                                trailing: Chip(label: Text(a.status)),
                              ),
                            ),
                          ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              Text('Operations', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Manage your roster, invites, analytics, and today’s session load.',
              ),
              const SizedBox(height: 16),
              _OpsTile(
                title: 'Therapist roster',
                subtitle: 'View roster and remove therapists',
                icon: Icons.groups,
                onTap: () => context.push('${AppRoutes.agencyHome}/roster'),
              ),
              _OpsTile(
                title: 'Case assignments',
                subtitle: 'Assign children to service coordinators',
                icon: Icons.folder_shared_outlined,
                onTap: () => context.push('${AppRoutes.agencyHome}/cases'),
              ),
              _OpsTile(
                title: 'Invite therapists',
                subtitle: 'Add verified therapists to your agency',
                icon: Icons.person_add,
                onTap: () => context.push('${AppRoutes.agencyHome}/invites'),
              ),
              _OpsTile(
                title: 'Platform analytics',
                subtitle: 'Sessions, revenue, and activity metrics',
                icon: Icons.insights,
                onTap: () => context.push('${AppRoutes.agencyHome}/analytics'),
              ),
              _OpsTile(
                title: 'Marketplace browse',
                subtitle: 'View anonymous parent service requests by ZIP area',
                icon: Icons.storefront_outlined,
                onTap: () => context.push(AppRoutes.agencyMarketplace),
              ),
              _OpsTile(
                title: 'Appointments overview',
                subtitle: 'Today’s scheduled sessions across the agency',
                icon: Icons.event,
                onTap: () =>
                    context.push('${AppRoutes.agencyHome}/appointments'),
              ),
              _OpsTile(
                title: 'Session Notes and Service logs',
                subtitle: 'Review session notes and download parent-signed logs',
                icon: Icons.assignment_outlined,
                onTap: () =>
                    context.push('${AppRoutes.agencyHome}/session-notes'),
              ),
              _OpsTile(
                title: 'NY EI billing',
                subtitle: 'Medicaid EI claims, enrollment, and claim queue',
                icon: Icons.receipt_long_outlined,
                onTap: () => context.push(AppRoutes.agencyEiBilling),
              ),
              _OpsTile(
                title: unreadMessageCount > 0
                    ? 'Messages ($unreadMessageCount unread)'
                    : 'Messages',
                subtitle: unreadMessageCount > 0
                    ? 'Threads need a reply'
                    : 'Chat with parents and therapists',
                icon: Icons.message,
                onTap: () => context.push(AppRoutes.messages),
              ),
              const SizedBox(height: 12),
              Text('Account', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _OpsTile(
                title: 'Security',
                subtitle: 'Two-factor authentication and trusted devices',
                icon: Icons.security,
                onTap: () => context.push(AppRoutes.security),
              ),
              _OpsTile(
                title: 'Privacy & HIPAA',
                subtitle: 'Notice, policy, rights requests, PHI access report',
                icon: Icons.privacy_tip,
                onTap: () => context.push(AppRoutes.settingsPrivacy),
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: pull down to refresh counts on this screen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpsTile extends StatelessWidget {
  const _OpsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
