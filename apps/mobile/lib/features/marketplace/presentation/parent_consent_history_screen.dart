import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_scaffold.dart';
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
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
    return AppScaffold(
      title: 'Consent history',
      subtitle: 'Review and revoke sharing permissions',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _records.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No consent records yet.')),
                          ],
                        )
                      : ListView.separated(
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
