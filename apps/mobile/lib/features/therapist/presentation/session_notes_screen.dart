import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/document_upload.dart';
import '../../platform/data/platform_repository.dart';
import '../data/therapist_repository.dart';
import '../therapist_providers.dart';
import 'therapist_weekly_progress_section.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/speech_dictation.dart';

final therapistSessionsProvider = FutureProvider<List<TherapistSessionModel>>((
  ref,
) async {
  return ref.watch(therapistRepositoryProvider).fetchSessions();
});

final sessionNoteDocumentsProvider =
    FutureProvider<List<DocumentItemModel>>((ref) async {
  final docs = await ref.watch(platformRepositoryProvider).fetchDocuments();
  return docs
      .where(
        (d) => d.type == 'SOAP_NOTE' || d.type == 'PROGRESS_REPORT',
      )
      .toList();
});

class SessionNotesScreen extends ConsumerWidget {
  const SessionNotesScreen({super.key});

  static String _buildProgressSummary({
    required String explicit,
    required String plan,
    required String assessment,
    required String subjective,
  }) {
    if (explicit.trim().isNotEmpty) return explicit.trim();
    final parts = <String>[
      if (plan.trim().isNotEmpty) plan.trim(),
      if (assessment.trim().isNotEmpty) assessment.trim(),
      if (subjective.trim().isNotEmpty) subjective.trim(),
    ];
    return parts.isEmpty ? 'Session documented.' : parts.join('\n\n');
  }

  Future<void> _openSoapEditor(
    BuildContext context,
    WidgetRef ref,
    TherapistSessionModel session,
  ) async {
    final result = await showModalBottomSheet<_SoapEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SoapEditorSheet(
        session: session,
        onSuggest: () => ref
            .read(platformRepositoryProvider)
            .suggestSoap(childName: session.childName),
      ),
    );

    if (result == null || !context.mounted) return;

    var soapSaved = false;
    var progressSaved = false;
    Object? soapError;
    Object? progressError;

    try {
      await ref.read(therapistRepositoryProvider).saveSoapNote(
            sessionId: session.id,
            subjective: result.subjective,
            objective: result.objective,
            assessment: result.assessment,
            plan: result.plan,
          );
      soapSaved = true;
    } catch (e) {
      soapError = e;
    }

    try {
      final summary = _buildProgressSummary(
        explicit: result.progressSummary,
        plan: result.plan,
        assessment: result.assessment,
        subjective: result.subjective,
      );
      await ref.read(clinicalRepositoryProvider).saveProgressNote(
            sessionId: session.id,
            summary: summary,
          );
      progressSaved = true;
    } catch (e) {
      progressError = e;
    }

    ref.invalidate(therapistSessionsProvider);
    ref.invalidate(therapistDashboardProvider);
    ref.invalidate(therapistWeeklyProgressProvider);

