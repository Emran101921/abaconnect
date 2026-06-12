import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../messaging/messaging_providers.dart';
import '../../notifications/notification_providers.dart';
import '../data/parent_booking_repository.dart';
import 'parent_ops_tile.dart';

class ParentOperationsCategory {
  const ParentOperationsCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  static const scheduling = ParentOperationsCategory(
    id: 'scheduling',
    title: 'Scheduling',
    subtitle: 'Book sessions, manage appointments, and join telehealth',
    icon: Icons.calendar_month_outlined,
  );

  static const careTeam = ParentOperationsCategory(
    id: 'care-team',
    title: 'Care team',
    subtitle: 'Messages, providers, children, and clinical records',
    icon: Icons.groups_outlined,
  );

  static const payments = ParentOperationsCategory(
    id: 'payments',
    title: 'Payments',
    subtitle: 'Session invoices and receipts',
    icon: Icons.payment_outlined,
  );

  static const account = ParentOperationsCategory(
    id: 'account',
    title: 'Account',
    subtitle: 'Profile, notifications, security, and privacy',
    icon: Icons.manage_accounts_outlined,
  );

  static const all = [scheduling, careTeam, payments, account];

  /// Insurance-billed families use agency back-office; parents only see payments
  /// when children are self-pay (or not yet assigned a payer type).
  static List<ParentOperationsCategory> visibleFor({
    required bool showPayments,
  }) {
    return [
      scheduling,
      careTeam,
      if (showPayments) payments,
      account,
    ];
  }

  static bool childrenShowPayments(List<ChildModel> children) {
    if (children.isEmpty) return true;
    return children.every((child) {
      final type = child.insuranceType;
      return type == null || type == 'Self-pay';
    });
  }

  static ParentOperationsCategory? fromId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class ParentOperationsCategoryScreen extends ConsumerWidget {
  const ParentOperationsCategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ParentOperationsCategory.fromId(categoryId);
    if (category == null) {
      return AppScaffold(
        title: 'Not found',
        body: Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.parentHome),
            child: const Text('Back to home'),
          ),
        ),
      );
    }

    final unread = ref.watch(unreadNotificationsProvider);
    final unreadCount = unread.maybeWhen(data: (c) => c, orElse: () => 0);
    final unreadMessages = ref.watch(unreadMessageThreadsProvider);
    final unreadMessageCount = unreadMessages.maybeWhen(
      data: (c) => c,
      orElse: () => 0,
    );

    final tiles = _tilesForCategory(
      context,
      category,
      unreadCount: unreadCount,
      unreadMessageCount: unreadMessageCount,
    );

    return AppScaffold(
      title: category.title,
      subtitle: category.subtitle,
      body: AppContentContainer(
        child: ListView(
          children: [
            AppSectionHeader(
              title: category.title,
              subtitle: '${tiles.length} options in this category',
            ),
            const SizedBox(height: 12),
            ...tiles,
          ],
        ),
      ),
    );
  }

  List<Widget> _tilesForCategory(
    BuildContext context,
    ParentOperationsCategory category, {
    required int unreadCount,
    required int unreadMessageCount,
  }) {
    switch (category.id) {
      case 'scheduling':
        return [
          ParentOpsTile(
            title: 'Book session',
            subtitle: 'Schedule therapy appointments',
            icon: Icons.calendar_month,
            onTap: () => context.push('${AppRoutes.parentHome}/booking'),
          ),
          ParentOpsTile(
            title: 'My appointments',
            subtitle: 'Reschedule, cancel, export calendar',
            icon: Icons.event_note,
            onTap: () => context.push('${AppRoutes.parentHome}/appointments'),
          ),
          ParentOpsTile(
            title: 'Telehealth',
            subtitle: 'Join virtual sessions',
            icon: Icons.video_call,
            onTap: () => context.push(AppRoutes.telehealth),
          ),
        ];
      case 'care-team':
        return [
          ParentOpsTile(
            title: unreadMessageCount > 0
                ? 'Messages ($unreadMessageCount unread)'
                : 'Messages',
            subtitle: unreadMessageCount > 0
                ? 'New replies from your care team'
                : 'Chat with therapists',
            icon: Icons.message,
            onTap: () => context.push(AppRoutes.messages),
          ),
          ParentOpsTile(
            title: 'Find therapist',
            subtitle: 'Browse matched providers',
            icon: Icons.search,
            onTap: () => context.push(AppRoutes.matching),
          ),
          ParentOpsTile(
            title: 'My children',
            subtitle: 'Profiles and date of birth',
            icon: Icons.child_care,
            onTap: () => context.push('${AppRoutes.parentHome}/children'),
          ),
          ParentOpsTile(
            title: 'Session history',
            subtitle: 'Past completed sessions',
            icon: Icons.history,
            onTap: () =>
                context.push('${AppRoutes.parentHome}/session-history'),
          ),
          ParentOpsTile(
            title: 'Treatment plans',
            subtitle: 'Goals and care plans',
            icon: Icons.medical_information,
            onTap: () =>
                context.push('${AppRoutes.parentHome}/treatment-plans'),
          ),
          ParentOpsTile(
            title: 'Progress notes',
            subtitle: 'Session summaries from your therapist',
            icon: Icons.summarize_outlined,
            onTap: () => context.push('${AppRoutes.parentHome}/progress-notes'),
          ),
          ParentOpsTile(
            title: 'Screening',
            subtitle: 'Early Intervention assessments',
            icon: Icons.assignment,
            onTap: () => context.push(AppRoutes.parentScreening),
          ),
        ];
      case 'payments':
        return [
          ParentOpsTile(
            title: 'Pay for sessions',
            subtitle: 'View invoices and pay online',
            icon: Icons.payment,
            onTap: () => context.push(AppRoutes.payments),
          ),
          ParentOpsTile(
            title: 'Documents',
            subtitle: 'Upload care documents and receipts',
            icon: Icons.folder,
            onTap: () => context.push(AppRoutes.documents),
          ),
        ];
      case 'account':
        return [
          ParentOpsTile(
            title: unreadCount > 0
                ? 'Notifications ($unreadCount)'
                : 'Notifications',
            subtitle: unreadCount > 0
                ? 'Tap message alerts to open the conversation'
                : 'Alerts and reminders',
            icon: Icons.notifications,
            onTap: () => context.push(AppRoutes.notifications),
          ),
          ParentOpsTile(
            title: 'My profile',
            subtitle: 'Address and emergency contact',
            icon: Icons.person,
            onTap: () => context.push('${AppRoutes.parentHome}/profile'),
          ),
          ParentOpsTile(
            title: 'Reviews',
            subtitle: 'Rate your therapists',
            icon: Icons.star,
            onTap: () => context.push('${AppRoutes.parentHome}/reviews'),
          ),
          ParentOpsTile(
            title: 'Security',
            subtitle: 'Two-factor authentication',
            icon: Icons.security,
            onTap: () => context.push(AppRoutes.security),
          ),
          ParentOpsTile(
            title: 'Privacy',
            subtitle: 'Notice, policy, and your HIPAA rights',
            icon: Icons.privacy_tip,
            onTap: () => context.push(AppRoutes.settingsPrivacy),
          ),
          ParentOpsTile(
            title: 'File complaint',
            subtitle: 'Report a concern',
            icon: Icons.report,
            onTap: () => context.push('${AppRoutes.parentHome}/complaints'),
          ),
        ];
      default:
        return [];
    }
  }
}
