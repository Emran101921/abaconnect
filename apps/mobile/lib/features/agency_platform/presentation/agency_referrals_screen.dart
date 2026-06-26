import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_data_table.dart';
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
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppDataTable<AgencyReferralModel>(
              rows: list,
              searchPredicate: (row, q) {
                final needle = q.toLowerCase();
                return (row.childName ?? '').toLowerCase().contains(needle) ||
                    (row.sourceName ?? '').toLowerCase().contains(needle) ||
                    row.status.toLowerCase().contains(needle);
              },
              columns: [
                AppDataColumn(
                  label: 'Child / contact',
                  mobilePriority: true,
                  cellBuilder: (_, row) => Text(
                    row.childName ?? row.contactName ?? '—',
                  ),
                ),
                AppDataColumn(
                  label: 'Source',
                  cellBuilder: (_, row) => Text(row.sourceName ?? '—'),
                ),
                AppDataColumn(
                  label: 'Status',
                  mobilePriority: true,
                  cellBuilder: (_, row) => AppStatusBadge.fromKind(
                    _statusKind(row.status),
                    label: row.status.replaceAll('_', ' '),
                  ),
                ),
                AppDataColumn(
                  label: 'Created',
                  cellBuilder: (_, row) =>
                      Text(DateFormat.MMMd().format(row.createdAt)),
                ),
                AppDataColumn(
                  label: '',
                  mobilePriority: true,
                  cellBuilder: (context, row) => PopupMenuButton<String>(
                    tooltip: 'Referral actions',
                    onSelected: (action) async {
                      if (action == 'convert') {
                        await _convertReferral(context, ref, row);
                        return;
                      }
                      if (action == 'open_client' && row.convertedChildId != null) {
                        context.push(
                          '${AppRoutes.agencyHome}/children/${row.convertedChildId}',
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
                ),
              ],
            ),
          ],
        ),
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
          );
      ref.invalidate(agencyReferralsProvider);
      ref.invalidate(agencyManagedChildrenProvider);
      if (!context.mounted) return;
      AppSnackBar.showSuccess(
        context,
        'Referral converted. Client added to agency caseload.',
      );
      context.push('${AppRoutes.agencyHome}/children/${result.childId}');
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, AppSnackBar.messageFromError(e));
      }
    }
  }
}
