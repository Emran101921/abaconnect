import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/marketplace_repository.dart';

class ParentConsentHistoryScreen extends ConsumerStatefulWidget {
  const ParentConsentHistoryScreen({
    super.key,
    required this.marketplaceRequestId,
  });

  final String marketplaceRequestId;

  @override
  ConsumerState<ParentConsentHistoryScreen> createState() =>
      _ParentConsentHistoryScreenState();
}

class _ParentConsentHistoryScreenState
    extends ConsumerState<ParentConsentHistoryScreen> {
  var _loading = true;
  var _revoking = false;
  List<MarketplaceConsentModel> _records = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await ref
          .read(marketplaceRepositoryProvider)
          .fetchConsentHistory(widget.marketplaceRequestId);
      if (mounted) setState(() => _records = records);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(MarketplaceConsentModel record) async {
    if (record.providerId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke consent?'),
        content: Text(
          'This will remove ${record.providerName ?? 'the provider'}\'s access '
          'to your child\'s identifiable details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: 'Revoke',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.redDarkRed,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _revoking = true);
    try {
      await ref.read(marketplaceRepositoryProvider).revokeShareConsent(
            marketplaceRequestId: widget.marketplaceRequestId,
            providerProfileId: record.providerId!,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consent revoked. Provider access removed.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoke failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ParentTabScaffold(
      title: 'Consent history',
      subtitle: 'Review and revoke sharing permissions',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load consent history',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppSnackBar.messageFromError(_error!),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        GlossyButton(
                          title: 'Retry',
                          icon: Icons.refresh_rounded,
                          variant: GlossyButtonVariant.neutral,
                          onPressed: _load,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _records.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.2,
                            ),
                            Icon(
                              Icons.verified_user_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                'No consent records yet.\n'
                                'Sharing permissions you grant to providers appear here.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _records.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            return Card(
                              child: ListTile(
                                title: Text(_labelForType(record.consentType)),
                                subtitle: Text(
                                  '${record.providerName ?? 'Marketplace'}\n'
                                  '${DateFormat.yMMMd().add_jm().format(record.createdAt)}'
                                  '${record.revokedAt != null ? '\nRevoked ${DateFormat.yMMMd().format(record.revokedAt!)}' : ''}',
                                ),
                                isThreeLine: true,
                                trailing: record.isActiveShareConsent
                                    ? TextButton(
                                        onPressed:
                                            _revoking ? null : () => _revoke(record),
                                        child: const Text('Revoke'),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  String _labelForType(String type) {
    switch (type) {
      case 'ANONYMOUS_MARKETPLACE_POSTING':
        return 'Anonymous marketplace posting';
      case 'SHARE_IDENTIFIABLE_INFO':
        return 'Share identifiable info';
      case 'SHARE_DOCUMENTS':
        return 'Share selected documents';
      case 'REVOKE_CONSENT':
        return 'Consent revoked';
      default:
        return type.replaceAll('_', ' ').toLowerCase();
    }
  }
}
