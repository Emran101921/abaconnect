import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/step_progress.dart';
import '../../../shared/widgets/app_choice_tile.dart';
import '../../../shared/widgets/app_dashboard_card.dart';
import '../../../shared/widgets/glossy_button.dart';
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

class _FlatQuestion {
  const _FlatQuestion({
    required this.sectionIndex,
    required this.section,
    required this.question,
  });

  final int sectionIndex;
  final EiSection section;
  final EiQuestion question;
}

List<EiSection> parseEiSections(String? questionsJson) {
  if (questionsJson == null) return [];
  try {
    final decoded = jsonDecode(questionsJson);
    if (decoded is! Map<String, dynamic>) return [];
    final sections = decoded['sections'] as List<dynamic>? ?? [];
    return sections.map((s) {
      final map = s as Map<String, dynamic>;
      final questions = (map['questions'] as List<dynamic>? ?? []).map((q) {
        final qm = q as Map<String, dynamic>;
        return EiQuestion(
          id: qm['id'] as String? ?? '',
          text: qm['text'] as String? ?? '',
          type: qm['type'] as String? ?? 'yes_no',
          options: (qm['options'] as List<dynamic>? ?? [])
              .map((o) => o.toString())
              .toList(),
        );
      }).toList();
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
  late final List<_FlatQuestion> _flatQuestions;
  late Map<String, dynamic> _answers;
  late final Map<String, TextEditingController> _textControllers;
  int _questionIndex = 0;
  bool _saving = false;
  bool _consent = false;
  String? _draftId;

  @override
  void initState() {
    super.initState();
    _sections = parseEiSections(widget.template.questionsJson);
    _flatQuestions = [
      for (var si = 0; si < _sections.length; si++)
        for (final q in _sections[si].questions)
          _FlatQuestion(sectionIndex: si, section: _sections[si], question: q),
    ];
    _answers = Map<String, dynamic>.from(widget.initialAnswers);
    _draftId = widget.draftId;
    _textControllers = {};
    for (final fq in _flatQuestions) {
      final q = fq.question;
      if (q.type == 'text' || q.type == 'text_list') {
        _textControllers[q.id] = TextEditingController(
          text: _answers[q.id]?.toString() ?? '',
        );
      }
    }
    _questionIndex = _firstUnansweredIndex();
  }

  int _firstUnansweredIndex() {
    for (var i = 0; i < _flatQuestions.length; i++) {
      if (!_isQuestionAnswered(_flatQuestions[i].question)) return i;
    }
    return 0;
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  _FlatQuestion get _current {
    if (_flatQuestions.isEmpty) {
      return _FlatQuestion(
        sectionIndex: 0,
        section: EiSection(id: '', title: '', questions: []),
        question: EiQuestion(id: '', text: '', type: 'yes_no'),
      );
    }
    return _flatQuestions[_questionIndex];
  }


  bool get _isLastQuestion => _questionIndex >= _flatQuestions.length - 1;

  bool _isQuestionAnswered(EiQuestion q) {
    final value = _answers[q.id];
    if (q.type == 'text' || q.type == 'text_list') {
      return value is String && value.trim().isNotEmpty;
    }
    return value != null;
  }

  bool get _allAnswered =>
      _flatQuestions.every((fq) => _isQuestionAnswered(fq.question));

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final draft = await ref
          .read(parentBookingRepositoryProvider)
          .saveScreeningDraft(
            templateId: widget.template.id,
            childId: widget.child.id,
            responses: _answers,
            draftId: _draftId,
          );
      _draftId = draft.id;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved — continue anytime from Screening'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save draft: $e')));
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
    if (!_allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(parentBookingRepositoryProvider)
          .submitScreening(
            templateId: widget.template.id,
            childId: widget.child.id,
            responses: _answers,
            draftId: _draftId,
            consentGranted: true,
          );
      widget.onSubmitted?.call(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
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
    if (!_isQuestionAnswered(_current.question)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer this question to continue'),
        ),
      );
      return;
    }
    if (_isLastQuestion) return;
    setState(() => _questionIndex += 1);
  }

  void _goBack() {
    if (_questionIndex > 0) setState(() => _questionIndex -= 1);
  }

  Widget _buildQuestion(EiQuestion q) {
    final value = _answers[q.id];

    switch (q.type) {
      case 'yes_no':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppChoiceTile(
              label: 'Yes',
              selected: value == true,
              onTap: () => setState(() => _answers[q.id] = true),
            ),
            AppChoiceTile(
              label: 'No',
              selected: value == false,
              onTap: () => setState(() => _answers[q.id] = false),
            ),
          ],
        );
      case 'text':
      case 'text_list':
        final controller = _textControllers.putIfAbsent(
          q.id,
          () => TextEditingController(text: value?.toString() ?? ''),
        );
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: q.text,
            hintText: q.type == 'text_list'
                ? 'Enter one item per line'
                : 'Your response',
            alignLabelWithHint: true,
          ),
          maxLines: q.type == 'text_list' ? 5 : 3,
          onChanged: (v) => setState(() => _answers[q.id] = v),
        );
      default:
        final options = q.options.isNotEmpty
            ? q.options
            : ['Never', 'Sometimes', 'Often', 'Always'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: options.map((opt) {
            return AppChoiceTile(
              label: opt,
              selected: value == opt,
              onTap: () => setState(() => _answers[q.id] = opt),
            );
          }).toList(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sections.isEmpty || _flatQuestions.isEmpty) {
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
              GlossyButton(
                title: 'Go back',
                variant: GlossyButtonVariant.neutral,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      );
    }

    final current = _current;
    final section = current.section;
    final question = current.question;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: StepProgress(
            currentStep: _questionIndex + 1,
            totalSteps: _flatQuestions.length,
            title: 'Section ${section.id}: ${section.title}',
            labels: _sections.map((s) => s.id).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_sections.length, (i) {
                final s = _sections[i];
                final isActive = i == current.sectionIndex;
                final isDone =
                    i < current.sectionIndex ||
                    (i == current.sectionIndex &&
                        _flatQuestions
                            .where((fq) => fq.sectionIndex == i)
                            .every((fq) => _isQuestionAnswered(fq.question)));
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      _sectionIcon(s.id),
                      size: 18,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    label: Text('${s.id} · ${s.title.split(' ').first}'),
                    selected: isActive,
                    onSelected: isDone
                        ? (_) {
                            final idx = _flatQuestions.indexWhere(
                              (fq) => fq.sectionIndex == i,
                            );
                            if (idx >= 0) setState(() => _questionIndex = idx);
                          }
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
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (_questionIndex == 0)
                AppDashboardCard(
                  color: colorScheme.surfaceContainerHighest,
                  elevated: false,
                  child: Text(
                    eiScreeningDisclaimer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (_questionIndex == 0) const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      _sectionIcon(section.id),
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Section ${section.id}: ${section.title}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'For ${widget.child.displayName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                question.type == 'text' || question.type == 'text_list'
                    ? 'Share your thoughts'
                    : question.text,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (question.type == 'text' || question.type == 'text_list') ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  question.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _buildQuestion(question),
              if (_isLastQuestion) ...[
                const SizedBox(height: AppSpacing.lg),
                AppDashboardCard(
                  elevated: false,
                  child: CheckboxListTile(
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                    title: const Text(
                      'I consent to sharing screening results with care providers',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                if (_questionIndex > 0)
                  GlossyOutlinedButton(
                    onPressed: _saving ? null : _goBack,
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
                      : const Text('Save & continue later'),
                ),
                const Spacer(),
                GlossyButton(
                  title: _isLastQuestion ? 'Submit screening' : 'Next',
                  size: GlossyButtonSize.medium,
                  fullWidth: false,
                  variant: GlossyButtonVariant.bluePurple,
                  loading: _saving,
                  onPressed: () async {
                    if (_isLastQuestion) {
                      await _submit();
                    } else {
                      _goNext();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
