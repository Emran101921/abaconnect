import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/agency_platform_repository.dart';
import '../../agency/presentation/agency_profile_screen.dart';
import 'agency_platform_providers.dart';

class AgencyReferralsScreen extends ConsumerWidget {
  const AgencyReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = ref.watch(agencyReferralsProvider);

    return AppScaffold(
      title: 'Referrals & outreach',
      subtitle: 'Track intake pipeline from referral to client',
      showPageBreadcrumbs: true,
      actions: [
        GlossyButton(
          title: 'Add referral',
          icon: Icons.add,
          size: GlossyButtonSize.small,
          fullWidth: false,
          onPressed: () => _showAddReferral(context, ref),
        ),
      ],
      body: referrals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No referrals yet. Add one to start intake tracking.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyReferralsProvider);
              await ref.read(agencyReferralsProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final row = list[index];
                      return DashboardCard(
                        title: row.childName ?? row.contactName ?? 'Referral',
                        subtitle: row.sourceName ?? 'Unknown source',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AppStatusBadge.fromKind(
                                  _statusKind(row.status),
                                  label: row.status.replaceAll('_', ' '),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat.MMMd().format(row.createdAt),
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            if (row.contactName != null &&
                                row.childName != null) ...[
                              const SizedBox(height: 8),
                              Text('Contact: ${row.contactName}'),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (!row.isConverted)
                                  FilledButton.tonal(
                                    onPressed: () =>
                                        _convertReferral(context, ref, row),
                                    child: const Text('Convert to client'),
                                  ),
                                if (row.convertedChildId != null)
                                  OutlinedButton(
                                    onPressed: () => context.push(
                                      '${AppRoutes.agencyHome}/children/${row.convertedChildId}/chart?tab=program',
                                    ),
                                    child: const Text('Open chart'),
                                  ),
                                PopupMenuButton<String>(
                                  tooltip: 'Referral actions',
                                  onSelected: (action) async {
                                    if (action == 'convert') {
                                      await _convertReferral(context, ref, row);
                                      return;
                                    }
                                    if (action == 'open_client' &&
                                        row.convertedChildId != null) {
                                      context.push(
                                        '${AppRoutes.agencyHome}/children/${row.convertedChildId}/chart?tab=program',
                                      );
                                      return;
                                    }
                                    await ref
                                        .read(agencyPlatformRepositoryProvider)
                                        .upsertReferral(id: row.id, status: action);
                                    ref.invalidate(agencyReferralsProvider);
                                  },
                                  itemBuilder: (context) => [
                                    if (!row.isConverted)
                                      const PopupMenuItem(
                                        value: 'convert',
                                        child: Text('Convert to caseload client'),
                                      ),
                                    if (row.convertedChildId != null)
                                      const PopupMenuItem(
                                        value: 'open_client',
                                        child: Text('Open client chart'),
                                      ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'CONTACTED',
                                      child: Text('Contacted'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'SCREENING_STARTED',
                                      child: Text('Screening started'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'INTAKE_SCHEDULED',
                                      child: Text('Intake scheduled'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'EVALUATION_NEEDED',
                                      child: Text('Evaluation needed'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'NOT_ELIGIBLE',
                                      child: Text('Not eligible'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'CLOSED',
                                      child: Text('Closed'),
                                    ),
                                  ],
                                  child: const Icon(Icons.more_vert),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  AppStatusKind _statusKind(String status) {
    switch (status) {
      case 'CONVERTED_TO_CLIENT':
        return AppStatusKind.completed;
      case 'NOT_ELIGIBLE':
      case 'CLOSED':
        return AppStatusKind.cancelled;
      default:
        return AppStatusKind.pending;
    }
  }

  Future<void> _showAddReferral(BuildContext context, WidgetRef ref) async {
    final childCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New referral'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: childCtrl,
              decoration: const InputDecoration(labelText: 'Child name'),
            ),
            TextField(
              controller: contactCtrl,
              decoration: const InputDecoration(labelText: 'Contact name'),
            ),
            TextField(
              controller: sourceCtrl,
              decoration: const InputDecoration(labelText: 'Referral source'),
            ),
          ],
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
    await ref.read(agencyPlatformRepositoryProvider).upsertReferral(
          childName: childCtrl.text.trim().isEmpty
              ? null
              : childCtrl.text.trim(),
          contactName: contactCtrl.text.trim().isEmpty
              ? null
              : contactCtrl.text.trim(),
          sourceName:
              sourceCtrl.text.trim().isEmpty ? null : sourceCtrl.text.trim(),
          sourceType: 'community',
        );
    ref.invalidate(agencyReferralsProvider);
  }

  Future<void> _convertReferral(
    BuildContext context,
    WidgetRef ref,
    AgencyReferralModel row,
  ) async {
    final nameParts = (row.childName ?? row.contactName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final firstCtrl = TextEditingController(
      text: nameParts.isNotEmpty ? nameParts.first : '',
    );
    final lastCtrl = TextEditingController(
      text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to caseload client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstCtrl,
              decoration: const InputDecoration(labelText: 'First name'),
              textCapitalization: TextCapitalization.words,
            ),
            TextField(
              controller: lastCtrl,
              decoration: const InputDecoration(labelText: 'Last name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be asked for date of birth on the next step.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final dob = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      helpText: 'Child date of birth',
    );
    if (dob == null || !context.mounted) return;

    try {
      final result = await ref
          .read(agencyPlatformRepositoryProvider)
          .convertReferralToClient(
            referralId: row.id,
            dateOfBirth: dob,
            firstName: firstCtrl.text.trim().isEmpty
                ? null
                : firstCtrl.text.trim(),
            lastName:
                lastCtrl.text.trim().isEmpty ? null : lastCtrl.text.trim(),
          );
      ref.invalidate(agencyReferralsProvider);
      ref.invalidate(agencyManagedChildrenProvider);
      if (!context.mounted) return;
      AppSnackBar.showSuccess(
        context,
        'Referral converted. Client added to agency caseload.',
      );
      context.push(
        '${AppRoutes.agencyHome}/children/${result.childId}/chart?tab=program',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, AppSnackBar.messageFromError(e));
      }
    }
  }
}
