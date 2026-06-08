import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../agency/data/agency_repository.dart';
import '../models/session_note_editor_mode.dart';
import '../../../shared/widgets/app_scaffold.dart';

final agencySessionNotesProvider =
    FutureProvider<List<StaffSessionNoteSummaryModel>>((ref) async {
  return ref.read(agencyRepositoryProvider).fetchSessionNotes();
});

final adminSessionNotesProvider =
    FutureProvider<List<StaffSessionNoteSummaryModel>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchSessionNotes();
});

class StaffSessionNotesScreen extends ConsumerWidget {
  const StaffSessionNotesScreen({
    super.key,
    required this.editorMode,
    required this.formRoutePrefix,
  });

  final SessionNoteEditorMode editorMode;
  final String formRoutePrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = editorMode == SessionNoteEditorMode.agency
        ? ref.watch(agencySessionNotesProvider)
        : ref.watch(adminSessionNotesProvider);

    final title = editorMode == SessionNoteEditorMode.agency
        ? 'Session notes'
        : 'Session notes (admin)';

    return AppScaffold(
      title: title,
      body: RefreshIndicator(
        onRefresh: () async {
          if (editorMode == SessionNoteEditorMode.agency) {
            ref.invalidate(agencySessionNotesProvider);
            await ref.read(agencySessionNotesProvider.future);
          } else {
            ref.invalidate(adminSessionNotesProvider);
            await ref.read(adminSessionNotesProvider.future);
          }
        },
        child: notes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No documented session notes yet.')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final note = list[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      note.isFullySigned
                          ? Icons.lock_open_outlined
                          : Icons.edit_note_outlined,
                    ),
                    title: Text(note.childName),
                    subtitle: Text(
                      [
                        note.therapistName,
                        if (note.sessionDate != null) note.sessionDate!,
                        if (note.isFullySigned) 'Fully signed',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('$formRoutePrefix/${note.sessionId}/form'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
