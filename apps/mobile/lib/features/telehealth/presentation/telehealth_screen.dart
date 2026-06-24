import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../parent/presentation/parent_dashboard_providers.dart';
import '../../platform/data/platform_repository.dart';
import '../../therapist/presentation/therapist_home_screen.dart';

final telehealthSessionsProvider = FutureProvider<List<TelehealthSessionModel>>(
  (ref) {
    return ref.watch(platformRepositoryProvider).fetchTelehealthSessions();
  },
);

class TelehealthScreen extends ConsumerWidget {
  const TelehealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(telehealthSessionsProvider);
    final role = ref.watch(authStateProvider).valueOrNull?.user.role;
    final isTherapist = role == UserRole.therapist;
    final parentAppointments = ref.watch(parentAppointmentsProvider);
    final therapistAppointments = ref.watch(therapistAppointmentsProvider);

    return AppScaffold(
      title: 'Telehealth',
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.schedule),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(telehealthSessionsProvider);
          if (isTherapist) {
            ref.invalidate(therapistAppointmentsProvider);
          } else {
            ref.invalidate(parentAppointmentsProvider);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Virtual sessions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create or open a video room. Set TELEHEALTH_VENDOR=daily or twilio '
              'on the API for vendor-hosted rooms; otherwise demo links are used.',
            ),
            const SizedBox(height: 16),
            sessions.when(
              data: (list) {
                if (list.isNotEmpty) {
                  return Column(
                    children: list.map((s) {
                      return Card(
                        child: ListTile(
                          title: Text(s.appointmentLabel ?? s.roomId),
                          subtitle: Text(
                            [
                              if (s.vendor != null) 'Vendor: ${s.vendor}',
                              s.joinUrl ?? 'Room ready',
                            ].join('\n'),
                          ),
                          isThreeLine: s.vendor != null,
                          trailing: GlossyButton(
                            title: 'Open',
                            size: GlossyButtonSize.small,
                            fullWidth: false,
                            variant: GlossyButtonVariant.tealBlue,
                            onPressed: s.joinUrl != null
                                ? () => _showRoomLink(context, s.joinUrl!)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }
                if (isTherapist) {
                  return therapistAppointments.when(
                    data: (apts) {
                      final telehealth = apts
                          .where((a) => a.isTelehealth)
                          .toList();
                      return _appointmentJoinList(
                        context,
                        ref,
                        telehealth
                            .map(
                              (a) => _TelehealthAppointmentRow(
                                id: a.id,
                                title: '${a.childName} · ${a.therapyType}',
                                subtitle: a.status,
                                scheduledStart: a.scheduledStart,
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('$e'),
                  );
                }
                return parentAppointments.when(
                  data: (apts) {
                    final telehealth = apts
                        .where((a) => a.isTelehealth)
                        .toList();
                    return _appointmentJoinList(
                      context,
                      ref,
                      telehealth
                          .map(
                            (a) => _TelehealthAppointmentRow(
                              id: a.id,
                              title: a.therapyType,
                              subtitle: '${a.childName} · ${a.status}',
                              scheduledStart: a.scheduledStart,
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('$e'),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentJoinList(
    BuildContext context,
    WidgetRef ref,
    List<_TelehealthAppointmentRow> apts,
  ) {
    if (apts.isEmpty) {
      return const Text(
        'No telehealth appointments. Book or schedule visits with location type TELEHEALTH.',
      );
    }
    return Column(
      children: apts.map((a) {
        return Card(
          child: ListTile(
            title: Text(a.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.subtitle),
                if (a.scheduledStart != null) ...[
                  const SizedBox(height: 4),
                  _TelehealthCountdown(start: a.scheduledStart!),
                ],
              ],
            ),
            isThreeLine: a.scheduledStart != null,
            trailing: GlossyButton(
              title: 'Join',
              size: GlossyButtonSize.small,
              fullWidth: false,
              variant: GlossyButtonVariant.tealBlue,
              onPressed: () => _join(context, ref, a.id),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _join(
    BuildContext context,
    WidgetRef ref,
    String appointmentId,
  ) async {
    try {
      final room = await ref
          .read(platformRepositoryProvider)
          .joinTelehealth(appointmentId);
      ref.invalidate(telehealthSessionsProvider);
      if (room.joinUrl != null && context.mounted) {
        _showRoomLink(context, room.joinUrl!);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Join failed: $e')));
      }
    }
  }

  void _showRoomLink(BuildContext context, String url) {
    showTelehealthRoomLinkDialog(context, url);
  }
}

void showTelehealthRoomLinkDialog(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Session link'),
      content: SelectableText(url),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            Navigator.pop(ctx);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Link copied')));
          },
          child: const Text('Copy link'),
        ),
        GlossyButton(
          title: 'Close',
          size: GlossyButtonSize.small,
          fullWidth: false,
          variant: GlossyButtonVariant.neutral,
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

class _TelehealthAppointmentRow {
  const _TelehealthAppointmentRow({
    required this.id,
    required this.title,
    required this.subtitle,
    this.scheduledStart,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime? scheduledStart;
}

class _TelehealthCountdown extends StatefulWidget {
  const _TelehealthCountdown({required this.start});

  final DateTime start;

  @override
  State<_TelehealthCountdown> createState() => _TelehealthCountdownState();
}

class _TelehealthCountdownState extends State<_TelehealthCountdown> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  void _tick() {
    setState(() {
      _remaining = widget.start.difference(DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.jm();
    if (_remaining.isNegative) {
      return Text(
        'Started ${fmt.format(widget.start)} · ready to join',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.green.shade700),
      );
    }
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    return Text(
      'Starts ${fmt.format(widget.start)} · in ${hours}h ${minutes}m',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
