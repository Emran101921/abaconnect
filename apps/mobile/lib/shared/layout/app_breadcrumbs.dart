import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';

/// Breadcrumb trail for inner pages — improves web navigation context.
class AppBreadcrumbs extends StatelessWidget {
  const AppBreadcrumbs({
    super.key,
    this.location,
  });

  final String? location;

  static const _labels = <String, String>{
    AppRoutes.parentHome: 'Home',
    AppRoutes.parentChildren: 'Children',
    AppRoutes.parentScreening: 'Screening',
    AppRoutes.parentAppointments: 'Appointments',
    AppRoutes.parentProfile: 'Profile',
    AppRoutes.parentMarketplace: 'Marketplace',
    AppRoutes.therapistHome: 'Home',
    AppRoutes.therapistAppointments: 'Schedule',
    AppRoutes.therapistSessionNotes: 'Session notes',
    AppRoutes.therapistProfile: 'Profile',
    AppRoutes.therapistMarketplace: 'Marketplace',
    AppRoutes.agencyHome: 'Dashboard',
    AppRoutes.adminHome: 'Dashboard',
    AppRoutes.messages: 'Messages',
    AppRoutes.notifications: 'Notifications',
    AppRoutes.security: 'Security',
    AppRoutes.documents: 'Documents',
    AppRoutes.payments: 'Payments',
    AppRoutes.insurance: 'Insurance',
    AppRoutes.matching: 'Find providers',
    AppRoutes.consent: 'Consent',
    AppRoutes.telehealth: 'Telehealth',
    'verifications': 'Verifications',
    'complaints': 'Complaints',
    'users': 'Users',
    'analytics': 'Analytics',
    'compliance': 'Compliance',
    'marketplace': 'Marketplace',
    'roster': 'Roster',
    'appointments': 'Appointments',
    'session-notes': 'Session notes',
    'progress-notes': 'Progress notes',
    'reviews': 'Reviews',
    'booking': 'Booking',
    'children': 'Children',
    'session-history': 'Session history',
    'opt-in': 'Opt in',
    'onboarding': 'Onboarding',
  };

  @override
  Widget build(BuildContext context) {
    final path = location ?? GoRouterState.of(context).matchedLocation;
    final crumbs = _buildCrumbs(path);
    if (crumbs.length <= 1) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Breadcrumb: ${crumbs.map((c) => c.label).join(', ')}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < crumbs.length; i++) ...[
              if (i > 0)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              _Crumb(
                label: crumbs[i].label,
                route: crumbs[i].route,
                isLast: i == crumbs.length - 1,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_CrumbData> _buildCrumbs(String path) {
    if (path.isEmpty || path == '/') return [];

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final crumbs = <_CrumbData>[];
    var built = '';

    for (final segment in segments) {
      built += '/$segment';
      crumbs.add(
        _CrumbData(
          label: _labels[built] ?? _labels[segment] ?? _humanize(segment),
          route: built,
        ),
      );
    }
    return crumbs;
  }

  String _humanize(String segment) {
    return segment
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
        )
        .join(' ');
  }
}

class _CrumbData {
  const _CrumbData({required this.label, required this.route});
  final String label;
  final String route;
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.label,
    required this.route,
    required this.isLast,
  });

  final String label;
  final String route;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: isLast
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
          fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
        );

    if (isLast) {
      return Text(label, style: style);
    }

    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Text(label, style: style),
      ),
    );
  }
}
