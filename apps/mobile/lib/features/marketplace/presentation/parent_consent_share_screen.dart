import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../../platform/data/platform_repository.dart';
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
  var _loadingDocs = true;
  String? _childId;
  List<DocumentItemModel> _childDocuments = [];
  final Set<String> _selectedDocumentIds = {};
  String? _loadError;

  String get _consentText =>
      'I authorize this app to share my child\'s profile, contact information, '
      'service needs, and selected documents with ${widget.providerName} for '
      'evaluation, referral, care coordination, or service matching.';

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    setState(() {
      _loadingDocs = true;
      _loadError = null;
    });
    try {
      final marketplace = ref.read(marketplaceRepositoryProvider);
      final requests = await marketplace.fetchMyRequests();
      MarketplaceRequestModel? request;
      for (final r in requests) {
        if (r.id == widget.marketplaceRequestId) {
          request = r;
          break;
        }
      }
      final childId = request?.childId;
      if (childId == null) {
        if (mounted) {
          setState(() {
            _childId = null;
            _childDocuments = [];
          });
        }
        return;
      }

      final allDocs = await ref.read(platformRepositoryProvider).fetchDocuments();
      final childDocs =
          allDocs.where((doc) => doc.childId == childId).toList();
      if (mounted) {
        setState(() {
          _childId = childId;
          _childDocuments = childDocs;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  Future<void> _grant() async {
    if (!_consent) return;
    setState(() => _submitting = true);
    try {
      await ref.read(marketplaceRepositoryProvider).grantShareConsent(
            marketplaceRequestId: widget.marketplaceRequestId,
            providerProfileId: widget.providerProfileId,
            documentIds: _selectedDocumentIds.toList(),
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
    return ParentTabScaffold(
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
          if (_loadingDocs)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load sharing context',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppSnackBar.messageFromError(_loadError!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    GlossyButton(
                      title: 'Retry',
                      icon: Icons.refresh_rounded,
                      variant: GlossyButtonVariant.neutral,
                      onPressed: _loadContext,
                    ),
                  ],
                ),
              ),
            )
          else if (_childId == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'This marketplace request could not be found or is no longer active. '
                  'Return to your dashboard and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            Text(
              'Optional documents to share',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_childDocuments.isEmpty)
              const Text(
                'No documents on file for this child. You can still share profile and contact details.',
              )
            else ...[
              Row(
                children: [
                  Text(
                    '${_selectedDocumentIds.length} of ${_childDocuments.length} selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDocumentIds
                          ..clear()
                          ..addAll(_childDocuments.map((doc) => doc.id));
                      });
                    },
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    onPressed: _selectedDocumentIds.isEmpty
                        ? null
                        : () => setState(_selectedDocumentIds.clear),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              ..._childDocuments.map(
                (doc) => CheckboxListTile(
                  value: _selectedDocumentIds.contains(doc.id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedDocumentIds.add(doc.id);
                      } else {
                        _selectedDocumentIds.remove(doc.id);
                      }
                    });
                  },
                  title: Text(doc.title),
                  subtitle: Text('${doc.type} · ${doc.fileName}'),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
          if (!_loadingDocs && _loadError == null && _childId != null) ...[
            CheckboxListTile(
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text('I authorize sharing as described above'),
            ),
            const SizedBox(height: 16),
            GlossyButton(
              title: 'Grant consent & share',
              variant: GlossyButtonVariant.greenTeal,
              loading: _submitting,
              disabled: !_consent,
              onPressed: _grant,
            ),
          ],
        ],
      ),
    );
  }
}
