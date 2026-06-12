import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
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
      final details = await ref
          .read(marketplaceRepositoryProvider)
          .fetchAuthorizedChildDetails(widget.marketplaceRequestId);
      if (mounted) setState(() => _details = details);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Authorized child details',
      subtitle: 'Visible only after parent consent',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Access denied or consent not granted.\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _details == null
                  ? const Center(child: Text('No authorized details available.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
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
                        _Section(
                          title: 'Parent / guardian contact',
                          lines: [
                            'Name: ${_details!.parentName}',
                            if (_details!.parentEmail != null)
                              'Email: ${_details!.parentEmail}',
                            if (_details!.parentPhone != null)
                              'Phone: ${_details!.parentPhone}',
                          ],
                        ),
                        if (_details!.sharedDocuments.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _Section(
                            title: 'Shared documents',
                            lines: _details!.sharedDocuments
                                .map(
                                  (doc) =>
                                      '${doc.title} (${doc.type}) · ${doc.fileName}',
                                )
                                .toList(),
                          ),
                        ],
                      ],
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
