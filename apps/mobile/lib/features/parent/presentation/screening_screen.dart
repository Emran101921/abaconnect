import 'package:flutter/material.dart';

import '../../../shared/widgets/app_scaffold.dart';

class ScreeningScreen extends StatelessWidget {
  const ScreeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Screening',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Intake Assessment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Complete the following screening forms for your child.'),
          const SizedBox(height: 24),
          _FormCard(title: 'Developmental History', progress: 0.6),
          _FormCard(title: 'Behavior Checklist', progress: 0.0),
          _FormCard(title: 'Insurance Information', progress: 1.0),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.progress});

  final String title;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text('${(progress * 100).round()}% complete'),
          ],
        ),
      ),
    );
  }
}
