import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../platform/data/platform_repository.dart';

final documentsProvider = FutureProvider<List<DocumentItemModel>>((ref) {
  return ref.watch(platformRepositoryProvider).fetchDocuments();
});

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);

    return AppScaffold(
      title: 'Documents',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _uploadDemo(context, ref),
        child: const Icon(Icons.upload_file),
      ),
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No documents. Tap + to register an upload.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(documentsProvider);
              await ref.read(documentsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final d = list[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(d.title),
                    subtitle: Text('${d.fileName} · ${d.type}'),
                    trailing: Text('${(d.fileSize / 1024).round()} KB'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _uploadDemo(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(platformRepositoryProvider).registerDocument(
            title: 'Uploaded document',
            fileName: 'upload_${DateTime.now().millisecondsSinceEpoch}.pdf',
            type: 'OTHER',
          );
      ref.invalidate(documentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document registered')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }
}
