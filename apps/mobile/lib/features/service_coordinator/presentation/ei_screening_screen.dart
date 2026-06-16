import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
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
  final _notesController = TextEditingController();
  final _progressController = TextEditingController();
  final _concernsController = TextEditingController();
  bool _followUpRequired = false;
  DateTime? _followUpDate;
  int _completion = 0;
  bool _saving = false;

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
      if (widget.mode == EiScreeningMode.initial &&
          detail.initialScreening != null) {
        final raw = detail.initialScreening!['answersJson'];
        if (raw is String) {
          _answers.addAll(jsonDecode(raw) as Map<String, dynamic>);
        }
        _notesController.text = detail.initialScreening!['notes'] as String? ?? '';
      }
    } catch (_) {}
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
              submit ? 'Screening submitted ($_completion% complete)' : 'Draft saved',
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
          if (_completion > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(value: _completion / 100),
            ),
          const SizedBox(height: 16),
          if (isInitial) ...[
            _sectionTitle('Child information'),
            _textField('childFirstName', 'Child first name'),
            _textField('childDateOfBirth', 'Date of birth'),
            _sectionTitle('Parent/guardian'),
            _textField('guardianName', 'Guardian name'),
            _textField('guardianPhone', 'Guardian phone'),
            _sectionTitle('Referral & concerns'),
            _textField('referralSource', 'Referral source'),
            _textField('parentConcerns', 'Parent concerns', maxLines: 3),
            _sectionTitle('Medical/birth history'),
            _textField('medicalHistory', 'Medical/birth history', maxLines: 3),
            _yesNo('communicationConcerns', 'Communication/speech concerns?'),
            _yesNo('motorConcerns', 'Motor skills concerns?'),
            _yesNo('socialEmotionalConcerns', 'Social-emotional concerns?'),
            _yesNo('dailyLivingConcerns', 'Feeding/sleeping/daily living?'),
            _sectionTitle('Consent'),
            SwitchListTile(
              title: const Text('Consent and privacy acknowledgment'),
              value: _answers['consentAcknowledged'] == true,
              onChanged: (v) => setState(() => _answers['consentAcknowledged'] = v),
            ),
          ] else ...[
            _sectionTitle('Current services'),
            _yesNo('servicesActive', 'Are services active?'),
            _yesNo('missedSessions', 'Any missed sessions?'),
            _yesNo('providerIssues', 'Any provider issues?'),
            _yesNo('childRegression', 'Any child regression?'),
            _yesNo('familyCrisis', 'Family crisis or urgent concern?'),
            TextField(
              controller: _progressController,
              decoration: const InputDecoration(labelText: 'Child progress update'),
              maxLines: 3,
              onChanged: (v) => _answers['childProgress'] = v,
            ),
            TextField(
              controller: _concernsController,
              decoration: const InputDecoration(labelText: 'New concerns'),
              maxLines: 2,
            ),
            _textField('nextFollowUpDate', 'Next follow-up date'),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Follow-up required'),
            value: _followUpRequired,
            onChanged: (v) => setState(() => _followUpRequired = v),
          ),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Coordinator notes'),
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

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _textField(String key, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        decoration: InputDecoration(labelText: label),
        maxLines: maxLines,
        onChanged: (v) => _answers[key] = v,
        controller: TextEditingController(text: _answers[key]?.toString() ?? ''),
      ),
    );
  }

  Widget _yesNo(String key, String label) {
    final val = _answers[key] == true || _answers[key] == 'yes';
    return SwitchListTile(
      title: Text(label),
      value: val,
      onChanged: (v) => setState(() => _answers[key] = v),
    );
  }
}
