import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/parent_booking_repository.dart';
import 'ei_screening_wizard.dart';
import 'screening_results_screen.dart';

class ScreeningScreen extends ConsumerStatefulWidget {
  const ScreeningScreen({super.key, this.childId, this.autoStart = false});

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
  bool _hasDraft = false;

  ScreeningTemplateModel? _activeTemplate;
  ChildModel? _activeChild;
  Map<String, dynamic> _draftAnswers = {};
  String? _draftId;

  ChildModel? get _selectedChild {
    if (_children.isEmpty) return null;
    if (widget.childId != null) {
      for (final child in _children) {
        if (child.id == widget.childId) return child;
      }
      return null;
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
    return null;
  }

  List<ScreeningTemplateModel> get _legacyTemplates =>
      _templates.where((t) => t.therapyType != 'EARLY_INTERVENTION').toList();

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
        await _checkDraft();
        _maybeAutoStartQuestionnaire();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load screening: $e')));
      }
    }
  }

  Future<void> _checkDraft() async {
    final template = _eiTemplate;
    final child = _selectedChild;
    if (template == null || child == null) {
      if (mounted) setState(() => _hasDraft = false);
      return;
    }
    try {
      final draft = await ref
          .read(parentBookingRepositoryProvider)
          .fetchScreeningDraft(templateId: template.id, childId: child.id);
      if (mounted) setState(() => _hasDraft = draft != null);
    } catch (_) {
      if (mounted) setState(() => _hasDraft = false);
    }
  }

  void _maybeAutoStartQuestionnaire() {
    if (!widget.autoStart || _autoStartHandled) return;
    _autoStartHandled = true;

    final child = _selectedChild;
    if (child == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a child profile before screening')),
        );
        context.push(AppRoutes.parentChildren);
      });
      return;
    }

    final template = _eiTemplate;
    if (template == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Early Intervention screening is loading — tap Start below when ready',
            ),
          ),
        );
      });
      return;
    }

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
        const SnackBar(
          content: Text('Add a child before completing screening'),
        ),
      );
      context.push(AppRoutes.parentChildren);
      return;
    }

    Map<String, dynamic> answers = {};
    String? draftId;
    try {
      final draft = await ref
          .read(parentBookingRepositoryProvider)
          .fetchScreeningDraft(
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

  Future<void> _viewHistoryResult(ScreeningHistoryModel entry) async {
    final child =
        _selectedChild ??
        _children.cast<ChildModel?>().firstWhere(
          (c) => c?.displayName == entry.childName,
          orElse: () => _children.isNotEmpty ? _children.first : null,
        );
    if (child == null) return;

    try {
      final result = await ref
          .read(parentBookingRepositoryProvider)
          .fetchScreeningResult(entry.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScreeningResultsScreen(child: child, result: result),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load results: $e')));
      }
    }
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
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd();
    final selectedChild = _selectedChild;
    final eiTemplate = _eiTemplate;

    if (_wizardActive && _activeTemplate != null && _activeChild != null) {
      return AppScaffold(
        title: 'Early Intervention Screening',
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Save and exit',
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
      title: 'Early Intervention Screening',
      bottomNavigationBar: ParentBottomNav(
        current: ParentNavTab.screening,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.childId != null && selectedChild == null
          ? const Center(
              child: Text(
                'Child not found. Return to your children list and try again.',
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Parent screening questionnaire',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedChild == null
                        ? 'Complete your child\'s profile first, then continue to sections A–G.'
                        : 'Screening for ${selectedChild.displayName}',
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            eiScreeningDisclaimer,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 16),
                          if (selectedChild == null)
                            GlossyButton(
                              title: 'Add child profile',
                              icon: Icons.child_care,
                              variant: GlossyButtonVariant.tealBlue,
                              onPressed: () =>
                                  context.push(AppRoutes.parentChildren),
                            )
                          else if (eiTemplate == null)
                            const Text(
                              'Early Intervention template is not available. Pull to refresh.',
                            )
                          else
                            GlossyButton(
                              title: _hasDraft
                                  ? 'Resume screening'
                                  : 'Start screening (sections A–G)',
                              icon: Icons.play_arrow,
                              variant: GlossyButtonVariant.bluePurple,
                              onPressed: () => _startTemplate(
                                eiTemplate,
                                child: selectedChild,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_history.isNotEmpty && selectedChild != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.storefront_outlined),
                        title: const Text(
                          'Post anonymous marketplace request',
                        ),
                        subtitle: const Text(
                          'Share service needs from your screening with verified providers in your ZIP area',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          final latest = [..._history]
                            ..sort(
                              (a, b) =>
                                  b.completedAt.compareTo(a.completedAt),
                            );
                          context.push(
                            '${AppRoutes.parentMarketplaceOptIn}'
                            '?childId=${selectedChild.id}'
                            '&screeningResponseId=${latest.first.id}'
                            '${selectedChild.primaryLanguage != null ? '&languagePreference=${Uri.encodeComponent(selectedChild.primaryLanguage!)}' : ''}',
                          );
                        },
                      ),
                    ),
                  ],
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Completed screenings',
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
                          trailing: h.riskLevel != null
                              ? Chip(label: Text(h.riskLevel!))
                              : null,
                          onTap: () => _viewHistoryResult(h),
                        ),
                      ),
                    ),
                  ],
                  if (_legacyTemplates.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Other therapy intake forms',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._legacyTemplates.map(
                      (t) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              title: Text(t.name),
                              subtitle: Text('${t.therapyType} intake'),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: GlossyButton(
                                  title: 'Start',
                                  size: GlossyButtonSize.small,
                                  fullWidth: false,
                                  variant: GlossyButtonVariant.neutral,
                                  onPressed: selectedChild == null
                                      ? null
                                      : () => _startTemplate(
                                            t,
                                            child: selectedChild,
                                          ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
