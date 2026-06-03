import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../platform/data/platform_repository.dart';
import '../data/therapist_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';

final therapistSessionsProvider =
    FutureProvider<List<TherapistSessionModel>>((ref) async {
  return ref.watch(therapistRepositoryProvider).fetchSessions();
});

class SessionNotesScreen extends ConsumerWidget {
  const SessionNotesScreen({super.key});

  Future<void> _openSoapEditor(
    BuildContext context,
    WidgetRef ref,
    TherapistSessionModel session,
  ) async {
    final subjective = TextEditingController();
    final objective = TextEditingController();
    final assessment = TextEditingController();
    final plan = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SOAP · ${session.childName}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjective,
                  decoration: const InputDecoration(labelText: 'Subjective'),
                  maxLines: 2,
                ),
                TextField(
                  controller: objective,
                  decoration: const InputDecoration(labelText: 'Objective'),
                  maxLines: 2,
                ),
                TextField(
                  controller: assessment,
                  decoration: const InputDecoration(labelText: 'Assessment'),
                  maxLines: 2,
                ),
                TextField(
                  controller: plan,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      final s = await ref
                          .read(platformRepositoryProvider)
                          .suggestSoap(childName: session.childName);
                      subjective.text = s['subjective'] ?? '';
                      objective.text = s['objective'] ?? '';
                      assessment.text = s['assessment'] ?? '';
                      plan.text = s['plan'] ?? '';
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('AI assist: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('AI suggest'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save SOAP Note'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved == true && context.mounted) {
      try {
        await ref.read(therapistRepositoryProvider).saveSoapNote(
              sessionId: session.id,
              subjective: subjective.text,
              objective: objective.text,
              assessment: assessment.text,
              plan: plan.text,
            );
        ref.invalidate(therapistSessionsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOAP note saved')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e')),
          );
        }
      }
    }

    subjective.dispose();
    objective.dispose();
    assessment.dispose();
    plan.dispose();
  }

  Future<void> _evv(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    String eventType,
  ) async {
    try {
      await ref.read(platformRepositoryProvider).recordEvv(
            sessionId: sessionId,
            lat: 30.2672,
            lng: -97.7431,
            eventType: eventType,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('EVV $eventType recorded')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('EVV failed: $e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(therapistSessionsProvider);

    return AppScaffold(
      title: 'Session Notes',
      body: sessions.when(
        data: (list) {
          if (list.isEmpty) {
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start a session from an appointment, then document SOAP notes here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/therapist/appointments'),
                      icon: const Icon(Icons.event),
                      label: const Text('Go to appointments'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final s = list[index];
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(s.childName),
                      subtitle: Text(s.status),
                      trailing: Icon(
                        s.hasSoap ? Icons.check_circle : Icons.edit_note,
                        color: s.hasSoap ? Colors.green : null,
                      ),
                      onTap: () => _openSoapEditor(context, ref, s),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => _evv(
                              context,
                              ref,
                              s.id,
                              'CHECK_IN',
                            ),
                            child: const Text('EVV in'),
                          ),
                          TextButton(
                            onPressed: () => _evv(
                              context,
                              ref,
                              s.id,
                              'CHECK_OUT',
                            ),
                            child: const Text('EVV out'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
