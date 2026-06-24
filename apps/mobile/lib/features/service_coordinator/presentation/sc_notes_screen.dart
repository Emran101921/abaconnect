import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import 'sc_providers.dart';

class ScNotesScreen extends ConsumerStatefulWidget {
  const ScNotesScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ScNotesScreen> createState() => _ScNotesScreenState();
}

class _ScNotesScreenState extends ConsumerState<ScNotesScreen> {
  final _typeController = TextEditingController(text: 'General');
  final _textController = TextEditingController();
  bool _actionRequired = false;

  @override
  void dispose() {
    _typeController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    if (_textController.text.trim().isEmpty) return;
    try {
      await ref.read(serviceCoordinatorRepositoryProvider).createNote(
        childId: widget.childId,
        noteType: _typeController.text.trim(),
        noteText: _textController.text.trim(),
        actionRequired: _actionRequired,
      );
      _textController.clear();
      ref.invalidate(scCaseDetailProvider(widget.childId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added')),
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseDetail = ref.watch(scCaseDetailProvider(widget.childId));

    return AppScaffold(
      title: 'Coordination notes',
      body: caseDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (detail) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _typeController,
              decoration: const InputDecoration(labelText: 'Note type'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Note text'),
              maxLines: 4,
            ),
            SwitchListTile(
              title: const Text('Action required'),
              value: _actionRequired,
              onChanged: (v) => setState(() => _actionRequired = v),
            ),
            GlossyButton(
              title: 'Add note',
              icon: Icons.add,
              onPressed: _addNote,
            ),
            const SizedBox(height: 24),
            ...detail.notes.map(
              (n) => Card(
                child: ListTile(
                  title: Text(n['noteType'] as String? ?? 'Note'),
                  subtitle: Text(n['noteText'] as String? ?? ''),
                  trailing: n['createdAt'] != null
                      ? Text(
                          DateFormat.yMMMd().format(
                            DateTime.parse(n['createdAt'] as String),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
