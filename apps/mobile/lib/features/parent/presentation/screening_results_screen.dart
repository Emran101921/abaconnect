import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';

class ScreeningResultsScreen extends StatelessWidget {
  const ScreeningResultsScreen({
    super.key,
    required this.child,
    required this.result,
  });

  final ChildModel child;
  final ScreeningResultModel result;

  String get _ageLabel {
    final now = DateTime.now();
    var years = now.year - child.dateOfBirth.year;
    final birthdayPassed = now.month > child.dateOfBirth.month ||
        (now.month == child.dateOfBirth.month &&
            now.day >= child.dateOfBirth.day);
    if (!birthdayPassed) years -= 1;
    if (years < 1) {
      final months = (now.difference(child.dateOfBirth).inDays / 30).floor();
      return '$months mo';
    }
    return '$years yr';
  }

  Color _riskColor(BuildContext context) {
    switch (result.riskLevel?.toUpperCase()) {
      case 'HIGH':
        return Colors.red.shade700;
      case 'MODERATE':
        return Colors.orange.shade800;
      default:
        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final risk = result.riskLevel ?? 'UNKNOWN';

    return AppScaffold(
      title: 'Screening Results',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('Age $_ageLabel · DOB ${DateFormat.yMMMd().format(child.dateOfBirth)}'),
                  const SizedBox(height: 16),
                  Text('Overall risk level', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.flag, color: _riskColor(context)),
                      const SizedBox(width: 8),
                      Text(
                        risk,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: _riskColor(context),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (result.score != null) ...[
                        const Spacer(),
                        Text('Score ${result.score!.toStringAsFixed(2)}'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Recommended services',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (result.recommendations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No specific service recommendations at this time. '
                  'Continue monitoring development and consult your pediatrician.',
                ),
              ),
            )
          else
            ...result.recommendations.map(
              (rec) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(rec.service.characters.first),
                  ),
                  title: Text(rec.service),
                  subtitle: Text(rec.explanation),
                  isThreeLine: true,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This screening tool is for informational purposes only and '
                'does not replace evaluation by a licensed professional.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Next steps', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.parentBooking),
            icon: const Icon(Icons.medical_services_outlined),
            label: const Text('Request evaluation'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.documents),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload documents'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.matching),
            icon: const Icon(Icons.people_outline),
            label: const Text('Match providers'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.messages),
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact care coordinator'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              final childId = child.id;
              context.push(
                '${AppRoutes.parentScreening}?childId=$childId&autoStart=true',
              );
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('Start new screening or edit via draft'),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.parentHome),
              child: const Text('Back to home'),
            ),
          ),
        ],
      ),
    );
  }
}
