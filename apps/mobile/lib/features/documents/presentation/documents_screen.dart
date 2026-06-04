import 'package:file_picker/file_picker.dart';
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
        onPressed: () => _pickAndUpload(context, ref),
        child: const Icon(Icons.upload_file),
      ),
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No documents. Tap + to upload a file.'),
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
                    onTap: () => _download(context, ref, d),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    var docType = 'OTHER';

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: docType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  DropdownMenuItem(
                    value: 'INSURANCE_CARD',
                    child: Text('Insurance card'),
                  ),
                  DropdownMenuItem(value: 'IEP', child: Text('IEP')),
                  DropdownMenuItem(
                    value: 'EVALUATION_REPORT',
                    child: Text('Evaluation report'),
                  ),
                  DropdownMenuItem(
                    value: 'CONSENT_FORM',
                    child: Text('Consent form'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => docType = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Choose file')),
          ],
        ),
      ),
    );
    if (proceed != true || !context.mounted) return;

    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file bytes')),
        );
      }
      return;
    }

    try {
      await ref.read(platformRepositoryProvider).uploadDocumentFile(
            title: titleController.text.trim().isEmpty
                ? (file.name)
                : titleController.text.trim(),
            fileName: file.name,
            bytes: bytes,
            mimeType: file.extension != null
                ? _mimeFromExtension(file.extension!)
                : 'application/octet-stream',
            type: docType,
          );
      ref.invalidate(documentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded')),
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

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    DocumentItemModel doc,
  ) async {
    try {
      final path = await ref
          .read(platformRepositoryProvider)
          .downloadDocumentFile(doc.id, doc.fileName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path.isEmpty ? 'Download started' : 'Saved: $path'),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
