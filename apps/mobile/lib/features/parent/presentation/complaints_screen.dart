import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/glossy_button.dart';

class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _category = 'SERVICE';

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty || _description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in subject and description')),
      );
      return;
    }
    try {
      await ref
          .read(platformRepositoryProvider)
          .fileComplaint(
            category: _category,
            subject: _subject.text.trim(),
            description: _description.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Complaint submitted')));
        _subject.clear();
        _description.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'File a complaint',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Report a concern about care quality, billing, or safety. '
            'Our team will review open complaints.',
          ),
          const SizedBox(height: 16),
          AppSelectField<String>(
            label: 'Category',
            value: _category,
            options: const [
              AppSelectOption(value: 'SERVICE', label: 'Service'),
              AppSelectOption(value: 'BILLING', label: 'Billing'),
              AppSelectOption(value: 'SAFETY', label: 'Safety'),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          GlossyButton(
            title: 'Submit complaint',
            variant: GlossyButtonVariant.orangeRed,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
