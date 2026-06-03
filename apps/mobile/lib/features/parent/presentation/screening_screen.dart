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

  Future<void> _completeTemplate(ScreeningTemplateModel template) async {
    if (_children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a child before completing screening')),
      );
      return;
    }
    final childId = _children.first.id;
    try {
      await ref.read(parentBookingRepositoryProvider).submitScreening(
            templateId: template.id,
            childId: childId,
            responses: {'completed': true, 'template': template.name},
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
                    (t) => _FormCard(
                      title: t.name,
                      subtitle: t.therapyType,
                      onComplete: () => _completeTemplate(t),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.subtitle,
    required this.onComplete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onComplete,
              child: const Text('Mark complete'),
            ),
          ],
        ),
      ),
    );
  }
}
