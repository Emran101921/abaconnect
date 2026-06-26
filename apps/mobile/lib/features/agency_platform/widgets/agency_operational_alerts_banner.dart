import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../presentation/agency_platform_providers.dart';

class AgencyOperationalAlertsBanner extends ConsumerWidget {
  const AgencyOperationalAlertsBanner({super.key});

  String? _routeForHint(String? hint) {
    switch (hint) {
      case 'referrals':
        return AppRoutes.agencyReferrals;
      case 'session-notes':
        return '${AppRoutes.agencyHome}/session-notes';
      case 'payroll':
        return AppRoutes.agencyPayroll;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(agencyOperationalAlertsProvider);
    return alerts.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational alerts',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final alert in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${alert.count}'),
                      ),
                      title: Text(alert.label),
                      trailing: _routeForHint(alert.routeHint) != null
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: () {
                        final route = _routeForHint(alert.routeHint);
                        if (route != null) context.push(route);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
