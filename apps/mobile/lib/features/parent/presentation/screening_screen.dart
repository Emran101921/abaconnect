import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';

class ScreeningScreen extends ConsumerStatefulWidget {
  const ScreeningScreen({super.key});

  @override
  ConsumerState<ScreeningScreen> createState() => _ScreeningScreenState();
}

class _ScreeningScreenState extends ConsumerState<ScreeningScreen> {
  List<ScreeningTemplateModel> _templates = [];
  List<ChildModel> _children = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(parentBookingRepositoryProvider);
    try {
      final templates = await repo.fetchScreeningTemplates();
      final children = await repo.fetchChildren();
      if (mounted) {
        setState(() {
          _templates = templates;
          _children = children;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load screening: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _parseQuestions(ScreeningTemplateModel template) {
    if (template.questionsJson == null) return [];
    try {
      final decoded = jsonDecode(template.questionsJson!);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _completeTemplate(ScreeningTemplateModel template) async {
    if (_children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a child before completing screening')),
      );
      return;
    }

    final questions = _parseQuestions(template);
    final answers = <String, dynamic>{};

    if (questions.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(template.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: questions.map((q) {
                  final id = q['id'] as String? ?? 'q';
                  final label = q['label'] as String? ?? id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      decoration: InputDecoration(labelText: label),
                      onChanged: (v) => answers[id] = v,
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
      if (ok != true) return;
    } else {
      answers['completed'] = true;
    }

    try {
      await ref.read(parentBookingRepositoryProvider).submitScreening(
            templateId: template.id,
            childId: _children.first.id,
            responses: answers,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${template.name} submitted')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Screening',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Intake Assessment',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _children.isEmpty
                      ? 'Add a child profile to complete forms.'
                      : 'Forms for ${_children.first.displayName}',
                ),
                const SizedBox(height: 24),
                if (_templates.isEmpty)
                  const Text('No screening templates configured.')
                else
                  ..._templates.map(
                    (t) {
                      final qCount = _parseQuestions(t).length;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                            '${t.therapyType} · $qCount question(s)',
                          ),
                          trailing: FilledButton(
                            onPressed: () => _completeTemplate(t),
                            child: const Text('Start'),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
