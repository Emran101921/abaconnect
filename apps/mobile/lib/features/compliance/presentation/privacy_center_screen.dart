import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/privacy_repository.dart';
import 'hipaa_privacy_notice_screen.dart';

final privacyAckStatusProvider = FutureProvider<AcknowledgmentStatusModel>((
  ref,
) {
  return ref.watch(privacyRepositoryProvider).fetchAcknowledgmentStatus();
});

class PrivacyCenterScreen extends ConsumerWidget {
  const PrivacyCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(privacyAckStatusProvider);

    return AppScaffold(
      title: 'Privacy & HIPAA',
      body: ListView(
        children: [
          status.when(
            data: (s) => s.acknowledged
                ? ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(
                      s.activeVersion != null
                          ? 'Acknowledged Notice v${s.activeVersion}'
                          : 'Notice acknowledged',
                    ),
                    subtitle: s.acknowledgedAt != null
                        ? Text(
                            'On ${s.acknowledgedAt!.toLocal()}',
                          )
                        : null,
                  )
                : Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    margin: const EdgeInsets.all(16),
                    child: ListTile(
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      title: Text(
                        'A new Notice of Privacy Practices requires your acknowledgment.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                      ),
                      trailing: FilledButton(
                        onPressed: () => context.push(
                          AppRoutes.signupPrivacyNotice,
                        ),
                        child: const Text('Review'),
                      ),
                    ),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(),
          _tile(
            context,
            icon: Icons.article_outlined,
            title: 'Notice of Privacy Practices',
            route: AppRoutes.privacyNoticeOfPractices,
          ),
          _tile(
            context,
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            route: AppRoutes.privacyPolicy,
          ),
          _tile(
            context,
            icon: Icons.folder_open_outlined,
            title: 'Request My Records',
            route: AppRoutes.privacyRecordsRequest,
          ),
          _tile(
            context,
            icon: Icons.edit_note_outlined,
            title: 'Request Correction',
            route: AppRoutes.privacyCorrectionRequest,
          ),
          _tile(
            context,
            icon: Icons.block_outlined,
            title: 'Request Restriction',
            route: AppRoutes.privacyRestrictionRequest,
          ),
          _tile(
            context,
            icon: Icons.lock_outline,
            title: 'Request Confidential Communication',
            route: AppRoutes.privacyConfidentialCommunication,
          ),
          _tile(
            context,
            icon: Icons.list_alt_outlined,
            title: 'Request Accounting of Disclosures',
            route: AppRoutes.privacyAccountingOfDisclosures,
          ),
          _tile(
            context,
            icon: Icons.support_agent_outlined,
            title: 'Contact Privacy Officer',
            route: AppRoutes.privacyContactOfficer,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Download My Acknowledgment'),
            onTap: () => _downloadAcknowledgment(context, ref),
          ),
          _tile(
            context,
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account / Data Request',
            route: AppRoutes.privacyDataDeletion,
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('View PHI access report'),
            onTap: () => context.push(AppRoutes.phiAccessReport),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }

  Future<void> _downloadAcknowledgment(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final data = await ref
          .read(privacyRepositoryProvider)
          .downloadAcknowledgment();
      final ack = data['acknowledgment'] as Map<String, dynamic>?;
      if (!context.mounted) return;
      if (ack == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No acknowledgment on file yet.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Your acknowledgment'),
          content: SingleChildScrollView(
            child: SelectableText(
              'Version: ${ack['noticeVersion']}\n'
              'Acknowledged: ${ack['acknowledgedAt']}\n\n'
              '${ack['acknowledgmentTextSnapshot'] ?? ''}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load acknowledgment.')),
        );
      }
    }
  }
}
