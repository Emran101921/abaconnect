import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/parent_booking_repository.dart';

class EiSection {
  EiSection({
    required this.id,
    required this.title,
    this.description,
    required this.questions,
  });

  final String id;
  final String title;
  final String? description;
  final List<EiQuestion> questions;
}

class EiQuestion {
  EiQuestion({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
  });

  final String id;
  final String text;
  final String type;
  final List<String> options;
}

List<EiSection> parseEiSections(String? questionsJson) {
  if (questionsJson == null) return [];
  try {
    final decoded = jsonDecode(questionsJson);
    if (decoded is! Map<String, dynamic>) return [];
    final sections = decoded['sections'] as List<dynamic>? ?? [];
    return sections.map((s) {
      final map = s as Map<String, dynamic>;
      final questions = (map['questions'] as List<dynamic>? ?? [])
          .map((q) {
            final qm = q as Map<String, dynamic>;
            return EiQuestion(
              id: qm['id'] as String? ?? '',
              text: qm['text'] as String? ?? '',
              type: qm['type'] as String? ?? 'yes_no',
              options: (qm['options'] as List<dynamic>? ?? [])
                  .map((o) => o.toString())
                  .toList(),
            );
          })
          .toList();
      return EiSection(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        questions: questions,
      );
    }).toList();
  } catch (_) {
    return [];
  }
}

class EiScreeningWizard extends ConsumerStatefulWidget {
  const EiScreeningWizard({
    super.key,
    required this.template,
    required this.child,
    this.initialAnswers = const {},
    this.draftId,
    this.onSubmitted,
  });

  final ScreeningTemplateModel template;
  final ChildModel child;
  final Map<String, dynamic> initialAnswers;
  final String? draftId;
  final void Function(ScreeningResultModel result)? onSubmitted;

  @override
  ConsumerState<EiScreeningWizard> createState() => _EiScreeningWizardState();
}

class _EiScreeningWizardState extends ConsumerState<EiScreeningWizard> {
  late final List<EiSection> _sections;
  late Map<String, dynamic> _answers;
  int _step = 0;
  bool _saving = false;
  bool _consent = false;
  String? _draftId;

  @override
  void initState() {
    super.initState();
    _sections = parseEiSections(widget.template.questionsJson);
    _answers = Map<String, dynamic>.from(widget.initialAnswers);
    _draftId = widget.draftId;
  }

  EiSection get _currentSection =>
      _sections.isEmpty ? EiSection(id: '', title: '', questions: []) : _sections[_step];

  double get _progress =>
      _sections.isEmpty ? 0 : (_step + 1) / _sections.length;

  bool get _isLastStep => _step >= _sections.length - 1;

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final draft = await ref.read(parentBookingRepositoryProvider).saveScreeningDraft(
            templateId: widget.template.id,
            childId: widget.child.id,
            responses: _answers,
            draftId: _draftId,
          );
      _draftId = draft.id;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save draft: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please consent to share results with providers'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref.read(parentBookingRepositoryProvider).submitScreening(
            templateId: widget.template.id,
            childId: widget.child.id,
            responses: _answers,
            draftId: _draftId,
            consentGranted: true,
          );
      widget.onSubmitted?.call(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildQuestion(EiQuestion q) {
    final value = _answers[q.id];

    switch (q.type) {
      case 'yes_no':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.text, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Yes')),
                ButtonSegment(value: false, label: Text('No')),
              ],
              selected: value == true
                  ? {true}
                  : value == false
                      ? {false}
                      : <bool>{},
              emptySelectionAllowed: true,
              onSelectionChanged: (sel) {
                setState(() {
                  if (sel.isEmpty) {
                    _answers.remove(q.id);
                  } else {
                    _answers[q.id] = sel.first;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      case 'text':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            decoration: InputDecoration(
              labelText: q.text,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            controller: TextEditingController(text: value?.toString() ?? '')
              ..selection = TextSelection.collapsed(
                offset: (value?.toString() ?? '').length,
              ),
            onChanged: (v) => setState(() => _answers[q.id] = v),
          ),
        );
      default:
        final options = q.options.isNotEmpty
            ? q.options
            : ['Never', 'Sometimes', 'Often', 'Always'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q.text),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((opt) {
                  final selected = value == opt;
                  return ChoiceChip(
                    label: Text(opt),
                    selected: selected,
                    onSelected: (_) => setState(() => _answers[q.id] = opt),
                  );
                }).toList(),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sections.isEmpty) {
      return const Center(child: Text('No screening sections configured.'));
    }

    final section = _currentSection;

    return Column(
      children: [
        LinearProgressIndicator(value: _progress),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(
                'Section ${section.id} of ${_sections.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              Text('${(_progress * 100).round()}%'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                section.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (section.description != null) ...[
                const SizedBox(height: 8),
                Text(section.description!),
              ],
              const SizedBox(height: 8),
              Text(
                'For ${widget.child.displayName}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 24),
              ...section.questions.map(_buildQuestion),
              if (_isLastStep) ...[
                const Divider(height: 32),
                CheckboxListTile(
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                  title: const Text(
                    'I consent to sharing screening results with care providers',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _step -= 1),
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saving ? null : _saveDraft,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save draft'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (_isLastStep) {
                            await _submit();
                          } else {
                            setState(() => _step += 1);
                          }
                        },
                  child: Text(_isLastStep ? 'Submit' : 'Next'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
