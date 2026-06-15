import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../core/providers/app_providers.dart';

final pendingLegalDocumentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(privacyRepositoryProvider).listPendingLegalDocuments();
    });

class LegalDocumentsScreen extends ConsumerWidget {
  const LegalDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(pendingLegalDocumentsProvider);

    return AppScaffold(
      title: 'Legal & policies',
      body: docs.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No documents require acceptance.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = list[index];
              final accepted = doc['accepted'] == true;
              return ListTile(
                title: Text(doc['title']?.toString() ?? 'Document'),
                subtitle: Text(
                  'Version ${doc['version']} · ${accepted ? 'Accepted' : 'Acceptance required'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '${AppRoutes.legalDocuments}/detail?id=${doc['id']}',
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class LegalDocumentDetailScreen extends ConsumerStatefulWidget {
  const LegalDocumentDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<LegalDocumentDetailScreen> createState() =>
      _LegalDocumentDetailScreenState();
}

class _LegalDocumentDetailScreenState
    extends ConsumerState<LegalDocumentDetailScreen> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(pendingLegalDocumentsProvider);
    final doc = docs.maybeWhen(
      data: (list) => list.cast<Map<String, dynamic>?>().firstWhere(
        (d) => d?['id'] == widget.documentId,
        orElse: () => null,
      ),
      orElse: () => null,
    );

    return AppScaffold(
      title: doc?['title']?.toString() ?? 'Document',
      body: doc == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  doc['content']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (doc['accepted'] != true)
                  GlossyButton(
                    title: 'I accept',
                    variant: GlossyButtonVariant.greenTeal,
                    loading: _accepting,
                    onPressed: () async {
                      setState(() => _accepting = true);
                      try {
                        await ref
                            .read(privacyRepositoryProvider)
                            .acceptLegalDocument(widget.documentId);
                        ref.invalidate(pendingLegalDocumentsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Document accepted'),
                            ),
                          );
                          context.pop();
                        }
                      } finally {
                        if (mounted) setState(() => _accepting = false);
                      }
                    },
                  ),
              ],
            ),
    );
  }
}
