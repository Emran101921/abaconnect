import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../service_coordinator/data/service_coordinator_repository.dart';
import 'ei_screening_form_config.dart';
import 'sc_providers.dart';

enum EiScreeningMode { initial, ongoing }

class EiScreeningScreen extends ConsumerStatefulWidget {
  const EiScreeningScreen({
    super.key,
    required this.childId,
    required this.mode,
  });

  final String childId;
  final EiScreeningMode mode;

  @override
  ConsumerState<EiScreeningScreen> createState() => _EiScreeningScreenState();
}

class _EiScreeningScreenState extends ConsumerState<EiScreeningScreen> {
  final _answers = <String, dynamic>{};
  final _controllers = <String, TextEditingController>{};
  final _notesController = TextEditingController();
  final _progressController = TextEditingController();
  final _concernsController = TextEditingController();
  bool _followUpRequired = false;
  DateTime? _followUpDate;
  int _completion = 0;
  bool _saving = false;
  ScCaseDetailModel? _caseDetail;

  List<EiSectionConfig> get _sections =>
      widget.mode == EiScreeningMode.initial
          ? initialEiSections()
          : ongoingEiSections();

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final detail = await ref
          .read(serviceCoordinatorRepositoryProvider)
          .fetchCaseDetail(widget.childId);
      _caseDetail = detail;
      _answers.addAll(detail.screeningPrefill);
      if (widget.mode == EiScreeningMode.initial &&
          detail.initialScreening != null) {
        _mergeAnswersJson(detail.initialScreening!['answersJson']);
        _notesController.text =
            detail.initialScreening!['notes'] as String? ?? '';
      }
    } catch (_) {}
    _syncControllers();
    _updateCompletion();
  }

  void _mergeAnswersJson(dynamic raw) {
    if (raw is String) {
      _answers.addAll(jsonDecode(raw) as Map<String, dynamic>);
    } else if (raw is Map) {
      _answers.addAll(raw.cast<String, dynamic>());
    }
  }

  void _syncControllers() {
    for (final section in _sections) {
      for (final field in section.fields) {
        if (field.type == EiFieldType.text ||
            field.type == EiFieldType.date ||
            field.type == EiFieldType.multiChoice) {
          final value = _answers[field.key]?.toString() ?? '';
          _controllers[field.key] ??= TextEditingController(text: value);
          _controllers[field.key]!.text = value;
        }
      }
    }
    if (widget.mode == EiScreeningMode.ongoing) {
      _progressController.text = _answers['childProgress']?.toString() ?? '';
      _concernsController.text = _answers['newConcernsDetail']?.toString() ?? '';
    }
  }

  void _updateCompletion() {
    setState(() {
      _completion = completionPercentForSections(_answers, _sections);
    });
  }

  Future<void> _save({bool submit = false}) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(serviceCoordinatorRepositoryProvider);
      if (widget.mode == EiScreeningMode.initial) {
        _completion = await repo.upsertInitialScreening(
          childId: widget.childId,
          answers: _answers,
          notes: _notesController.text,
          followUpRequired: _followUpRequired,
          followUpDueDate: _followUpDate,
          submit: submit,
        );
      } else {
        _answers['childProgress'] = _progressController.text;
        _answers['newConcerns'] = _concernsController.text;
        _completion = await repo.upsertOngoingScreening(
          childId: widget.childId,
          answers: _answers,
          notes: _notesController.text,
          progressSummary: _progressController.text,
          newConcerns: _concernsController.text,
          followUpRequired: _followUpRequired,
          followUpDueDate: _followUpDate,
          submit: submit,
        );
      }
      ref.invalidate(scCaseDetailProvider(widget.childId));
      ref.invalidate(scDashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submit
                  ? 'Screening submitted ($_completion% complete)'
                  : 'Draft saved ($_completion% complete)',
            ),
          ),
        );
        if (submit) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _progressController.dispose();
    _concernsController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInitial = widget.mode == EiScreeningMode.initial;
    return AppScaffold(
      title: isInitial ? 'Initial EI screening' : 'Ongoing follow-up',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'This screening does not diagnose the child. It helps the Service Coordinator understand family concerns and coordinate appropriate next steps.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_caseDetail != null) _buildChildReferenceCard(_caseDetail!),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(value: _completion / 100),
              ),
              const SizedBox(width: 12),
              Text('$_completion%'),
            ],
          ),
          const SizedBox(height: 16),
          ..._sections.map(_buildSection),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Follow-up required'),
            value: _followUpRequired,
            onChanged: (v) => setState(() {
              _followUpRequired = v;
              _answers['followUpRequired'] = v;
              _updateCompletion();
            }),
          ),
          ListTile(
            title: const Text('Follow-up due date'),
            subtitle: Text(
              _followUpDate != null
                  ? _followUpDate!.toLocal().toString().split(' ').first
                  : 'Not set',
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _followUpDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _followUpDate = picked;
                  _answers['followUpDueDate'] = picked.toIso8601String();
                });
              }
            },
          ),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Service coordinator notes'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          GlossyButton(
            title: _saving ? 'Saving…' : 'Save draft',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : () => _save(),
          ),
          const SizedBox(height: 8),
          GlossyButton(
            title: 'Submit completed screening',
            icon: Icons.check_circle_outline,
            variant: GlossyButtonVariant.secondary,
            onPressed: _saving ? null : () => _save(submit: true),
          ),
        ],
      ),
    );
  }

  Widget _buildChildReferenceCard(ScCaseDetailModel detail) {
    final dob = detail.dateOfBirth.toLocal().toString().split(' ').first;
    final phone = detail.guardianPhone ?? detail.parentPhone ?? '—';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Child information (from case record)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text('${detail.childName} · DOB $dob'),
            Text('Guardian: ${detail.parentName}'),
            Text('Phone: $phone'),
            if (detail.parentEmail != null) Text('Email: ${detail.parentEmail}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(EiSectionConfig section) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(section.title, style: Theme.of(context).textTheme.titleSmall),
        children: section.fields.map(_buildField).toList(),
      ),
    );
  }

  Widget _buildField(EiFieldConfig field) {
    final readOnly = field.readOnly;
    switch (field.type) {
      case EiFieldType.yesNo:
        final val = _answers[field.key] == true;
        return SwitchListTile(
          title: Text(field.label),
          subtitle: field.required ? const Text('Required') : null,
          value: val,
          onChanged: readOnly
              ? null
              : (v) {
                  setState(() {
                    _answers[field.key] = v;
                    _updateCompletion();
                  });
                },
        );
      case EiFieldType.priority:
        final current = _answers[field.key]?.toString() ?? 'LOW';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: AppSelectField<String>(
            label: field.label,
            value: current,
            enabled: !readOnly,
            options: const [
              AppSelectOption(value: 'LOW', label: 'Low'),
              AppSelectOption(value: 'MEDIUM', label: 'Medium'),
              AppSelectOption(value: 'HIGH', label: 'High'),
            ],
            onChanged: readOnly
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      _answers[field.key] = v;
                      _updateCompletion();
                    });
                  },
          ),
        );
      case EiFieldType.multiChoice:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: AppSelectField<String>(
            label: field.label,
            value: _answers[field.key]?.toString(),
            enabled: !readOnly,
            hint: 'Select…',
            options: field.options
                .map((o) => AppSelectOption(value: o, label: o))
                .toList(),
            onChanged: readOnly
                ? null
                : (v) {
                    if (v == null) return;
                    _controllers[field.key]?.text = v;
                    setState(() {
                      _answers[field.key] = v;
                      _updateCompletion();
                    });
                  },
          ),
        );
      case EiFieldType.date:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _controllers.putIfAbsent(
              field.key,
              () => TextEditingController(text: _answers[field.key]?.toString() ?? ''),
            ),
            readOnly: readOnly,
            decoration: InputDecoration(
              labelText: field.label,
              hintText: 'YYYY-MM-DD',
            ),
            onChanged: readOnly
                ? null
                : (v) {
                    _answers[field.key] = v;
                    _updateCompletion();
                  },
          ),
        );
      case EiFieldType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _controllers.putIfAbsent(
              field.key,
              () => TextEditingController(text: _answers[field.key]?.toString() ?? ''),
            ),
            readOnly: readOnly,
            decoration: InputDecoration(labelText: field.label),
            maxLines: field.maxLines,
            onChanged: readOnly
                ? null
                : (v) {
                    _answers[field.key] = v;
                    _updateCompletion();
                  },
          ),
        );
    }
  }
}
