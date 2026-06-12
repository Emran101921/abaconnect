import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../data/marketplace_repository.dart';

class ParentConsentShareScreen extends ConsumerStatefulWidget {
  const ParentConsentShareScreen({
    super.key,
    required this.marketplaceRequestId,
    required this.providerProfileId,
    required this.providerName,
  });

  final String marketplaceRequestId;
  final String providerProfileId;
  final String providerName;

  @override
  ConsumerState<ParentConsentShareScreen> createState() =>
      _ParentConsentShareScreenState();
}

class _ParentConsentShareScreenState
    extends ConsumerState<ParentConsentShareScreen> {
  var _consent = false;
  var _submitting = false;

  String get _consentText =>
      'I authorize this app to share my child\'s profile, contact information, '
      'service needs, and selected documents with ${widget.providerName} for '
      'evaluation, referral, care coordination, or service matching.';

  Future<void> _grant() async {
    if (!_consent) return;
    setState(() => _submitting = true);
    try {
      await ref.read(marketplaceRepositoryProvider).grantShareConsent(
            marketplaceRequestId: widget.marketplaceRequestId,
            providerProfileId: widget.providerProfileId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consent recorded. Details shared.')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Consent failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Share details',
      subtitle: 'Explicit consent required',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Before sharing identifiable information with a selected provider or agency, '
                'review what will be shared. You can revoke consent later.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(_consentText),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: const Text('I authorize sharing as described above'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting || !_consent ? null : _grant,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Grant consent & share'),
          ),
        ],
      ),
    );
  }
}
