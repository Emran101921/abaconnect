import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_snackbar.dart';
import '../data/job_opportunities_repository.dart';

class JobCredentialDocumentsSummary extends ConsumerWidget {
  const JobCredentialDocumentsSummary({
    super.key,
    required this.documents,
    this.applicationId,
    this.dense = false,
  });

  final List<JobCredentialDocumentModel> documents;
  final String? applicationId;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (documents.isEmpty) {
      return Text(
        'No credential documents on file',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final dateFormat = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${documents.length} credential document${documents.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (!dense) const SizedBox(height: 8),
        ...documents.take(dense ? 2 : documents.length).map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dense
                            ? doc.title
                            : '${doc.title} · ${doc.type} · ${dateFormat.format(doc.uploadedAt.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (applicationId != null)
                      IconButton(
                        tooltip: 'Download',
                        icon: const Icon(Icons.download_outlined, size: 18),
                        onPressed: () => _download(ref, context, doc),
                      ),
                  ],
                ),
              ),
            ),
        if (dense && documents.length > 2)
          Text(
            '+${documents.length - 2} more',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Future<void> _download(
    WidgetRef ref,
    BuildContext context,
    JobCredentialDocumentModel doc,
  ) async {
    if (applicationId == null) return;
    try {
      final path = await ref
          .read(jobOpportunitiesRepositoryProvider)
          .downloadApplicationCredential(
            applicationId: applicationId!,
            documentId: doc.id,
            fileName: doc.fileName,
          );
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Downloaded to $path');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }
}

Future<void> showApplicantCredentialsSheet(
  BuildContext context, {
  required String therapistName,
  required List<JobCredentialDocumentModel> documents,
  String? applicationId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$therapistName credentials',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          JobCredentialDocumentsSummary(
            documents: documents,
            applicationId: applicationId,
          ),
        ],
      ),
    ),
  );
}
