import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../models/eip_session_note_model.dart';
import '../therapist_providers.dart';
import 'session_notes_screen.dart';
import 'therapist_weekly_progress_section.dart';
import '../../../shared/widgets/app_scaffold.dart';

final sessionNoteFormContextProvider =
    FutureProvider.family<EipSessionNoteModel, String>((ref, sessionId) async {
  final ctx = await ref
      .read(therapistRepositoryProvider)
      .fetchSessionNoteFormContext(sessionId);
  return EipSessionNoteModel.fromContext(ctx);
});

class EipSessionNoteScreen extends ConsumerStatefulWidget {
  const EipSessionNoteScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<EipSessionNoteScreen> createState() =>
      _EipSessionNoteScreenState();
}

const _ifspServiceLocations = [
  'Home',
  'Home/Community (natural environment)',
  'Community — child care program',
  'Community — family child care home',
  'Community — other natural setting',
  'Facility / center-based',
  'School',
  'Telehealth (with parent consent)',
  'Other',
];

/// NYC EIP Individual Session Note — intensity per IFSP authorization.
const _intensityOptions = [
  'Home/Community (as authorized in IFSP)',
  'Individual-Facility (as authorized in IFSP)',
  'Group session (use Group Session Note)',
  'Parent-child group',
  'Family-support group',
  'Collateral / parent-only (per IFSP)',
  'Other',
];

class _EipSessionNoteScreenState extends ConsumerState<EipSessionNoteScreen> {
  EipSessionNoteModel? _form;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(
      sessionNoteFormContextProvider(widget.sessionId),
    );