    if (context.mounted) {
      if (soapSaved && progressSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SOAP and progress summary saved — parent can view in progress notes',
            ),
          ),
        );
      } else if (soapSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SOAP saved, but progress summary failed: $progressError',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              progressSaved
                  ? 'Progress summary saved, but SOAP failed: $soapError'
                  : 'Save failed: ${soapError ?? progressError}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _completeSession(
    BuildContext context,
    WidgetRef ref,
    TherapistSessionModel session,
  ) async {
    try {
      await ref.read(therapistRepositoryProvider).completeSession(session.id);
      ref.invalidate(therapistSessionsProvider);
      ref.invalidate(therapistDashboardProvider);
      if (!context.mounted) return;

      if (!session.hasSoap) {
        final writeNow = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Documentation due'),
            content: Text(
              'Visit with ${session.childName} ended. Complete SOAP notes now '
              'while details are fresh — parents are notified to review progress.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Later'),
              ),
              GlossyButton(
                title: 'Write SOAP now',
                size: GlossyButtonSize.small,
                fullWidth: false,
                variant: GlossyButtonVariant.tealBlue,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
        if (writeNow == true && context.mounted) {
          await _openSoapEditor(context, ref, session);
          return;
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Visit ended — complete SOAP notes, parent notified to review',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Complete failed: $e')));
      }
    }
  }

  List<DocumentItemModel> _attachmentsForSession(
    List<DocumentItemModel> docs,
    TherapistSessionModel session,
  ) {
    if (session.childId == null) return const [];
    return docs
        .where((d) => d.childId == session.childId)
        .toList();
  }

  Future<void> _attachPdf(
    BuildContext context,
    WidgetRef ref,
    TherapistSessionModel session,
  ) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: documentUploadExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file bytes')),
        );
      }
      return;
    }

    final mimeType = file.extension != null
        ? mimeFromExtension(file.extension!)
        : 'application/octet-stream';
    final validationError = validateDocumentUpload(
      extension: file.extension,
      mimeType: mimeType,
    );
    if (validationError != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
      }
      return;
    }

    final docType = session.hasSoap ? 'SOAP_NOTE' : 'PROGRESS_REPORT';
    final title = '${session.childName} · ${file.name}';

    try {
      await ref.read(platformRepositoryProvider).uploadDocumentFile(
            title: title,
            fileName: file.name,
            bytes: bytes,
            mimeType: mimeType,
            type: docType,
            childId: session.childId,
          );
      ref.invalidate(sessionNoteDocumentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attached ${file.name} as ${docType.replaceAll('_', ' ').toLowerCase()}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatUploadError(e))),
        );
      }
    }
  }

  Future<void> _downloadServiceLog(
    BuildContext context,
    WidgetRef ref,
    TherapistSessionModel session,
  ) async {
    try {
      final path = await ref
          .read(therapistRepositoryProvider)
          .downloadServiceLogPdf(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Service log saved: $path')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _evv(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    String eventType,
  ) async {
    try {
      final capture = await LocationService().captureCurrentPosition();
      if (!capture.isSuccess) {
        if (context.mounted) {
          await LocationService.showLocationRequiredDialog(
            context,
            capture.failureReason ?? LocationFailure.serviceDisabled,
          );
        }
        return;
      }
      final coords = (lat: capture.latitude!, lng: capture.longitude!);
      await ref
          .read(platformRepositoryProvider)
          .recordEvv(
            sessionId: sessionId,
            lat: coords.lat,
            lng: coords.lng,
            eventType: eventType,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('EVV $eventType recorded')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('EVV failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(therapistSessionsProvider);
    final sessionDocs = ref.watch(sessionNoteDocumentsProvider);

    return AppScaffold(
      title: 'Session Notes and Service logs',
      bottomNavigationBar: TherapistBottomNav(
        current: TherapistNavTab.sessions,
      ),
      body: sessions.when(
        data: (list) {
          final docs = sessionDocs.valueOrNull ?? [];
          final sorted = [...list]..sort((a, b) {
            if (a.needsDocumentation != b.needsDocumentation) {
              return a.needsDocumentation ? -1 : 1;
            }
            if (a.hasSoap != b.hasSoap) {
              return a.hasSoap ? 1 : -1;
            }
            return 0;
          });

          if (sorted.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.note_alt_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'No sessions yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start a session from Appointments (play button on a '
                      'confirmed visit), then add SOAP notes here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    GlossyButton(
                      title: 'Go to appointments',
                      icon: Icons.event,
                      variant: GlossyButtonVariant.tealBlue,
                      onPressed: () =>
                          context.push('${AppRoutes.therapistHome}/appointments'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const TherapistWeeklyProgressSection(),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Use "Session note (EIP)" for the NYC Early Intervention '
                    'fillable form. When a parent signs, a service log is '
                    'created automatically and can be downloaded as a PDF.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...sorted.map((s) {
                final attachments = _attachmentsForSession(docs, s);
                final attachmentLabel = attachments.isEmpty
                    ? null
                    : attachments.map((d) => d.fileName).join(', ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: s.needsDocumentation && !s.hasSoap
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(s.childName),
                          subtitle: Text(
                            [
                              if (s.needsDocumentation && !s.hasSoap)
                                '${s.status} · documentation needed'
                              else
                                s.status,
                              if (attachmentLabel != null)
                                'Attachments: $attachmentLabel',
                            ].join('\n'),
                          ),
                          trailing: Icon(
                            s.hasSoap ? Icons.check_circle : Icons.edit_note,
                            color: s.hasSoap ? Colors.green : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              GlossyButton(
                                title: s.eipFormFullySigned
                                    ? 'View session note (locked)'
                                    : s.hasSoap
                                        ? 'Edit session note (EIP)'
                                        : 'Session note (EIP)',
                                icon: s.eipFormFullySigned
                                    ? Icons.visibility_outlined
                                    : Icons.assignment,
                                size: GlossyButtonSize.small,
                                fullWidth: false,
                                variant: GlossyButtonVariant.bluePurple,
                                onPressed: () => context.push(
                                  '${AppRoutes.therapistHome}/session-notes/${s.id}/form',
                                ),
                              ),
                              GlossyButton(
                                title: 'Quick SOAP',
                                icon: Icons.edit_note,
                                size: GlossyButtonSize.small,
                                fullWidth: false,
                                variant: GlossyButtonVariant.neutral,
                                onPressed: s.eipFormFullySigned
                                    ? null
                                    : () => _openSoapEditor(context, ref, s),
                              ),
                              GlossyOutlinedButton.icon(
                                onPressed: () =>
                                    _attachPdf(context, ref, s),
                                icon: Icons.attach_file,
                                child: const Text('Attach PDF'),
                              ),
                              if (s.hasServiceLog)
                                GlossyOutlinedButton.icon(
                                  onPressed: () =>
                                      _downloadServiceLog(context, ref, s),
                                  icon: Icons.picture_as_pdf_outlined,
                                  child: Text(
                                    'Service log · ${s.serviceLog!.childName}',
                                  ),
                                ),
                              if (s.status == 'IN_PROGRESS')
                                GlossyButton(
                                  title: 'End visit',
                                  size: GlossyButtonSize.small,
                                  fullWidth: false,
                                  variant: GlossyButtonVariant.redDarkRed,
                                  onPressed: () =>
                                      _completeSession(context, ref, s),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _evv(context, ref, s.id, 'CHECK_IN'),
                                child: const Text('EVV in'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _evv(context, ref, s.id, 'CHECK_OUT'),
                                child: const Text('EVV out'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppSnackBar.messageFromError(e),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: GlossyButtonVariant.neutral,
                  onPressed: () =>
                      ref.invalidate(therapistSessionsProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoapEditorResult {
  const _SoapEditorResult({
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    required this.progressSummary,
  });

  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final String progressSummary;
}

class _SoapEditorSheet extends StatefulWidget {
  const _SoapEditorSheet({
    required this.session,
    required this.onSuggest,
  });

  final TherapistSessionModel session;
  final Future<Map<String, String>> Function() onSuggest;

  @override
  State<_SoapEditorSheet> createState() => _SoapEditorSheetState();
}

class _SoapEditorSheetState extends State<_SoapEditorSheet> {
  late final TextEditingController _subjective;
  late final TextEditingController _objective;
  late final TextEditingController _assessment;
  late final TextEditingController _plan;
  late final TextEditingController _progressSummary;

  @override
  void initState() {
    super.initState();
    _subjective = TextEditingController(text: widget.session.subjective ?? '');
    _objective = TextEditingController(text: widget.session.objective ?? '');
    _assessment = TextEditingController(text: widget.session.assessment ?? '');
    _plan = TextEditingController(text: widget.session.plan ?? '');
    _progressSummary = TextEditingController();
  }

  @override
  void dispose() {
    _subjective.dispose();
    _objective.dispose();
    _assessment.dispose();
    _plan.dispose();
    _progressSummary.dispose();
    super.dispose();
  }

  void _save() {
    final fields = [
      _subjective.text,
      _objective.text,
      _assessment.text,
      _plan.text,
      _progressSummary.text,
    ];
    if (!fields.any((t) => t.trim().isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter at least one SOAP field or progress summary',
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _SoapEditorResult(
        subjective: _subjective.text.trim(),
        objective: _objective.text.trim(),
        assessment: _assessment.text.trim(),
        plan: _plan.text.trim(),
        progressSummary: _progressSummary.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SOAP · ${widget.session.childName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SpeechDictationTextField(
              fieldKey: 'soap-subjective-${widget.session.id}',
              controller: _subjective,
              decoration: const InputDecoration(labelText: 'Subjective'),
              maxLines: 4,
              minLines: 2,
            ),
            SpeechDictationTextField(
              fieldKey: 'soap-objective-${widget.session.id}',
              controller: _objective,
              decoration: const InputDecoration(labelText: 'Objective'),
              maxLines: 4,
              minLines: 2,
            ),
            SpeechDictationTextField(
              fieldKey: 'soap-assessment-${widget.session.id}',
              controller: _assessment,
              decoration: const InputDecoration(labelText: 'Assessment'),
              maxLines: 4,
              minLines: 2,
            ),
            SpeechDictationTextField(
              fieldKey: 'soap-plan-${widget.session.id}',
              controller: _plan,
              decoration: const InputDecoration(labelText: 'Plan'),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 12),
            SpeechDictationTextField(
              fieldKey: 'soap-progress-${widget.session.id}',
              controller: _progressSummary,
              decoration: const InputDecoration(
                labelText: 'Progress summary (optional)',
              ),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 16),
            GlossyOutlinedButton(
              onPressed: () async {
                try {
                  final s = await widget.onSuggest();
                  setState(() {
                    _subjective.text = s['subjective'] ?? '';
                    _objective.text = s['objective'] ?? '';
                    _assessment.text = s['assessment'] ?? '';
                    _plan.text = s['plan'] ?? '';
                  });
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('AI assist: $e')),
                  );
                }
              },
              child: const Text('AI suggest'),
            ),
            const SizedBox(height: 8),
            GlossyButton(
              title: widget.session.hasSoap ? 'Update SOAP Note' : 'Save SOAP Note',
              variant: GlossyButtonVariant.greenTeal,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
