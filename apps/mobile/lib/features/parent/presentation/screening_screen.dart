import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';
import 'ei_screening_wizard.dart';
import 'screening_results_screen.dart';

class ScreeningScreen extends ConsumerStatefulWidget {
  const ScreeningScreen({
    super.key,
    this.childId,
    this.autoStart = false,
  });

  final String? childId;
  final bool autoStart;

  @override
  ConsumerState<ScreeningScreen> createState() => _ScreeningScreenState();
}

class _ScreeningScreenState extends ConsumerState<ScreeningScreen> {
  List<ScreeningTemplateModel> _templates = [];
  List<ScreeningHistoryModel> _history = [];
  List<ChildModel> _children = [];
  bool _loading = true;
  bool _autoStartHandled = false;
  bool _wizardActive = false;

  ScreeningTemplateModel? _activeTemplate;
  ChildModel? _activeChild;
  Map<String, dynamic> _draftAnswers = {};
  String? _draftId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ChildModel? get _selectedChild {
    if (_children.isEmpty) return null;
    if (widget.childId != null) {
      for (final child in _children) {
        if (child.id == widget.childId) return child;
      }
    }
    return _children.first;
  }

  ScreeningTemplateModel? get _eiTemplate {
    for (final t in _templates) {
      if (t.therapyType == 'EARLY_INTERVENTION' ||
          t.name.toLowerCase().contains('early intervention')) {
        return t;
      }
    }
    return _templates.isNotEmpty ? _templates.first : null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(parentBookingRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.fetchScreeningTemplates(),
        repo.fetchChildren(),
        repo.fetchScreeningHistory(),
      ]);
      if (mounted) {
        setState(() {
          _templates = results[0] as List<ScreeningTemplateModel>;
          _children = results[1] as List<ChildModel>;
          _history = results[2] as List<ScreeningHistoryModel>;
          _loading = false;
        });
        _maybeAutoStartQuestionnaire();
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

  void _maybeAutoStartQuestionnaire() {
    if (!widget.autoStart || _autoStartHandled) return;
    final template = _eiTemplate;
    final child = _selectedChild;
    if (template == null || child == null) return;
    _autoStartHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startTemplate(template, child: child);
    });
  }

  Future<void> _startTemplate(
    ScreeningTemplateModel template, {
    ChildModel? child,
  }) async {
    final targetChild = child ?? _selectedChild;
    if (targetChild == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a child before completing screening')),
      );
      return;
    }

    Map<String, dynamic> answers = {};
    String? draftId;
    try {
      final draft = await ref.read(parentBookingRepositoryProvider).fetchScreeningDraft(
            templateId: template.id,
            childId: targetChild.id,
          );
      if (draft != null) {
        answers = draft.responses;
        draftId = draft.id;
      }
    } catch (_) {}

    setState(() {
      _activeTemplate = template;
      _activeChild = targetChild;
      _draftAnswers = answers;
      _draftId = draftId;
      _wizardActive = true;
    });
  }

  void _onSubmitted(ScreeningResultModel result) {
    setState(() => _wizardActive = false);
    final child = _activeChild;
    if (child == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScreeningResultsScreen(child: child, result: result),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd();
    final selectedChild = _selectedChild;

    if (_wizardActive && _activeTemplate != null && _activeChild != null) {
      return AppScaffold(
        title: 'Early Intervention Screening',
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _wizardActive = false),
          ),
        ],
        body: EiScreeningWizard(
          template: _activeTemplate!,
          child: _activeChild!,
          initialAnswers: _draftAnswers,
          draftId: _draftId,
          onSubmitted: _onSubmitted,
        ),
      );
    }

    return AppScaffold(
      title: 'Screening',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Early Intervention Intake',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedChild == null
                        ? 'Add a child profile to complete the screening.'
                        : 'Screening for ${selectedChild.displayName}',
                  ),
                  if (selectedChild == null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.parentChildren),
                      icon: const Icon(Icons.child_care),
                      label: const Text('Add child profile'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_history.isNotEmpty) ...[
                    Text(
                      'Past screenings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._history.map(
                      (h) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(h.templateName),
                          subtitle: Text(
                            '${h.childName} · ${dateFmt.format(h.completedAt)}'
                            '${h.riskLevel != null ? ' · ${h.riskLevel}' : ''}',
                          ),
                          trailing: h.score != null
                              ? Text(h.score!.toStringAsFixed(2))
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Available forms',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_templates.isEmpty)
                    const Text('No screening templates configured.')
                  else
                    ..._templates.map(
                      (t) {
                        final isEi = t.therapyType == 'EARLY_INTERVENTION';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(t.name),
                            subtitle: Text(
                              isEi
                                  ? 'Sections A–G · comprehensive developmental screening'
                                  : '${t.therapyType} intake',
                            ),
                            trailing: FilledButton(
                              onPressed: selectedChild == null
                                  ? null
                                  : () => _startTemplate(
                                        t,
                                        child: selectedChild,
                                      ),
                              child: const Text('Start'),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
