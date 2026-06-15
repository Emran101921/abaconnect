import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_glossy_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_dashboard_card.dart';
import '../../../shared/widgets/app_glassy_tab_bar.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../telehealth/presentation/telehealth_screen.dart';
import '../data/parent_booking_repository.dart';
import 'parent_dashboard_providers.dart';

class ParentAppointmentsScreen extends ConsumerStatefulWidget {
  const ParentAppointmentsScreen({super.key, this.highlightAppointmentId});

  final String? highlightAppointmentId;

  @override
  ConsumerState<ParentAppointmentsScreen> createState() =>
      _ParentAppointmentsScreenState();
}

class _ParentAppointmentsScreenState extends ConsumerState<ParentAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _handledHighlight = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel appointment?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep'),
            ),
            GlossyButton(
              title: 'Cancel visit',
              size: GlossyButtonSize.small,
              fullWidth: false,
              variant: GlossyButtonVariant.redDarkRed,
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            ),
          ],
        );
      },
    );
    if (reason == null || !context.mounted) return;

    try {
      await ref
          .read(parentBookingRepositoryProvider)
          .cancelAppointment(
            appointmentId: appointment.id,
            reason: reason.isEmpty ? null : reason,
          );
      ref.invalidate(parentAppointmentsProvider);
      ref.invalidate(parentDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    }
  }

  Future<void> _joinTelehealth(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) async {
    try {
      final session = await ref
          .read(platformRepositoryProvider)
          .joinTelehealth(appointment.id);
      if (!context.mounted) return;
      if (session.joinUrl != null) {
        showTelehealthRoomLinkDialog(context, session.joinUrl!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room ready — open Telehealth to join')),
        );
        context.push(AppRoutes.telehealth);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Telehealth failed: $e')));
      }
    }
  }

  void _maybeFocusHighlight(List<AppointmentModel> list) {
    final id = widget.highlightAppointmentId;
    if (_handledHighlight || id == null || id.isEmpty) return;
    final inCompleted = list.any((a) => a.id == id && a.isCompleted);
    if (inCompleted && _tabController.index != 1) {
      _tabController.animateTo(1);
    }
    _handledHighlight = true;
  }

  Future<void> _exportCalendar(BuildContext context, WidgetRef ref) async {
    try {
      final path = await ref
          .read(parentBookingRepositoryProvider)
          .downloadAppointmentsIcal();
      if (!context.mounted) return;
      final message = kIsWeb
          ? 'Calendar file downloaded'
          : (path.isNotEmpty ? 'Saved to $path' : 'Calendar file saved');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _reschedule(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) async {
    var start = appointment.scheduledStart;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: start,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time == null || !context.mounted) return;
    start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final end = start.add(const Duration(hours: 1));

    try {
      await ref
          .read(parentBookingRepositoryProvider)
          .rescheduleAppointment(
            appointmentId: appointment.id,
            start: start,
            end: end,
          );
      ref.invalidate(parentAppointmentsProvider);
      ref.invalidate(parentDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment rescheduled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reschedule failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(parentAppointmentsProvider);

    return AppScaffold(
      title: 'My Appointments',
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Export to calendar',
          onPressed: () => _exportCalendar(context, ref),
        ),
      ],
      body: appointments.when(
        data: (list) {
          _maybeFocusHighlight(list);
          final highlightId = widget.highlightAppointmentId;
          final active =
              list.where((a) => !a.isCompleted).toList()
                ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
          final today =
              active.where((a) => a.isToday).toList();
          final later =
              active.where((a) => !a.isToday).toList();
          final completed =
              list.where((a) => a.isCompleted).toList()
                ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));

          if (list.isEmpty) {
            return _EmptyAppointments(message: 'Book a session to get started');
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AppGlassyTabBar(
                  controller: _tabController,
                  tabs: [
                    AppGlassyTabItem(
                      label: 'Schedule',
                      icon: Icons.calendar_month_outlined,
                      gradient: AppGlossyGradients.tertiary,
                      count: active.length,
                      alertCount: today.length,
                    ),
                    AppGlassyTabItem(
                      label: 'Completed',
                      icon: Icons.verified_outlined,
                      gradient: AppGlossyGradients.success,
                      count: completed.length,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ScheduleTabList(
                      today: today,
                      later: later,
                      onRefresh: () async {
                        ref.invalidate(parentAppointmentsProvider);
      ref.invalidate(parentDashboardProvider);
                        await ref.read(parentAppointmentsProvider.future);
                      },
                      itemBuilder: (a) => _UpcomingCard(
                        appointment: a,
                        highlightToday: a.isToday,
                        highlighted: highlightId == a.id,
                        onReschedule: () => _reschedule(context, ref, a),
                        onCancel: () => _cancel(context, ref, a),
                        onJoinTelehealth: () => _joinTelehealth(context, ref, a),
                      ),
                    ),
                    _AppointmentList(
                      appointments: completed,
                      sectionTitle: 'Completed sessions',
                      sectionSubtitle: 'Tap a visit to open session history',
                      emptyMessage: 'No completed sessions yet',
                      emptySubtitle:
                          'Finished visits will appear here with a summary',
                      onRefresh: () async {
                        ref.invalidate(parentAppointmentsProvider);
      ref.invalidate(parentDashboardProvider);
                        await ref.read(parentAppointmentsProvider.future);
                      },
                      itemBuilder: (a) => _CompletedGlassCard(
                        appointment: a,
                        highlighted: highlightId == a.id,
                        onTap: () => context.push(
                          '${AppRoutes.parentHome}/session-history',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ScheduleTabList extends StatelessWidget {
  const _ScheduleTabList({
    required this.today,
    required this.later,
    required this.onRefresh,
    required this.itemBuilder,
  });

  final List<AppointmentModel> today;
  final List<AppointmentModel> later;
  final Future<void> Function() onRefresh;
  final Widget Function(AppointmentModel) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (today.isEmpty && later.isEmpty) {
      return const _EmptyAppointments(
        message: 'No upcoming appointments',
        subtitle: 'Confirmed and scheduled visits appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AppContentContainer(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (today.isNotEmpty) ...[
              _ScheduleSectionHeader(
                title: 'Today',
                subtitle: 'Sessions happening today',
                alertCount: today.length,
              ),
              const SizedBox(height: 10),
              ...today.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: itemBuilder(a),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (later.isNotEmpty) ...[
              _ScheduleSectionHeader(
                title: 'Upcoming',
                subtitle: 'Later scheduled visits',
              ),
              const SizedBox(height: 10),
              ...later.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: itemBuilder(a),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScheduleSectionHeader extends StatelessWidget {
  const _ScheduleSectionHeader({
    required this.title,
    required this.subtitle,
    this.alertCount,
  });

  final String title;
  final String subtitle;
  final int? alertCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppSectionHeader(title: title, subtitle: subtitle),
        ),
        if (alertCount != null && alertCount! > 0)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '$alertCount',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    required this.appointments,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.onRefresh,
    required this.itemBuilder,
  });

  final List<AppointmentModel> appointments;
  final String sectionTitle;
  final String sectionSubtitle;
  final String emptyMessage;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;
  final Widget Function(AppointmentModel) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return _EmptyAppointments(
        message: emptyMessage,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AppContentContainer(
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: appointments.length + 1,
          separatorBuilder: (_, index) =>
              index == 0 ? const SizedBox.shrink() : const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return AppSectionHeader(
                title: sectionTitle,
                subtitle: sectionSubtitle,
              );
            }
            return itemBuilder(appointments[index - 1]);
          },
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.appointment,
    required this.onReschedule,
    required this.onCancel,
    required this.onJoinTelehealth,
    this.highlightToday = false,
    this.highlighted = false,
  });

  final AppointmentModel appointment;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;
  final VoidCallback onJoinTelehealth;
  final bool highlightToday;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final canChange = !['COMPLETED', 'CANCELLED', 'NO_SHOW'].contains(a.status);
    final loc = a.locationType ?? 'IN_HOME';

    return AppDashboardCard(
      elevated: highlightToday || highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'From notification',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (highlightToday)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'Today',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            '${a.therapyType} · ${a.childName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('${a.therapistName} · $loc'),
          Text(DateFormat.yMMMd().add_jm().format(a.scheduledStart)),
          const SizedBox(height: 8),
          Chip(label: Text(a.status)),
          if (a.isTelehealth && !['COMPLETED', 'CANCELLED'].contains(a.status))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlossyButton(
                title: 'Join telehealth',
                icon: Icons.video_call,
                variant: GlossyButtonVariant.tealBlue,
                onPressed: onJoinTelehealth,
              ),
            ),
          if (canChange)
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'reschedule') {
                    onReschedule();
                  } else if (v == 'cancel') {
                    onCancel();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
                  PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletedGlassCard extends StatelessWidget {
  const _CompletedGlassCard({
    required this.appointment,
    required this.onTap,
    this.highlighted = false,
  });

  final AppointmentModel appointment;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppGlossyGradients.success.colors.first.withValues(
                      alpha: isDark ? 0.22 : 0.14,
                    ),
                    AppGlossyGradients.info.colors.last.withValues(
                      alpha: isDark ? 0.18 : 0.1,
                    ),
                  ],
                ),
                border: Border.all(
                  color: highlighted
                      ? Theme.of(context).colorScheme.primary.withValues(
                            alpha: 0.75,
                          )
                      : AppGlossyGradients.success.colors.last.withValues(
                          alpha: 0.35,
                        ),
                  width: highlighted ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppGlossyGradients.success.colors.last.withValues(
                      alpha: 0.15,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGlossyGradients.success,
                      boxShadow: [
                        BoxShadow(
                          color: AppGlossyGradients.baseShadowColor(
                            AppGlossyGradients.success,
                          ).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.therapyType,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${a.childName} with ${a.therapistName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          DateFormat.yMMMd().add_jm().format(a.scheduledStart),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments({required this.message, this.subtitle});

  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppHealthcareIllustration(
              type: AppIllustrationType.scheduling,
              size: 120,
            ),
            const SizedBox(height: 24),
            Text(message, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
