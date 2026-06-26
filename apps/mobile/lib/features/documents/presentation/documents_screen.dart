import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/document_upload.dart';
import '../../../shared/models/user_role.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../parent/data/parent_booking_repository.dart';
import '../../platform/data/platform_repository.dart';
import '../../therapist/models/therapist_employment_document_requirements.dart';
import '../widgets/employment_document_title_picker.dart';

final documentsProvider = FutureProvider<List<DocumentItemModel>>((ref) {
  return ref.watch(platformRepositoryProvider).fetchDocuments();
});

final documentChildrenProvider = FutureProvider<List<ChildModel>>((ref) async {
  final session = ref.watch(authStateProvider).valueOrNull;
  if (session?.user.role != UserRole.parent) {
    return [];
  }
  return ref.watch(parentBookingRepositoryProvider).fetchChildren();
});

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);
    final role = ref.watch(authStateProvider).valueOrNull?.user.role;
    final isTherapist = role == UserRole.therapist;

    return AppScaffold(
      title: 'Documents',
      floatingActionButton: GlossyFab(
        icon: Icons.upload_file,
        onPressed: () => _pickAndUpload(context, ref),
        tooltip: 'Upload document',
      ),
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(documentsProvider);
                await ref.read(documentsProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (isTherapist) const _TherapistDocumentsHint(),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text('No documents. Tap + to upload a file.'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(documentsProvider);
              await ref.read(documentsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length + (isTherapist ? 1 : 0),
              itemBuilder: (context, index) {
                if (isTherapist && index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: _TherapistDocumentsHint(),
                  );
                }
                final docIndex = isTherapist ? index - 1 : index;
                final d = list[docIndex];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.description),
                    title: _ScrollableDocumentTitle(text: d.title),
                    subtitle: Text(
                      '${d.fileName} · ${d.type}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'download') {
                          await _download(context, ref, d);
                        } else if (v == 'delete') {
                          await _delete(context, ref, d);
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'download',
                          child: Text('Download'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
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
    final session = ref.read(authStateProvider).valueOrNull;
    final isParent = session?.user.role == UserRole.parent;
    final isTherapist = session?.user.role == UserRole.therapist;
    final children = isParent
        ? await ref.read(documentChildrenProvider.future)
        : <ChildModel>[];
    if (!context.mounted) return;

    final titleController = TextEditingController();
    var docType = 'OTHER';
    String? childId;

    try {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void selectRequirement(TherapistDocumentRequirement req) {
            setDialogState(() {
              titleController.text = req.label;
              titleController.selection = TextSelection.collapsed(
                offset: req.label.length,
              );
              docType = req.suggestedUploadType;
            });
          }

          return AlertDialog(
          title: const Text('Upload document'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isTherapist) ...[
                    EmploymentDocumentTitlePicker(
                      selectedTitle: titleController.text,
                      onSelect: selectRequirement,
                      maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: isTherapist
                          ? 'Selected title appears here'
                          : 'Enter document title',
                    ),
                    minLines: 1,
                    maxLines: 4,
                    scrollPhysics: const AlwaysScrollableScrollPhysics(),
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: docType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: 'OTHER',
                        child: Text('Other'),
                      ),
                      const DropdownMenuItem(
                        value: 'SOAP_NOTE',
                        child: Text('SOAP note'),
                      ),
                      const DropdownMenuItem(
                        value: 'PROGRESS_REPORT',
                        child: Text('Progress report'),
                      ),
                      const DropdownMenuItem(
                        value: 'LICENSE',
                        child: Text('License'),
                      ),
                      const DropdownMenuItem(
                        value: 'CERTIFICATION',
                        child: Text('Certification / insurance'),
                      ),
                      const DropdownMenuItem(
                        value: 'TREATMENT_PLAN',
                        child: Text('Treatment plan'),
                      ),
                      const DropdownMenuItem(
                        value: 'INSURANCE_CARD',
                        child: Text('Insurance card'),
                      ),
                      const DropdownMenuItem(value: 'IEP', child: Text('IEP')),
                      const DropdownMenuItem(
                        value: 'EVALUATION_REPORT',
                        child: Text('Evaluation report'),
                      ),
                      const DropdownMenuItem(
                        value: 'CONSENT_FORM',
                        child: Text('Consent / signed form'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => docType = v);
                    },
                  ),
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: childId,
                      decoration: const InputDecoration(
                        labelText: 'Child (optional)',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No specific child'),
                        ),
                        ...children.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.displayName),
                          ),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => childId = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            GlossyButton(
              title: 'Choose file',
              size: GlossyButtonSize.small,
              fullWidth: false,
              variant: GlossyButtonVariant.bluePurple,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
        },
      ),
    );
    if (proceed != true || !context.mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: documentUploadExtensions,
      withData: true,
    );
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

    final mimeType = file.extension != null
        ? mimeFromExtension(file.extension!)
        : 'application/octet-stream';
    final validationError = validateDocumentUpload(
      extension: file.extension,
      mimeType: mimeType,
    );
    if (validationError != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
      }
      return;
    }

    try {
      await ref
          .read(platformRepositoryProvider)
          .uploadDocumentFile(
            title: titleController.text.trim().isEmpty
                ? file.name
                : titleController.text.trim(),
            fileName: file.name,
            bytes: bytes,
            mimeType: mimeType,
            type: docType,
            childId: childId,
          );
      ref.invalidate(documentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document uploaded')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatUploadError(e))),
        );
      }
    }
    } finally {
      titleController.dispose();
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DocumentItemModel doc,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove "${doc.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: 'Delete',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.redDarkRed,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(platformRepositoryProvider).deleteDocument(doc.id);
      ref.invalidate(documentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

}

/// Horizontally scrollable title for long employment document names.
class _ScrollableDocumentTitle extends StatelessWidget {
  const _ScrollableDocumentTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _TherapistDocumentsHint extends StatelessWidget {
  const _TherapistDocumentsHint();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Upload employment onboarding files here (resume, liability insurance, '
                'W-9, signed I-9, etc.). See My Profile → Employment documents for the full checklist.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
