import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/marketplace_repository.dart';

class ProviderAuthorizedChildScreen extends ConsumerStatefulWidget {
  const ProviderAuthorizedChildScreen({
    super.key,
    required this.marketplaceRequestId,
  });

  final String marketplaceRequestId;

  @override
  ConsumerState<ProviderAuthorizedChildScreen> createState() =>
      _ProviderAuthorizedChildScreenState();
}

class _ProviderAuthorizedChildScreenState
    extends ConsumerState<ProviderAuthorizedChildScreen> {
  var _loading = true;
  AuthorizedChildDetailsModel? _details;
  Object? _error;

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
      final details = await ref
          .read(marketplaceRepositoryProvider)
          .fetchAuthorizedChildDetails(widget.marketplaceRequestId);
      if (mounted) setState(() => _details = details);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launchContactUri(Uri uri) async {
    if (!await launchUrl(uri)) {
      if (mounted) {
        AppSnackBar.showError(context, 'Could not open ${uri.scheme} link.');
      }
    }
  }

  Future<void> _downloadDocument(MarketplaceSharedDocumentModel doc) async {
    try {
      final path = await ref
          .read(platformRepositoryProvider)
          .downloadDocumentFile(doc.id, doc.fileName);
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        path.isEmpty ? 'Download started' : 'Saved: $path',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Download failed: ${AppSnackBar.messageFromError(e)}',
        );
      }
    }
  }

  Widget _buildErrorBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load authorized details',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Authorized child details',
      subtitle: 'Visible only after parent consent',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorBody(context)
              : _details == null
                  ? const Center(child: Text('No authorized details available.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Card(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Request ${_details!.anonymousPublicId}. Use these details '
                                'only for evaluation, referral, or care coordination.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _Section(
                            title: 'Child',
                            lines: [
                              'Name: ${_details!.firstName} ${_details!.lastName}',
                              'ZIP: ${_details!.zipCode}',
                              if (_details!.city != null)
                                'Area: ${_details!.city}, ${_details!.state ?? ''}',
                              if (_details!.primaryLanguage != null)
                                'Language: ${_details!.primaryLanguage}',
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ContactSection(
                            details: _details!,
                            onLaunchUri: _launchContactUri,
                          ),
                          if (_details!.sharedDocuments.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shared documents',
                                      style:
                                          Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    ..._details!.sharedDocuments.map(
                                      (doc) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.description_outlined),
                                        title: Text(doc.title),
                                        subtitle: Text(
                                          '${doc.type} · ${doc.fileName}',
                                        ),
                                        trailing: const Icon(Icons.download_outlined),
                                        onTap: () => _downloadDocument(doc),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.details,
    required this.onLaunchUri,
  });

  final AuthorizedChildDetailsModel details;
  final Future<void> Function(Uri uri) onLaunchUri;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parent / guardian contact',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Name: ${details.parentName}'),
            if (details.parentEmail != null) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: Text(details.parentEmail!),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => onLaunchUri(
                  Uri(scheme: 'mailto', path: details.parentEmail),
                ),
              ),
            ],
            if (details.parentPhone != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(details.parentPhone!),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () {
                  final digits =
                      details.parentPhone!.replaceAll(RegExp(r'\D'), '');
                  onLaunchUri(Uri(scheme: 'tel', path: digits));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line),
                )),
          ],
        ),
      ),
    );
  }
}
