import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/privacy_repository.dart';

enum PrivacyDocumentKind { noticeOfPractices, privacyPolicy }

final privacyDocumentProvider =
    FutureProvider.family<PrivacyDocumentModel, PrivacyDocumentKind>((
      ref,
      kind,
    ) {
      final repo = ref.watch(privacyRepositoryProvider);
      switch (kind) {
        case PrivacyDocumentKind.noticeOfPractices:
          return repo.fetchFullNotice();
        case PrivacyDocumentKind.privacyPolicy:
          return repo.fetchPrivacyPolicy();
      }
    });

class PrivacyDocumentScreen extends ConsumerWidget {
  const PrivacyDocumentScreen({super.key, required this.kind});

  final PrivacyDocumentKind kind;

  String get _title => switch (kind) {
    PrivacyDocumentKind.noticeOfPractices => 'Notice of Privacy Practices',
    PrivacyDocumentKind.privacyPolicy => 'Privacy Policy',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(privacyDocumentProvider(kind));
    final theme = Theme.of(context);

    return AppScaffold(
      title: _title,
      body: doc.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Unable to load document. Please try again.'),
        ),
        data: (document) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Notice Version: ${document.versionNumber}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Effective: ${document.effectiveDate.toLocal().toString().split(' ').first}',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 32),
            SelectableText(
              document.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}