    return AppScaffold(
      title: 'Session Note',
      body: contextAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (initial) {
          _form ??= initial;
          final form = _form!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _headerCard(context),
              const SizedBox(height: 12),
              _section(
                title: 'Demographics / Authorization',
                children: [
                  _field('Child\'s name', form.childName, (v) {
                    setState(() => _form = form.copyWith(childName: v));
                  }),
                  Row(
                    children: [
                      Expanded(
                        child: _field('DOB', form.childDob ?? '', (v) {
                          setState(() => _form = form.copyWith(childDob: v));
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _dropdown(
                          label: 'Sex',
                          value: form.childSex ?? '',
                          items: const ['', 'Male', 'Female'],
                          onChanged: (v) {
                            setState(
                              () => _form = form.copyWith(
                                childSex: v?.isEmpty == true ? null : v,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  _field('EI #', form.eiNumber ?? '', (v) {
                    setState(() => _form = form.copyWith(eiNumber: v));
                  }),
                  _field('Interventionist name', form.interventionistName, (v) {
                    setState(
                      () => _form = form.copyWith(interventionistName: v),
                    );
                  }),
                  _field('Credentials', form.credentials ?? '', (v) {
                    setState(() => _form = form.copyWith(credentials: v));
                  }),
                  _field('National Provider ID (NPI)', form.npi ?? '', (v) {
                    setState(() => _form = form.copyWith(npi: v));
                  }),
                  _field('Service type', form.serviceType ?? '', (v) {
                    setState(() => _form = form.copyWith(serviceType: v));
                  }),
                ],
              ),
              _section(
                title: 'Session details',
                children: [
                  _field('Session date', form.sessionDate ?? '', (v) {
                    setState(() => _form = form.copyWith(sessionDate: v));
                  }),
                  _scrollableDropdown(
                    label: 'IFSP service location',
                    value: _ifspLocationValue(form.ifspServiceLocation),
                    items: _ifspLocationItems(form.ifspServiceLocation),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _form = form.copyWith(
                          ifspServiceLocation: v,
                        );
                      });
                    },
                  ),
                  if (form.ifspServiceLocation == 'Other')
                    _field(
                      'Specify IFSP service location',
                      '',
                      (v) {
                        setState(
                          () => _form = form.copyWith(
                            ifspServiceLocation: v.trim().isEmpty ? 'Other' : v,
                          ),
                        );
                      },
                    ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _field('Time from', form.timeFrom ?? '', (v) {
                          setState(() => _form = form.copyWith(timeFrom: v));
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _dropdown(
                          label: 'AM/PM',
                          value: form.timeFromAmPm,
                          items: const ['AM', 'PM'],
                          onChanged: (v) {
                            if (v != null) {
                              setState(
                                () => _form = form.copyWith(timeFromAmPm: v),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _field('Time to', form.timeTo ?? '', (v) {
                          setState(() => _form = form.copyWith(timeTo: v));
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _dropdown(
                          label: 'AM/PM',
                          value: form.timeToAmPm,
                          items: const ['AM', 'PM'],
                          onChanged: (v) {
                            if (v != null) {
                              setState(
                                () => _form = form.copyWith(timeToAmPm: v),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  _scrollableDropdown(
                    label: 'Intensity',
                    value: _intensityValue(form.intensity),
                    items: _intensityItems(form.intensity),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _form = form.copyWith(intensity: v);
                      });
                    },
                  ),
                  if (form.intensity == 'Other')
                    _field(
                      'Specify intensity',
                      '',
                      (v) {
                        setState(
                          () => _form = form.copyWith(
                            intensity: v.trim().isEmpty ? 'Other' : v,
                          ),
                        );
                      },
                    ),
                  _dropdown(
                    label: 'Session delivered',
                    value: form.sessionDelivered,
                    items: const ['In-person', 'Telehealth'],
                    onChanged: (v) {
                      if (v != null) {
                        setState(
                          () => _form = form.copyWith(sessionDelivered: v),
                        );
                      }
                    },
                  ),
                  _field('Date note written', form.dateNoteWritten ?? '', (v) {
                    setState(() => _form = form.copyWith(dateNoteWritten: v));
                  }),
                  _field('ICD-10 code', form.icd10Code ?? '', (v) {
                    setState(() => _form = form.copyWith(icd10Code: v));
                  }),
                  _field('HCPCS code (if applicable)', form.hcpcsCode ?? '', (v) {
                    setState(() => _form = form.copyWith(hcpcsCode: v));
                  }),
                  _field('1st CPT code', form.cptCode1 ?? '', (v) {
                    setState(() => _form = form.copyWith(cptCode1: v));
                  }),
                  _field('2nd CPT code', form.cptCode2 ?? '', (v) {
                    setState(() => _form = form.copyWith(cptCode2: v));
                  }),
                ],
              ),
              _section(
                title: 'Cancellation / make-up (if applicable)',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Session cancelled'),
                    value: form.sessionCancelled,
                    onChanged: (v) {
                      setState(() => _form = form.copyWith(sessionCancelled: v));
                    },
                  ),
                  if (form.sessionCancelled) ...[
                    _multiline(
                      'Reason (document in #1 below)',
                      form.cancellationReason ?? '',
                      (v) {
                        setState(
                          () => _form = form.copyWith(cancellationReason: v),
                        );
                      },
                    ),
                    _field('Must be made up by', form.makeupByDate ?? '', (v) {
                      setState(() => _form = form.copyWith(makeupByDate: v));
                    }),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('This is a make-up session'),
                    value: form.isMakeup,
                    onChanged: (v) {
                      setState(() => _form = form.copyWith(isMakeup: v));
                    },
                  ),
                  if (form.isMakeup)
                    _field('Make-up for missed session on', form.makeupForDate ?? '', (v) {
                      setState(() => _form = form.copyWith(makeupForDate: v));
                    }),
                ],
              ),
              _section(
                title: 'Session participants',
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Child'),
                    value: form.participantChild,
                    onChanged: (v) {
                      setState(
                        () => _form = form.copyWith(participantChild: v ?? false),
                      );
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Parent/caregiver'),
                    value: form.participantParent,
                    onChanged: (v) {
                      setState(
                        () => _form = form.copyWith(participantParent: v ?? false),
                      );
                    },
                  ),
                  _field('Other participants', form.participantOther ?? '', (v) {
                    setState(() => _form = form.copyWith(participantOther: v));
                  }),
                ],
              ),
              _section(
                title: '1. IFSP outcome(s) and developmental step(s)',
                children: [
                  _multiline(
                    'List each IFSP outcome and developmental step addressed',
                    form.q1IfspOutcomes,
                    (v) => setState(() => _form = form.copyWith(q1IfspOutcomes: v)),
                    minLines: 4,
                    required: true,
                  ),
                ],
              ),
              _section(
                title: '2. Session description and progress',
                children: [
                  _multiline(
                    'Describe the session, routine activity, strategies used, and parent feedback',
                    form.q2SessionDescription,
                    (v) => setState(
                      () => _form = form.copyWith(q2SessionDescription: v),
                    ),
                    minLines: 6,
                    required: true,
                  ),
                ],
              ),
              _section(
                title: '3. How did you work with the parent/caregiver?',
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Observed parent/caregiver and child during routines',
                    ),
                    value: form.q3ObservedRoutines,
                    onChanged: (v) {
                      setState(
                        () => _form = form.copyWith(q3ObservedRoutines: v ?? false),
                      );
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Parent/caregiver tried activity; feedback exchanged',
                    ),
                    value: form.q3ParentTriedActivity,
                    onChanged: (v) {
                      setState(
                        () => _form = form.copyWith(q3ParentTriedActivity: v ?? false),
                      );
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Demonstrated activity to parent/caregiver'),
                    value: form.q3DemonstratedActivity,
                    onChanged: (v) {
                      setState(
                        () => _form = form.copyWith(q3DemonstratedActivity: v ?? false),
                      );
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Reviewed communication tool with parent/caregiver',
                    ),
                    value: form.q3ReviewedCommTool,
                    onChanged: (v) {
                      setState(
                        () => _form = form.copyWith(q3ReviewedCommTool: v ?? false),
                      );
                    },
                  ),
                  _field('Other technique', form.q3Other ?? '', (v) {
                    setState(() => _form = form.copyWith(q3Other: v));
                  }),
                ],
              ),
              _section(
                title: '4. Strategies between visits',
                children: [
                  _multiline(
                    'Activities the family agreed to do until the next visit',
                    form.q4HomeStrategies,
                    (v) => setState(() => _form = form.copyWith(q4HomeStrategies: v)),
                    minLines: 4,
                    required: true,
                  ),
                ],
              ),
              _section(
                title: 'Signatures',
                children: [
                  _field('Parent/caregiver signature', form.parentSignature ?? '', (v) {
                    setState(() => _form = form.copyWith(parentSignature: v));
                  }),
                  _field('Parent signature date', form.parentSignatureDate ?? '', (v) {
                    setState(() => _form = form.copyWith(parentSignatureDate: v));
                  }),
                  _field('Relationship to child', form.parentRelationship ?? '', (v) {
                    setState(() => _form = form.copyWith(parentRelationship: v));
                  }),
                  const Divider(height: 24),
                  _field(
                    'Interventionist signature',
                    form.interventionistSignature ?? form.interventionistName,
                    (v) {
                      setState(
                        () => _form = form.copyWith(interventionistSignature: v),
                      );
                    },
                  ),
                  _field(
                    'Interventionist signature date',
                    form.interventionistSignatureDate ?? form.dateNoteWritten ?? '',
                    (v) {
                      setState(
                        () => _form = form.copyWith(interventionistSignatureDate: v),
                      );
                    },
                  ),
                  _field(
                    'License/certification #',
                    form.interventionistLicense ?? form.credentials ?? '',
                    (v) {
                      setState(
                        () => _form = form.copyWith(interventionistLicense: v),
                      );
                    },
                  ),
                  const Divider(height: 24),
                  _field('Supervising clinician (if applicable)', form.supervisorName ?? '', (v) {
                    setState(() => _form = form.copyWith(supervisorName: v));
                  }),
                  _field('Supervisor signature date', form.supervisorSignatureDate ?? '', (v) {
                    setState(() => _form = form.copyWith(supervisorSignatureDate: v));
                  }),
                  _field('Supervisor license #', form.supervisorLicense ?? '', (v) {
                    setState(() => _form = form.copyWith(supervisorLicense: v));
                  }),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(context),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save session note'),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NYC Early Intervention Program',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text('Individual Session Note (Home/Facility) — Version 1'),
            SizedBox(height: 8),
            Text(
              'All fields marked required must be completed for billing and audit. '
              'Document contemporaneously or as close as possible to the session.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _BoundTextField(
        key: ValueKey('$label-$value'),
        label: label,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _multiline(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int minLines = 3,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _BoundTextField(
        key: ValueKey('$label-$value'),
        label: required ? '$label *' : label,
        value: value,
        onChanged: onChanged,
        minLines: minLines,
        multiline: true,
      ),
    );
  }

  String? _normalizeIfspLocation(String? location) {
    if (location == null || location.isEmpty) return location;
    switch (location) {
      case 'Home/Community':
        return 'Home/Community (natural environment)';
      case 'Facility':
        return 'Facility / center-based';
      case 'Telehealth':
        return 'Telehealth (with parent consent)';
      default:
        return location;
    }
  }

  String _ifspLocationValue(String? location) {
    if (location == 'Other') return 'Other';
    if (location == null || location.isEmpty) {
      return _ifspServiceLocations.first;
    }
    final normalized = _normalizeIfspLocation(location) ?? location;
    if (_ifspServiceLocations.contains(normalized)) return normalized;
    return normalized;
  }

  List<String> _ifspLocationItems(String? location) {
    final items = [..._ifspServiceLocations];
    final normalized = _normalizeIfspLocation(location);
    if (normalized != null &&
        normalized.isNotEmpty &&
        !items.contains(normalized)) {
      items.insert(items.length - 1, normalized);
    }
    return items;
  }

  String? _normalizeIntensity(String? intensity) {
    if (intensity == null || intensity.isEmpty) return intensity;
    switch (intensity) {
      case 'Home/Community':
        return 'Home/Community (as authorized in IFSP)';
      case 'Individual-Facility':
        return 'Individual-Facility (as authorized in IFSP)';
      default:
        return intensity;
    }
  }

  String _intensityValue(String? intensity) {
    if (intensity == 'Other') return 'Other';
    if (intensity == null || intensity.isEmpty) {
      return _intensityOptions.first;
    }
    final normalized = _normalizeIntensity(intensity) ?? intensity;
    if (_intensityOptions.contains(normalized)) return normalized;
    return normalized;
  }

  List<String> _intensityItems(String? intensity) {
    final items = [..._intensityOptions];
    final normalized = _normalizeIntensity(intensity);
    if (normalized != null &&
        normalized.isNotEmpty &&
        !items.contains(normalized)) {
      items.insert(items.length - 1, normalized);
    }
    return items;
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return _scrollableDropdown(
      label: label,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _scrollableDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final selected = items.contains(value) ? value : items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        menuMaxHeight: 280,
        decoration: InputDecoration(labelText: label),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e.isEmpty ? '—' : e,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final form = _form;
    if (form == null) return;

    if (!form.hasRequiredClinicalFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete required fields: IFSP outcomes (#1), session description (#2), '
            'and home strategies (#4).',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(therapistRepositoryProvider).saveEipSessionNote(form);
      await ref.read(clinicalRepositoryProvider).saveProgressNote(
            sessionId: form.sessionId,
            summary: form.toProgressSummary(),
          );

      ref.invalidate(therapistSessionsProvider);
      ref.invalidate(therapistDashboardProvider);
      ref.invalidate(therapistWeeklyProgressProvider);
      ref.invalidate(sessionNoteFormContextProvider(form.sessionId));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'NYC EIP session note saved — parent can view progress summary',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _BoundTextField extends StatefulWidget {
  const _BoundTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minLines = 1,
    this.multiline = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int minLines;
  final bool multiline;

  @override
  State<_BoundTextField> createState() => _BoundTextFieldState();
}

class _BoundTextFieldState extends State<_BoundTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _BoundTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        alignLabelWithHint: widget.multiline,
      ),
      minLines: widget.multiline ? widget.minLines : 1,
      maxLines: widget.multiline ? null : 1,
      onChanged: widget.onChanged,
    );
  }
}
