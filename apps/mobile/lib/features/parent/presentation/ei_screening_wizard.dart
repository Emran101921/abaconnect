import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/parent_booking_repository.dart';

const eiScreeningDisclaimer =
    'This screening tool is for informational purposes only and does not '
    'replace evaluation by a licensed professional. It is not a medical diagnosis.';

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
  late final Map<String, TextEditingController> _textControllers;
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
    _textControllers = {};
    for (final section in _sections) {
      for (final q in section.questions) {
        if (q.type == 'text' || q.type == 'text_list') {
          _textControllers[q.id] = TextEditingController(
            text: _answers[q.id]?.toString() ?? '',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  EiSection get _currentSection =>
      _sections.isEmpty
          ? EiSection(id: '', title: '', questions: [])
          : _sections[_step];

  double get _progress =>
      _sections.isEmpty ? 0 : (_step + 1) / _sections.length;

  bool get _isLastStep => _step >= _sections.length - 1;

  bool _isQuestionAnswered(EiQuestion q) {
    final value = _answers[q.id];
    if (q.type == 'text' || q.type == 'text_list') {
      return value is String && value.trim().isNotEmpty;
    }
    return value != null;
  }

  bool _isSectionComplete(EiSection section) {
    return section.questions.every(_isQuestionAnswered);
  }

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
          const SnackBar(content: Text('Draft saved — you can edit and submit later')),
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
    if (!_isSectionComplete(_currentSection)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions in this section')),
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

  IconData _sectionIcon(String id) {
    switch (id.toUpperCase()) {
      case 'A':
        return Icons.medical_services_outlined;
      case 'B':
        return Icons.record_voice_over_outlined;
      case 'C':
        return Icons.groups_outlined;
      case 'D':
        return Icons.back_hand_outlined;
      case 'E':
        return Icons.directions_run_outlined;
      case 'F':
        return Icons.restaurant_outlined;
      case 'G':
        return Icons.chat_bubble_outline;
      default:
        return Icons.assignment_outlined;
    }
  }

  void _goNext() {
    if (!_isSectionComplete(_currentSection)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions before continuing')),
      );
      return;
    }
    setState(() => _step += 1);
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
      case 'text_list':
        final controller = _textControllers.putIfAbsent(
          q.id,
          () => TextEditingController(text: value?.toString() ?? ''),
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: q.text,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: q.type == 'text_list' ? 4 : 3,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Early Intervention screening is not configured yet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    final section = _currentSection;

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            backgroundColor: colorScheme.outlineVariant,
            color: colorScheme.secondary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(
                'Section ${section.id} · ${_step + 1} of ${_sections.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              Text('${(_progress * 100).round()}%'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_sections.length, (i) {
                final s = _sections[i];
                final isActive = i == _step;
                final isDone = i < _step;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      _sectionIcon(s.id),
                      size: 18,
                      color: isActive
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    label: Text(s.id),
                    selected: isActive,
                    onSelected: isDone
                        ? (_) => setState(() => _step = i)
                        : null,
                    showCheckmark: false,
                  ),
                );
              }),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_step == 0)
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      eiScreeningDisclaimer,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                ),
              if (_step == 0) const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Icon(
                      _sectionIcon(section.id),
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              if (section.description != null) ...[
                const SizedBox(height: 8),
                Text(section.description!),
              ],
              const SizedBox(height: 8),
              Text(
                'Child: ${widget.child.displayName}',
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
                const SizedBox(height: 8),
                Text(
                  eiScreeningDisclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
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
                            _goNext();
                          }
                        },
                  child: Text(_isLastStep ? 'Submit screening' : 'Next section'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
